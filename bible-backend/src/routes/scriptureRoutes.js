const express = require("express");
const { getChapter } = require("../controllers/scriptureController");

const router = express.Router();

router.get("/chapter", getChapter);

module.exports = router;
