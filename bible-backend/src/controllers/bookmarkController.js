const asyncHandler = require("../utils/asyncHandler");
const AppError = require("../utils/AppError");
const { bookmarkService } = require("../services/bookmarkService");

const createBookmark = asyncHandler(async (req, res) => {
  const targetType = String(req.body.targetType || "verse").trim().toLowerCase();
  let bookmark;
  if (targetType === "song") {
    bookmark = await bookmarkService.saveSongBookmark(
      req.user.id || req.user._id,
      req.body
    );
  } else if (targetType === "verse") {
    bookmark = await bookmarkService.saveVerseBookmark(
      req.user.id || req.user._id,
      req.body
    );
  } else {
    throw new AppError(400, "targetType must be either verse or song");
  }

  res.status(201).json({
    success: true,
    data: bookmark,
  });
});

const listBookmarks = asyncHandler(async (req, res) => {
  const result = await bookmarkService.listBookmarks(
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

const deleteBookmark = asyncHandler(async (req, res) => {
  await bookmarkService.deleteBookmark(
    req.user.id || req.user._id,
    req.params.id
  );

  res.status(200).json({
    success: true,
    message: "Bookmark deleted successfully",
  });
});

module.exports = {
  createBookmark,
  listBookmarks,
  deleteBookmark,
};
