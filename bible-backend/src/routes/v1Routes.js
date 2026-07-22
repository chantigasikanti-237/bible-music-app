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

router.get("/debug/scrape-check/:versionId", async (req, res) => {
  const axios = require("axios");
  const versionId = req.params.versionId;
  const url = `https://www.bible.com/bible/${versionId}/GEN.9`;
  try {
    const response = await axios.get(url, {
      headers: {
        Accept: "text/html",
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
      },
      timeout: 15000,
      validateStatus: () => true,
    });
    const body = String(response.data ?? "");
    res.json({
      status: response.status,
      length: body.length,
      hasNextData: body.includes("__NEXT_DATA__"),
      hasChapterInfo: body.includes("chapterInfo"),
      snippet: body.slice(0, 300),
    });
  } catch (err) {
    res.json({ error: err.message, code: err.code });
  }
});

module.exports = router;
