const BibleVerse = require("../models/BibleVerse");
const normalizeText = require("../utils/normalizeText");
const {
  parseLimit,
  buildObjectIdCursorFilter,
  buildNextCursor,
} = require("../utils/pagination");

const createBibleVerseRepository = ({ model = BibleVerse } = {}) => ({
  async replaceChapterVerses(chapterPayload) {
    const chapterKey = `${chapterPayload.versionId}:${chapterPayload.bookId}:${chapterPayload.chapterNumber}`;
    await model.deleteMany({
      chapterKey,
    });

    if (!Array.isArray(chapterPayload.verses) || chapterPayload.verses.length === 0) {
      return [];
    }

    const documents = chapterPayload.verses.map((verse) => ({
      versionId: chapterPayload.versionId,
      languageCode: chapterPayload.languageCode || null,
      bookId: chapterPayload.bookId,
      bookName: chapterPayload.bookName,
      chapterNumber: chapterPayload.chapterNumber,
      verseNumber: verse.number,
      reference: `${chapterPayload.bookName} ${chapterPayload.chapterNumber}:${verse.number}`,
      passageId: chapterPayload.passageId,
      chapterKey,
      text: verse.text,
      normalizedText: normalizeText(verse.text),
    }));

    return model.insertMany(documents, { ordered: false });
  },

  async searchVerses({
    query,
    versionId,
    languageCode,
    bookId,
    limit,
    cursor,
  }) {
    const normalizedLimit = parseLimit(limit);
    const normalizedQuery = normalizeText(query);
    const filter = {
      ...buildObjectIdCursorFilter(cursor),
    };

    if (versionId) {
      filter.versionId = versionId;
    }
    if (languageCode) {
      filter.languageCode = languageCode;
    }
    if (bookId) {
      filter.bookId = bookId;
    }
    if (normalizedQuery) {
      filter.normalizedText = {
        $regex: normalizedQuery
          .split(" ")
          .filter(Boolean)
          .map((token) => token.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
          .join(".*"),
        $options: "i",
      };
    }

    const items = await model
      .find(filter)
      .sort({ _id: -1 })
      .limit(normalizedLimit)
      .lean()
      .exec();

    return {
      items,
      nextCursor: buildNextCursor(items),
    };
  },
});

module.exports = {
  createBibleVerseRepository,
  bibleVerseRepository: createBibleVerseRepository(),
};
