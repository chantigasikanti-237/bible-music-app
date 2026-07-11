const express = require("express");

const authMiddleware = require("../middleware/authMiddleware");
const { getCurrentUser } = require("../controllers/userController");

const router = express.Router();

router.get("/profile", authMiddleware, getCurrentUser);
router.get("/api/profile", authMiddleware, getCurrentUser);

module.exports = router;
