const { config } = require("../config/env");
const { ensureRedisConnection } = require("../config/redis");

const createChapterCacheService = ({
  ttlSeconds = config.chapterCacheTtlSeconds,
} = {}) => ({
  buildKey({ versionId, bookId, chapterNumber }) {
    return `chapter:v1:${versionId}:${bookId}:${chapterNumber}`;
  },

  async getChapter(params) {
    const client = await ensureRedisConnection();
    if (!client) {
      return null;
    }

    const raw = await client.get(this.buildKey(params));
    if (!raw) {
      return null;
    }

    try {
      return JSON.parse(raw);
    } catch (_) {
      return null;
    }
  },

  async setChapter(params, value) {
    const client = await ensureRedisConnection();
    if (!client) {
      return;
    }

    await client.set(
      this.buildKey(params),
      JSON.stringify(value),
      "EX",
      ttlSeconds
    );
  },
});

module.exports = {
  createChapterCacheService,
  chapterCacheService: createChapterCacheService(),
};
