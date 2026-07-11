const test = require("node:test");
const assert = require("node:assert/strict");

const { createBookmarkService } = require("../src/services/bookmarkService");
const { createHistoryService } = require("../src/services/historyService");

test("saveVerseBookmark derives canonical verse metadata and target key", async () => {
  let capturedPayload = null;
  const bookmarkService = createBookmarkService({
    bookmarkRepo: {
      async upsertBookmark(_userId, payload) {
        capturedPayload = payload;
        return {
          _id: "bookmark-1",
          ...payload,
        };
      },
    },
  });

  const bookmark = await bookmarkService.saveVerseBookmark("user-1", {
    bibleId: 111,
    passageId: "GEN.1",
    verseNumber: 2,
    text: "Now the earth was formless and empty.",
  });

  assert.equal(bookmark._id, "bookmark-1");
  assert.equal(capturedPayload.targetType, "verse");
  assert.equal(capturedPayload.targetKey, "verse:111:GEN:1:2");
  assert.equal(capturedPayload.verseRef.bookId, "GEN");
  assert.equal(capturedPayload.verseRef.chapterNumber, 1);
  assert.equal(capturedPayload.verseRef.reference, "Genesis 1:2");
});

test("updateReadingHistory stores derived passage metadata", async () => {
  let capturedPayload = null;
  const historyService = createHistoryService({
    historyRepo: {
      async upsertHistory(_userId, payload) {
        capturedPayload = payload;
        return payload;
      },
    },
  });

  const history = await historyService.updateReadingHistory("user-1", {
    bibleId: 111,
    passageId: "GEN.1",
  });

  assert.equal(history.bookId, "GEN");
  assert.equal(history.chapterNumber, 1);
  assert.equal(history.reference, "Genesis 1");
  assert.equal(capturedPayload.passageId, "GEN.1");
});
