const asyncHandler = require("../utils/asyncHandler");
const { parsePositiveInteger, validateRequiredFields } = require("../utils/validators");
const { getChapterWithCache } = require("../services/scriptureService");

const getChapter = asyncHandler(async (req, res) => {
  validateRequiredFields(req.query, ["bibleId", "passageId"]);

  const bibleId = parsePositiveInteger(req.query.bibleId, "bibleId");
  const passageId = req.query.passageId;

  const chapter = await getChapterWithCache({ bibleId, passageId });

  res.status(200).json({
    success: true,
    bibleId: chapter.bibleId,
    passageId: chapter.passageId,
    content: chapter.content,
    audioUrl: chapter.audioUrl,
    verses: chapter.verses,
  });
});

module.exports = {
  getChapter,
};
