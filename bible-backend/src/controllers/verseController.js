const asyncHandler = require("../utils/asyncHandler");
const {
  saveVerse,
  listSavedVerses,
  deleteSavedVerse,
} = require("../services/verseService");

const saveUserVerse = asyncHandler(async (req, res) => {
  const verse = await saveVerse(req.user._id, req.body);

  res.status(201).json({
    success: true,
    message: "Verse saved successfully",
    data: verse,
  });
});

const getUserVerses = asyncHandler(async (req, res) => {
  const verses = await listSavedVerses(req.user._id);

  res.status(200).json({
    success: true,
    data: verses,
  });
});

const deleteUserVerse = asyncHandler(async (req, res) => {
  await deleteSavedVerse(req.user._id, req.params.id);

  res.status(200).json({
    success: true,
    message: "Saved verse deleted successfully",
  });
});

module.exports = {
  saveUserVerse,
  getUserVerses,
  deleteUserVerse,
};
