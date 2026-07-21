const express = require("express");

const authMiddleware = require("../middleware/authMiddleware");
const {
  authLimiter,
  loginLimiter,
  passwordResetRequestLimiter,
  emailVerificationResendLimiter,
  refreshLimiter,
} = require("../middleware/rateLimiters");
const csrfProtection = require("../middleware/csrfProtection");
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
const { getCurrentUser, updateUser, uploadPhoto } = require("../controllers/userController");
const {
  listBooks,
  listChapters,
  getChapter,
} = require("../controllers/bibleContentController");
const {
  createBookmark,
  listBookmarks,
  deleteBookmark,
} = require("../controllers/bookmarkController");
const {
  createHistory,
  listHistory,
} = require("../controllers/historyV1Controller");
const {
  getDownloadCounts,
  listDownloads,
  registerDownload,
  removeDownload,
} = require("../controllers/musicDownloadController");
const { listSongs } = require("../controllers/songController");
const { searchVerses } = require("../controllers/searchController");

const router = express.Router();

router.post("/auth/register", authLimiter, register);
router.post("/auth/signup", authLimiter, register);
router.post("/auth/login", loginLimiter, login);
router.post("/auth/refresh", refreshLimiter, csrfProtection, refresh);
router.post("/auth/logout", authMiddleware, csrfProtection, logout);
router.post(
  "/auth/password-reset/request",
  passwordResetRequestLimiter,
  requestPasswordReset
);
router.post("/auth/password-reset/confirm", authLimiter, resetPassword);
router.post(
  "/auth/verify-email/resend",
  emailVerificationResendLimiter,
  resendVerificationEmail
);
router.post("/auth/verify-email/confirm", authLimiter, verifyEmail);

router.get("/users/me", authMiddleware, getCurrentUser);
router.patch("/users/me", authMiddleware, updateUser);
router.post("/users/me/photo", authMiddleware, ...uploadPhoto);
router.get("/users/me/bookmarks", authMiddleware, listBookmarks);
router.post("/users/me/bookmarks", authMiddleware, createBookmark);
router.delete("/users/me/bookmarks/:id", authMiddleware, deleteBookmark);
router.get("/users/me/history", authMiddleware, listHistory);
router.post("/users/me/history", authMiddleware, createHistory);
router.get("/users/me/music-downloads/counts", authMiddleware, getDownloadCounts);
router.get("/users/me/music-downloads", authMiddleware, listDownloads);
router.post("/users/me/music-downloads", authMiddleware, registerDownload);
router.delete("/users/me/music-downloads/:videoId", authMiddleware, removeDownload);

router.get("/bibles/:versionId/books", listBooks);
router.get("/bibles/:versionId/books/:bookId/chapters", listChapters);
router.get(
  "/bibles/:versionId/books/:bookId/chapters/:chapterNumber",
  getChapter
);
router.get("/songs", listSongs);
router.get("/search/verses", searchVerses);

// TEMPORARY - probing the YouVersion API for a verse-structured response
// format (USFM/USX/json) instead of flat text. Remove once resolved.
router.get("/debug/youversion-formats/:versionId", async (req, res) => {
  const axios = require("axios");
  const { config } = require("../config/env");
  const versionId = req.params.versionId;
  const attempts = [
    { label: "single-verse-GEN.1.1", url: `https://api.youversion.com/v1/bibles/${versionId}/passages/GEN.1.1`, headers: {} },
    { label: "single-verse-GEN.1.16", url: `https://api.youversion.com/v1/bibles/${versionId}/passages/GEN.1.16`, headers: {} },
  ];

  const results = [];
  for (const attempt of attempts) {
    try {
      const response = await axios.get(attempt.url, {
        headers: { "x-yvp-app-key": config.youVersionAppKey, ...attempt.headers },
        timeout: 15000,
        validateStatus: () => true,
      });
      const data = response.data;
      results.push({
        label: attempt.label,
        status: response.status,
        topLevelKeys: data && typeof data === "object" ? Object.keys(data) : typeof data,
        hasVersesArray: Array.isArray(data?.verses),
        sample: JSON.stringify(data).slice(0, 250),
      });
    } catch (error) {
      results.push({ label: attempt.label, error: error.message });
    }
  }
  res.json(results);
});

module.exports = router;
