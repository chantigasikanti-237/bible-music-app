const express = require("express");

const authMiddleware = require("../middleware/authMiddleware");
const csrfProtection = require("../middleware/csrfProtection");
const {
  authLimiter,
  loginLimiter,
  passwordResetRequestLimiter,
  emailVerificationResendLimiter,
  refreshLimiter,
} = require("../middleware/rateLimiters");
const {
  register,
  login,
  refresh,
  logout,
  requestPasswordReset,
  resetPassword,
  resendVerificationEmail,
  verifyEmail,
} = require("../controllers/authController");
const { getCurrentUser } = require("../controllers/userController");

const router = express.Router();

router.post("/signup", authLimiter, register);
router.post("/register", authLimiter, register);
router.post("/login", loginLimiter, login);
router.post("/refresh", refreshLimiter, csrfProtection, refresh);
router.post("/logout", authMiddleware, csrfProtection, logout);
router.post(
  "/password-reset/request",
  passwordResetRequestLimiter,
  requestPasswordReset
);
router.post("/password-reset/confirm", authLimiter, resetPassword);
router.post(
  "/verify-email/resend",
  emailVerificationResendLimiter,
  resendVerificationEmail
);
router.post("/verify-email/confirm", authLimiter, verifyEmail);

router.get("/profile", authMiddleware, getCurrentUser);


module.exports = router;
