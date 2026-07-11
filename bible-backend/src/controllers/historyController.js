const asyncHandler = require("../utils/asyncHandler");
const { historyService } = require("../services/historyService");

const updateHistory = asyncHandler(async (req, res) => {
  const historyRecord = await historyService.updateReadingHistory(req.user._id, req.body);

  res.status(200).json({
    success: true,
    message: "Reading history updated successfully",
    data: historyRecord,
  });
});

const getLastHistory = asyncHandler(async (req, res) => {
  const lastHistory = await historyService.getLastReadHistory(req.user._id);

  res.status(200).json({
    success: true,
    data: lastHistory,
  });
});

module.exports = {
  updateHistory,
  getLastHistory,
};
