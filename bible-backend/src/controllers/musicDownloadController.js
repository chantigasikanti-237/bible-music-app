const asyncHandler = require("../utils/asyncHandler");
const { musicDownloadService } = require("../services/musicDownloadService");

const getDownloadCounts = asyncHandler(async (req, res) => {
  const counts = await musicDownloadService.getCounts(req.user.id || req.user._id);
  res.status(200).json({ success: true, data: counts });
});

const listDownloads = asyncHandler(async (req, res) => {
  const downloads = await musicDownloadService.listDownloads(req.user.id || req.user._id);
  res.status(200).json({ success: true, data: downloads });
});

const registerDownload = asyncHandler(async (req, res) => {
  const download = await musicDownloadService.registerDownload(
    req.user.id || req.user._id,
    req.body
  );
  res.status(201).json({ success: true, data: download });
});

const removeDownload = asyncHandler(async (req, res) => {
  await musicDownloadService.removeDownload(req.user.id || req.user._id, req.params.videoId);
  res.status(200).json({ success: true, message: "Download removed" });
});

module.exports = {
  getDownloadCounts,
  listDownloads,
  registerDownload,
  removeDownload,
};
