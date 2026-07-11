const BibleChapter = require("../models/BibleChapter");

const createBibleChapterRepository = ({ model = BibleChapter } = {}) => ({
  async findChapter({ versionId, bookId, chapterNumber }) {
    return model
      .findOne({
        versionId,
        bookId,
        chapterNumber,
      })
      .lean()
      .exec();
  },

  async findChapterByPassage({ versionId, passageId }) {
    return model
      .findOne({
        versionId,
        passageId,
      })
      .lean()
      .exec();
  },

  async upsertChapter(payload) {
    return model
      .findOneAndUpdate(
        {
          versionId: payload.versionId,
          bookId: payload.bookId,
          chapterNumber: payload.chapterNumber,
        },
        {
          $set: payload,
        },
        {
          upsert: true,
          new: true,
          setDefaultsOnInsert: true,
        }
      )
      .lean()
      .exec();
  },

  async listBooks(versionId) {
    return model
      .aggregate([
        {
          $match: {
            versionId,
          },
        },
        {
          $group: {
            _id: "$bookId",
            bookId: { $first: "$bookId" },
            bookName: { $first: "$bookName" },
            maxChapterNumber: { $max: "$chapterNumber" },
          },
        },
        {
          $sort: {
            bookId: 1,
          },
        },
      ])
      .exec();
  },

  async listChapters(versionId, bookId) {
    return model
      .find({
        versionId,
        bookId,
      })
      .sort({
        chapterNumber: 1,
      })
      .select("bookId bookName chapterNumber passageId verseCount updatedAt")
      .lean()
      .exec();
  },
});

module.exports = {
  createBibleChapterRepository,
  bibleChapterRepository: createBibleChapterRepository(),
};
