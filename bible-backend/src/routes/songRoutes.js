const express = require("express");

const { listSongs } = require("../controllers/songController");

const router = express.Router();

router.get("/", listSongs);

module.exports = router;
