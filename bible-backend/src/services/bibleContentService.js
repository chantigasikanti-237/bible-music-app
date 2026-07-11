const AppError = require("../utils/AppError");
const { bibleChapterRepository } = require("../repositories/bibleChapterRepository");
const { bibleVerseRepository } = require("../repositories/bibleVerseRepository");
const { scriptureProvider } = require("../integrations/scriptureProvider");
const { chapterCacheService } = require("./chapterCacheService");
const {
  getBookMetadataList,
  findBookMetadataById,
  getLocalizedBookTitle,
} = require("../utils/bookMetadata");
const { buildPassageId, requirePassageId } = require("../utils/passage");
const { transliterateTitle } = require("../utils/transliterate");

const mapChapterResponse = (chapter) => ({
  versionId: chapter.versionId,
  languageCode: chapter.languageCode || null,
  bookId: chapter.bookId,
  bookName: chapter.bookName,
  chapterNumber: chapter.chapterNumber,
  passageId: chapter.passageId,
  verseCount: chapter.verseCount,
  content: chapter.content,
  verses: chapter.verses || [],
  audio: {
    provider: chapter.audio?.provider || null,
    url: chapter.audio?.url || null,
    storageKey: chapter.audio?.storageKey || null,
  },
  source: {
    type: chapter.source?.type || null,
    provider: chapter.source?.provider || null,
    fetchedAt: chapter.source?.fetchedAt || null,
  },
  createdAt: chapter.createdAt || null,
  updatedAt: chapter.updatedAt || null,
});

const createBibleContentService = ({
  chapterRepo = bibleChapterRepository,
  verseRepo = bibleVerseRepository,
  provider = scriptureProvider,
  chapterCache = chapterCacheService,
} = {}) => ({
  async getChapter({ versionId, bookId, chapterNumber }) {
    if (!Number.isInteger(versionId) || versionId <= 0) {
      throw new AppError(400, "versionId must be a positive integer");
    }

    const normalizedBookId = String(bookId || "").trim().toUpperCase();
    if (!normalizedBookId) {
      throw new AppError(400, "bookId is required");
    }
    if (!Number.isInteger(chapterNumber) || chapterNumber <= 0) {
      throw new AppError(400, "chapterNumber must be a positive integer");
    }

    const cacheKey = {
      versionId,
      bookId: normalizedBookId,
      chapterNumber,
    };

    const cachedChapter = await chapterCache.getChapter(cacheKey);
    if (cachedChapter) {
      return cachedChapter;
    }

    const storedChapter = await chapterRepo.findChapter(cacheKey);
    if (storedChapter) {
      const normalizedChapter = mapChapterResponse(storedChapter);
      await chapterCache.setChapter(cacheKey, normalizedChapter);
      return normalizedChapter;
    }

    const providerChapter = await provider.fetchChapter({
      versionId,
      bookId: normalizedBookId,
      chapterNumber,
      passageId: buildPassageId(normalizedBookId, chapterNumber),
    });
    const savedChapter = await chapterRepo.upsertChapter(providerChapter);
    await verseRepo.replaceChapterVerses(providerChapter);

    const normalizedChapter = mapChapterResponse(savedChapter);
    await chapterCache.setChapter(cacheKey, normalizedChapter);
    return normalizedChapter;
  },

  async getChapterByPassage({ versionId, passageId }) {
    const parsed = requirePassageId(passageId);
    return this.getChapter({
      versionId,
      bookId: parsed.bookId,
      chapterNumber: parsed.chapterNumber,
    });
  },

  async listBooks({ versionId, languageCode }) {
    const storedBooks = await chapterRepo.listBooks(versionId);
    const storedById = new Map(
      storedBooks.map((book) => [String(book.bookId).trim().toUpperCase(), book])
    );

    return getBookMetadataList().map((book) => {
      const stored = storedById.get(book.id);
      const title = getLocalizedBookTitle(book.id, languageCode);
      return {
        id: book.id,
        title,
        // Lets a search typed in English letters (e.g. "Genesis") match a
        // book whose displayed title is in native script — same fix as
        // Hymns search, see src/utils/transliterate.js.
        titleRomanized: transliterateTitle(title, languageCode),
        // The book's standard English name is always the same regardless of
        // display language — someone typing "Ephesians" almost certainly
        // means the English name, not a phonetic guess at its Telugu
        // translation (a different word, not a transliteration of it).
        englishTitle: book.englishTitle,
        canon: book.canon,
        chapterCount: book.chapterCount,
        availableChapterCount: stored?.maxChapterNumber || 0,
      };
    });
  },

  async listChapters({ versionId, bookId }) {
    const normalizedBookId = String(bookId || "").trim().toUpperCase();
    if (!normalizedBookId) {
      throw new AppError(400, "bookId is required");
    }

    const storedChapters = await chapterRepo.listChapters(versionId, normalizedBookId);
    const storedByChapter = new Map(
      storedChapters.map((chapter) => [chapter.chapterNumber, chapter])
    );
    const metadata = findBookMetadataById(normalizedBookId);
    const chapterCount =
      metadata?.chapterCount ||
      Math.max(...storedChapters.map((chapter) => chapter.chapterNumber), 0);

    return Array.from({ length: chapterCount }, (_, index) => {
      const chapterNumber = index + 1;
      const stored = storedByChapter.get(chapterNumber);
      return {
        bookId: normalizedBookId,
        bookName: metadata?.englishTitle || stored?.bookName || normalizedBookId,
        chapterNumber,
        passageId: buildPassageId(normalizedBookId, chapterNumber),
        verseCount: stored?.verseCount || null,
        isImported: Boolean(stored),
        updatedAt: stored?.updatedAt || null,
      };
    });
  },
});

module.exports = {
  createBibleContentService,
  bibleContentService: createBibleContentService(),
};
