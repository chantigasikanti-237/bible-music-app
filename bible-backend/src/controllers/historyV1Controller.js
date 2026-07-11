const asyncHandler = require("../utils/asyncHandler");
const { historyService } = require("../services/historyService");

const createHistory = asyncHandler(async (req, res) => {
  const record = await historyService.updateReadingHistory(
    req.user.id || req.user._id,
    req.body
  );

  res.status(201).json({
    success: true,
    data: record,
  });
});

const listHistory = asyncHandler(async (req, res) => {
  const result = await historyService.listHistory(
    req.user.id || req.user._id,
    req.query
  );

  res.status(200).json({
    success: true,
    data: result.items,
    pagination: {
      nextCursor: result.nextCursor,
    },
  });
});

module.exports = {
  createHistory,
  listHistory,
};
