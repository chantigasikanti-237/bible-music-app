const express = require("express");

const { listSongsByLanguage, listCategories, listSongsByCategory, getStreamUrl, searchSongs, streamAudio } = require("../controllers/audioController");

const router = express.Router();

router.get("/songs/:language", listSongsByLanguage);
router.get("/categories", listCategories);
router.get("/category/:category/:language", listSongsByCategory);
router.get("/search", searchSongs);
router.get("/url/:videoId", getStreamUrl);
router.get("/stream/:videoId", streamAudio);

module.exports = router;
