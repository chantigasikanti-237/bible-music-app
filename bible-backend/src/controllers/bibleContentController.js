const asyncHandler = require("../utils/asyncHandler");
const AppError = require("../utils/AppError");
const { bibleContentService } = require("../services/bibleContentService");

const parseVersionId = (value) => {
  const versionId = Number(value);
  if (!Number.isInteger(versionId) || versionId <= 0) {
    throw new AppError(400, "versionId must be a positive integer");
  }
  return versionId;
};

const parseChapterNumber = (value) => {
  const chapterNumber = Number(value);
  if (!Number.isInteger(chapterNumber) || chapterNumber <= 0) {
    throw new AppError(400, "chapterNumber must be a positive integer");
  }
  return chapterNumber;
};

const listBooks = asyncHandler(async (req, res) => {
  const books = await bibleContentService.listBooks({
    versionId: parseVersionId(req.params.versionId),
    languageCode: String(req.query.lang || "").trim().toLowerCase() || null,
  });

  res.status(200).json({
    success: true,
    data: books,
  });
});

const listChapters = asyncHandler(async (req, res) => {
  const chapters = await bibleContentService.listChapters({
    versionId: parseVersionId(req.params.versionId),
    bookId: req.params.bookId,
  });

  res.status(200).json({
    success: true,
    data: chapters,
  });
});

const getChapter = asyncHandler(async (req, res) => {
  const chapter = await bibleContentService.getChapter({
    versionId: parseVersionId(req.params.versionId),
    bookId: req.params.bookId,
    chapterNumber: parseChapterNumber(req.params.chapterNumber),
  });

  res.status(200).json({
    success: true,
    data: chapter,
  });
});

module.exports = {
  listBooks,
  listChapters,
  getChapter,
};
