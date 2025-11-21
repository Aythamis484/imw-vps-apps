#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# Despliegue de Webapp Node.js con systemd en Ubuntu 24.04
# =========================================================
#
# server.js y package.json deben estar en la misma carpeta

# ---------- Config ----------
INSTALL_DIR="/opt/nodewebapp"       # Carpeta donde se despliega la app
APP_ENTRY="server.js"               # Archivo de entrada Node.js
SERVICE_NAME="nodewebapp.service"
ENV_FILE="/etc/default/nodewebapp"
APP_USER="nodewebapp"               # Usuario del servicio
APP_PORT="8081"                     # Puerto HTTP

log() { printf "\n\033[1;34m[INFO]\033[0m %s\n" "$*"; }
require_root() { [[ $EUID -eq 0 ]] || { echo "[ERROR] Ejecuta este script como root."; exit 1; }; }

# 0) Requisitos
require_root

# 1) Instalar Node.js
log "Actualizando sistema e instalando Node.js 20 LTS…"
apt update
apt upgrade -y
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

log "Node instalado:"
node -v
npm -v

# 2) Usuario del servicio
if ! id -u "$APP_USER" >/dev/null 2>&1; then
  log "Creando usuario del servicio: $APP_USER"
  useradd --system --no-create-home --shell /usr/sbin/nologin "$APP_USER"
fi

# 3) Copia del proyecto
log "Creando directorio de instalación en $INSTALL_DIR…"
mkdir -p "$INSTALL_DIR"

log "Copiando archivos del proyecto…"
# Se copian server.js, package.json, package-lock.json, .env y carpetas
cp -r ./* "$INSTALL_DIR"

cd "$INSTALL_DIR"

# 4) Instalación de dependencias
log "Instalando dependencias de Node.js…"
npm install --omit=dev

# 5) Archivo .env (si no existe)
if [ ! -f "$ENV_FILE" ]; then
  log "Generando archivo de entorno en $ENV_FILE…"
  cat > "$ENV_FILE" <<EOF
PORT=$APP_PORT
NODE_ENV=production
EOF
fi

chmod 644 "$ENV_FILE"

# 6) Permisos
chown -R "$APP_USER":"$APP_USER" "$INSTALL_DIR"
chmod 750 "$INSTALL_DIR"

# 7) Unidad systemd
log "Creando unidad systemd: /etc/systemd/system/$SERVICE_NAME"
cat > "/etc/systemd/system/$SERVICE_NAME" <<EOF
[Unit]
Description=Node.js WebApp (Express)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$ENV_FILE
ExecStart=/usr/bin/node $INSTALL_DIR/$APP_ENTRY
Restart=on-failure
RestartSec=3

# Endurecimiento básico
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR
CapabilityBoundingSet=
LockPersonality=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

# 8) UFW
if command -v ufw >/dev/null 2>&1; then
  if ufw status | grep -q "Status: active"; then
    log "Abriendo puerto $APP_PORT/TCP en UFW…"
    ufw allow "${APP_PORT}/tcp" || true
  fi
fi

# 9) Iniciar servicio
log "Cargando systemd e iniciando servicio…"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

sleep 1
systemctl --no-pager --full status "$SERVICE_NAME" || true

echo
echo "=============================================="
echo "   Despliegue Node.js completado"
echo "----------------------------------------------"
echo "Servicio:          $SERVICE_NAME"
echo "Directorio:        $INSTALL_DIR"
echo "Archivo entorno:   $ENV_FILE"
echo "Puerto:            $APP_PORT"
echo
echo "Comandos útiles:"
echo "  sudo systemctl status $SERVICE_NAME"
echo "  sudo journalctl -u $SERVICE_NAME -f"
echo "  sudo systemctl restart $SERVICE_NAME"
echo
echo "Accede a:"
echo "  http://<ip_servidor>:$APP_PORT/"
echo "=============================================="
