const asyncHandler = require("../utils/asyncHandler");
const { audioService } = require("../services/audioService");

const listSongsByLanguage = asyncHandler(async (req, res) => {
  const songs = await audioService.listSongsByLanguage(req.params.language);
  res.status(200).json(songs);
});

const listCategories = asyncHandler(async (_req, res) => {
  res.status(200).json(audioService.listCategories());
});

const listSongsByCategory = asyncHandler(async (req, res) => {
  const songs = await audioService.listSongsByCategory(req.params.language, req.params.category);
  res.status(200).json(songs);
});

const getStreamUrl = asyncHandler(async (req, res) => {
  const url = await audioService.getStreamUrl(req.params.videoId);
  res.status(200).json({ url });
});

const searchSongs = asyncHandler(async (req, res) => {
  const query = String(req.query.q || '').trim();
  if (!query) return res.status(400).json({ error: 'q is required' });
  const songs = await audioService.searchSongs(query);
  res.status(200).json(songs);
});

const streamAudio = async (req, res, next) => {
  try {
    await audioService.streamAudio(req.params.videoId, req, res);
  } catch (err) {
    if (!res.headersSent) {
      next(err);
    }
  }
};

module.exports = {
  listSongsByLanguage,
  listCategories,
  listSongsByCategory,
  getStreamUrl,
  searchSongs,
  streamAudio,
};
