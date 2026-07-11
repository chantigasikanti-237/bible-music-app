const { bibleContentService } = require("./bibleContentService");

const getChapterWithCache = async ({ bibleId, passageId }) => {
  const chapter = await bibleContentService.getChapterByPassage({
    versionId: bibleId,
    passageId,
  });

  return {
    bibleId: chapter.versionId,
    passageId: chapter.passageId,
    content: chapter.content,
    audioUrl: chapter.audio.url,
    verses: chapter.verses,
  };
};

module.exports = {
  getChapterWithCache,
};
