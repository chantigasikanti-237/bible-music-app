const test = require("node:test");
const assert = require("node:assert/strict");

const { createBibleContentService } = require("../src/services/bibleContentService");

test("getChapter returns cached chapter before hitting repositories or providers", async () => {
  let repoCalls = 0;
  let providerCalls = 0;
  const chapterCache = {
    async getChapter() {
      return {
        versionId: 111,
        bookId: "GEN",
        chapterNumber: 1,
        passageId: "GEN.1",
        content: "1 In the beginning",
        verses: [{ number: 1, text: "In the beginning" }],
        audio: { provider: null, url: null, storageKey: null },
        source: { type: "cache", provider: "redis", fetchedAt: null },
      };
    },
    async setChapter() {},
  };

  const service = createBibleContentService({
    chapterRepo: {
      async findChapter() {
        repoCalls += 1;
        return null;
      },
    },
    verseRepo: {
      async replaceChapterVerses() {},
    },
    provider: {
      async fetchChapter() {
        providerCalls += 1;
        throw new Error("should not be called");
      },
    },
    chapterCache,
  });

  const chapter = await service.getChapter({
    versionId: 111,
    bookId: "GEN",
    chapterNumber: 1,
  });

  assert.equal(chapter.passageId, "GEN.1");
  assert.equal(repoCalls, 0);
  assert.equal(providerCalls, 0);
});

test("getChapter falls back to provider and persists chapter + verses", async () => {
  let persistedChapter = null;
  let persistedVerses = null;
  let cacheSetCount = 0;
  const providerChapter = {
    versionId: 111,
    languageCode: "en",
    bookId: "GEN",
    bookName: "Genesis",
    chapterNumber: 1,
    passageId: "GEN.1",
    verseCount: 2,
    content: "1 In the beginning\n2 The earth was without form",
    verses: [
      { number: 1, text: "In the beginning" },
      { number: 2, text: "The earth was without form" },
    ],
    audio: { provider: null, url: null, storageKey: null },
    source: { type: "provider", provider: "test", fetchedAt: new Date() },
  };

  const service = createBibleContentService({
    chapterRepo: {
      async findChapter() {
        return null;
      },
      async upsertChapter(payload) {
        persistedChapter = payload;
        return {
          _id: "chapter-1",
          createdAt: new Date("2026-03-25T00:00:00.000Z"),
          updatedAt: new Date("2026-03-25T00:00:00.000Z"),
          ...payload,
        };
      },
      async listBooks() {
        return [];
      },
      async listChapters() {
        return [];
      },
    },
    verseRepo: {
      async replaceChapterVerses(payload) {
        persistedVerses = payload.verses;
      },
    },
    provider: {
      async fetchChapter() {
        return providerChapter;
      },
    },
    chapterCache: {
      async getChapter() {
        return null;
      },
      async setChapter() {
        cacheSetCount += 1;
      },
    },
  });

  const chapter = await service.getChapter({
    versionId: 111,
    bookId: "GEN",
    chapterNumber: 1,
  });

  assert.equal(chapter.passageId, "GEN.1");
  assert.equal(persistedChapter.bookName, "Genesis");
  assert.equal(persistedVerses.length, 2);
  assert.equal(cacheSetCount, 1);
});
