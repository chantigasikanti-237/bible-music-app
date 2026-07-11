const AppError = require("../utils/AppError");
const { bibleVerseRepository } = require("../repositories/bibleVerseRepository");

const createSearchService = ({
  verseRepo = bibleVerseRepository,
} = {}) => ({
  async searchVerses(query) {
    const rawQuery = String(query.q || query.query || "").trim();
    if (!rawQuery) {
      throw new AppError(400, "q is required");
    }

    const versionId = query.versionId ? Number(query.versionId) : null;
    if (query.versionId && (!Number.isInteger(versionId) || versionId <= 0)) {
      throw new AppError(400, "versionId must be a positive integer");
    }

    return verseRepo.searchVerses({
      query: rawQuery,
      versionId,
      languageCode: query.languageCode?.trim().toLowerCase() || null,
      bookId: query.bookId?.trim().toUpperCase() || null,
      limit: query.limit,
      cursor: query.cursor,
    });
  },
});

module.exports = {
  createSearchService,
  searchService: createSearchService(),
};
