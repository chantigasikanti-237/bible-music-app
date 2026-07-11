const AppError = require("../utils/AppError");
const { musicDownloadRepository } = require("../repositories/musicDownloadRepository");

// Kept in sync with bible-ui/src/app/lib/offlineMusicStore.ts — Non-Stop
// Worship mixes are 20+ minutes each, so a much lower cap keeps total
// per-account download counts reasonable compared to regular songs.
const REGULAR_DOWNLOAD_LIMIT = 200;
const LONGMIX_DOWNLOAD_LIMIT = 100;

const createMusicDownloadService = ({
  repo = musicDownloadRepository,
} = {}) => ({
  async getCounts(userId) {
    return repo.countsByUser(userId);
  },

  async registerDownload(userId, payload) {
    const videoId = String(payload.videoId || "").trim();
    const title = String(payload.title || "").trim();
    if (!videoId || !title) {
      throw new AppError(400, "videoId and title are required");
    }

    const existing = await repo.findByUserAndVideoId(userId, videoId);
    if (existing) {
      // Already registered (e.g. re-downloading on a second device) — no
      // quota impact, just confirm it still counts.
      return existing;
    }

    const isLongMix = Boolean(payload.isLongMix);
    const counts = await repo.countsByUser(userId);
    const limit = isLongMix ? LONGMIX_DOWNLOAD_LIMIT : REGULAR_DOWNLOAD_LIMIT;
    const current = isLongMix ? counts.longmix : counts.regular;

    if (current >= limit) {
      const kind = isLongMix ? "Non-Stop Worship" : "song";
      throw new AppError(
        403,
        `You've reached the ${limit}-download limit for ${kind}s.`
      );
    }

    try {
      return await repo.create(userId, {
        videoId,
        title,
        artist: payload.artist?.trim() || null,
        image: payload.image?.trim() || null,
        language: payload.language?.trim() || null,
        isLongMix,
      });
    } catch (err) {
      // Unique index race (e.g. two tabs downloading the same song at once)
      // — treat as already-registered rather than a hard failure.
      if (err.code === 11000) {
        return repo.findByUserAndVideoId(userId, videoId);
      }
      throw err;
    }
  },

  async removeDownload(userId, videoId) {
    return repo.deleteByUserAndVideoId(userId, videoId);
  },

  async listDownloads(userId) {
    return repo.listByUser(userId);
  },
});

module.exports = {
  createMusicDownloadService,
  musicDownloadService: createMusicDownloadService(),
  REGULAR_DOWNLOAD_LIMIT,
  LONGMIX_DOWNLOAD_LIMIT,
};
