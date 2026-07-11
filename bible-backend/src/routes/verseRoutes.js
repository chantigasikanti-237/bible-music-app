const express = require("express");
const authMiddleware = require("../middleware/authMiddleware");
const {
  saveUserVerse,
  getUserVerses,
  deleteUserVerse,
} = require("../controllers/verseController");

const router = express.Router();

router.use(authMiddleware);
router.post("/save", saveUserVerse);
router.get("/", getUserVerses);
router.delete("/:id", deleteUserVerse);

module.exports = router;
