const { bookmarkService } = require("./bookmarkService");

const saveVerse = (userId, payload) =>
  bookmarkService.saveVerseBookmark(userId, payload);

const listSavedVerses = async (userId) =>
  bookmarkService.listLegacyVerseBookmarks(userId);

const deleteSavedVerse = async (userId, bookmarkId) =>
  bookmarkService.deleteBookmark(userId, bookmarkId);

module.exports = {
  saveVerse,
  listSavedVerses,
  deleteSavedVerse,
};
