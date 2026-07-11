const test = require("node:test");
const assert = require("node:assert/strict");

const { createSearchService } = require("../src/services/searchService");
const { createSongService } = require("../src/services/songService");

test("searchVerses rejects empty searches", async () => {
  const searchService = createSearchService({
    verseRepo: {
      async searchVerses() {
        return { items: [], nextCursor: null };
      },
    },
  });

  await assert.rejects(
    () => searchService.searchVerses({ q: "   " }),
    /q is required/
  );
});

test("listSongs delegates pagination filters to repository", async () => {
  let capturedQuery = null;
  const songService = createSongService({
    songs: {
      async listSongs(query) {
        capturedQuery = query;
        return {
          items: [{ songId: "1", languageCode: "te", title: "Genesis Chapter 1" }],
          nextCursor: "next-cursor",
        };
      },
    },
  });

  const result = await songService.listSongs({
    language: "TE",
    search: "Grace",
    page: "2",
    limit: "10",
    cursor: "cursor-1",
  });

  assert.equal(capturedQuery.languageCode, "te");
  assert.equal(capturedQuery.search, "Grace");
  assert.equal(capturedQuery.page, "2");
  assert.equal(capturedQuery.limit, "10");
  assert.equal(result.nextCursor, "next-cursor");
});
