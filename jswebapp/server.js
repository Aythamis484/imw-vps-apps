const express = require("express");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 8081;

app.get("/", (req, res) => {
    res.send("Aplicación Node.js desplegada correctamente 🚀");
});

app.listen(PORT, () => {
    console.log(`Servidor escuchando por HTTP en puerto ${PORT}`);
});
