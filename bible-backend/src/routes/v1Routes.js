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

// TEMPORARY - inspecting the raw YouVersion API response shape to fix verse
// splitting. Remove once resolved.
router.get("/debug/youversion-raw/:versionId", async (req, res) => {
  const axios = require("axios");
  const { config } = require("../config/env");
  try {
    const response = await axios.get(
      `https://api.youversion.com/v1/bibles/${req.params.versionId}/passages/GEN.1`,
      { headers: { "x-yvp-app-key": config.youVersionAppKey }, timeout: 15000, validateStatus: () => true }
    );
    const data = response.data;
    res.json({
      status: response.status,
      topLevelKeys: data && typeof data === "object" ? Object.keys(data) : typeof data,
      hasVersesArray: Array.isArray(data?.verses),
      versesSample: Array.isArray(data?.verses) ? data.verses.slice(0, 2) : null,
      contentSample: typeof data?.content === "string" ? data.content.slice(0, 300) : null,
      dataSample: JSON.stringify(data).slice(0, 800),
    });
  } catch (error) {
    res.json({ error: error.message });
  }
});

module.exports = router;
