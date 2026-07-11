const asyncHandler = require("../utils/asyncHandler");
const { searchService } = require("../services/searchService");

const searchVerses = asyncHandler(async (req, res) => {
  const result = await searchService.searchVerses(req.query);

  res.status(200).json({
    success: true,
    data: result.items,
    pagination: {
      nextCursor: result.nextCursor,
    },
  });
});

module.exports = {
  searchVerses,
};
