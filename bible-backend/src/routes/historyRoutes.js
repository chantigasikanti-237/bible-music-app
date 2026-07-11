const express = require("express");
const authMiddleware = require("../middleware/authMiddleware");
const {
  updateHistory,
  getLastHistory,
} = require("../controllers/historyController");

const router = express.Router();

router.use(authMiddleware);
router.post("/update", updateHistory);
router.get("/last", getLastHistory);

module.exports = router;
