const MusicDownload = require("../models/MusicDownload");

const createMusicDownloadRepository = ({ model = MusicDownload } = {}) => ({
  async create(userId, payload) {
    return model.create({ userId, ...payload });
  },

  async findByUserAndVideoId(userId, videoId) {
    return model.findOne({ userId, videoId }).lean().exec();
  },

  async listByUser(userId) {
    return model.find({ userId }).sort({ createdAt: -1 }).lean().exec();
  },

  async countsByUser(userId) {
    const [regular, longmix] = await Promise.all([
      model.countDocuments({ userId, isLongMix: false }),
      model.countDocuments({ userId, isLongMix: true }),
    ]);
    return { regular, longmix };
  },

  async deleteByUserAndVideoId(userId, videoId) {
    return model.findOneAndDelete({ userId, videoId }).lean().exec();
  },
});

module.exports = {
  createMusicDownloadRepository,
  musicDownloadRepository: createMusicDownloadRepository(),
};
