const AppError = require("../utils/AppError");
const { historyRepository } = require("../repositories/historyRepository");
const { requirePassageId } = require("../utils/passage");
const { findBookMetadataById } = require("../utils/bookMetadata");

const createHistoryService = ({
  historyRepo = historyRepository,
} = {}) => ({
  async updateReadingHistory(userId, payload) {
    const bibleId = Number(payload.bibleId || payload.versionId);
    if (!Number.isInteger(bibleId) || bibleId <= 0) {
      throw new AppError(400, "bibleId must be a positive integer");
    }

    const passage = requirePassageId(payload.passageId);
    const metadata = findBookMetadataById(passage.bookId);
    const reference =
      payload.reference?.trim() ||
      `${metadata?.englishTitle || passage.bookId} ${passage.chapterNumber}`;

    return historyRepo.upsertHistory(userId, {
      bibleId,
      versionId: bibleId,
      languageCode: payload.languageCode?.trim().toLowerCase() || null,
      bookId: passage.bookId,
      chapterNumber: passage.chapterNumber,
      passageId: passage.passageId,
      reference,
    });
  },

  async getLastReadHistory(userId) {
    return historyRepo.getLatestHistory(userId);
  },

  async listHistory(userId, query) {
    return historyRepo.listHistory({
      userId,
      limit: query.limit,
      cursor: query.cursor,
    });
  },
});

module.exports = {
  createHistoryService,
  historyService: createHistoryService(),
};
