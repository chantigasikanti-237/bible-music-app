const AppError = require("../utils/AppError");
const { bookmarkRepository } = require("../repositories/bookmarkRepository");
const { requirePassageId } = require("../utils/passage");
const { findBookMetadataById } = require("../utils/bookMetadata");

const createVerseTargetKey = ({ versionId, bookId, chapterNumber, verseNumber }) =>
  `verse:${versionId}:${bookId}:${chapterNumber}:${verseNumber}`;

const createSongTargetKey = ({ languageCode, slug }) =>
  `song:${String(languageCode ?? "").trim().toLowerCase()}:${String(slug ?? "")
    .trim()
    .toLowerCase()}`;

const buildReference = (bookId, chapterNumber, verseNumber) => {
  const metadata = findBookMetadataById(bookId);
  const bookName = metadata?.englishTitle || bookId;
  return `${bookName} ${chapterNumber}:${verseNumber}`;
};

const mapLegacyVerseBookmark = (bookmark) => ({
  _id: bookmark._id,
  bibleId: bookmark.verseRef?.versionId || null,
  passageId: bookmark.verseRef?.passageId || null,
  verseNumber: bookmark.verseRef?.verseNumber || null,
  text: bookmark.verseRef?.text || "",
  bookId: bookmark.verseRef?.bookId || null,
  bookName: bookmark.verseRef?.bookName || null,
  chapterNumber: bookmark.verseRef?.chapterNumber || null,
  reference: bookmark.verseRef?.reference || null,
  folderId: bookmark.folderId || null,
  folderName: bookmark.folderName || null,
  createdAt: bookmark.createdAt,
  updatedAt: bookmark.updatedAt,
});

const createBookmarkService = ({
  bookmarkRepo = bookmarkRepository,
} = {}) => ({
  async saveVerseBookmark(userId, payload) {
    const versionId = Number(payload.bibleId || payload.versionId);
    if (!Number.isInteger(versionId) || versionId <= 0) {
      throw new AppError(400, "bibleId must be a positive integer");
    }

    const passage = requirePassageId(payload.passageId);
    const verseNumber = Number(payload.verseNumber);
    if (!Number.isInteger(verseNumber) || verseNumber <= 0) {
      throw new AppError(400, "verseNumber must be a positive integer");
    }

    const text = String(payload.text || "").trim();
    if (!text) {
      throw new AppError(400, "text is required");
    }

    const metadata = findBookMetadataById(passage.bookId);
    return bookmarkRepo.upsertBookmark(userId, {
      targetType: "verse",
      targetKey: createVerseTargetKey({
        versionId,
        bookId: passage.bookId,
        chapterNumber: passage.chapterNumber,
        verseNumber,
      }),
      folderId: payload.folderId?.trim() || null,
      folderName: payload.folderName?.trim() || null,
      note: payload.note?.trim() || null,
      verseRef: {
        versionId,
        languageCode: payload.languageCode?.trim().toLowerCase() || null,
        bookId: passage.bookId,
        bookName: payload.bookName?.trim() || metadata?.englishTitle || passage.bookId,
        chapterNumber: passage.chapterNumber,
        verseNumber,
        passageId: passage.passageId,
        reference:
          payload.reference?.trim() ||
          buildReference(passage.bookId, passage.chapterNumber, verseNumber),
        text,
      },
      songRef: null,
    });
  },

  async saveSongBookmark(userId, payload) {
    const languageCode = String(payload.languageCode || "").trim().toLowerCase();
    const title = String(payload.title || "").trim();
    const slug = String(payload.slug || "").trim().toLowerCase();
    const songId = String(payload.songId || "").trim();
    if (!languageCode || !title || !slug || !songId) {
      throw new AppError(400, "songId, title, slug, and languageCode are required");
    }

    return bookmarkRepo.upsertBookmark(userId, {
      targetType: "song",
      targetKey: createSongTargetKey({ languageCode, slug }),
      folderId: payload.folderId?.trim() || null,
      folderName: payload.folderName?.trim() || null,
      note: payload.note?.trim() || null,
      verseRef: null,
      songRef: {
        songId,
        languageCode,
        title,
        slug,
      },
    });
  },

  async listBookmarks(userId, query) {
    return bookmarkRepo.listBookmarks({
      userId,
      targetType: query.targetType?.trim() || null,
      limit: query.limit,
      cursor: query.cursor,
    });
  },

  async listLegacyVerseBookmarks(userId) {
    const items = await bookmarkRepo.listAllBookmarks({
      userId,
      targetType: "verse",
    });
    return items.map(mapLegacyVerseBookmark);
  },

  async deleteBookmark(userId, bookmarkId) {
    const deleted = await bookmarkRepo.deleteBookmark(userId, bookmarkId);
    if (!deleted) {
      throw new AppError(404, "Bookmark not found");
    }
    return deleted;
  },
});

module.exports = {
  createBookmarkService,
  bookmarkService: createBookmarkService(),
  mapLegacyVerseBookmark,
};
