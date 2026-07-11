const asyncHandler = require("../utils/asyncHandler");
const { songService } = require("../services/songService");

const listSongs = asyncHandler(async (req, res) => {
  const result = await songService.listSongs(req.query);

  res.status(200).json({
    success: true,
    data: result.items,
    pagination: {
      page: result.page,
      limit: result.limit,
      nextPage: result.nextPage,
      nextCursor: result.nextCursor,
      hasNextPage: result.hasNextPage,
    },
  });
});

module.exports = {
  listSongs,
};
