const axios = require("axios");

const { config } = require("../config/env");
const AppError = require("../utils/AppError");
const extractScriptureContent = require("../utils/extractScriptureContent");
const {
  parseBibleDotComAudioPage,
  parseBibleDotComChapterPage,
} = require("../utils/parseBibleDotComPage");
const { findBookMetadataById } = require("../utils/bookMetadata");
const { buildPassageId } = require("../utils/passage");

const YOUVERSION_BASE_URL = "https://api.youversion.com/v1";
const PUBLIC_PAGE_PREFERRED_BIBLE_IDS = new Set([
  111,   // English KJV
  339,   // Tamil OV BSI
  722,   // Sindhi Common Language NT
  155,   // Bengali (Pobitro Baibel)
  1681,  // Bengali OV BSI
  1683,  // Hindi OV BSI
  1684,  // Kannada JV BSI
  1686,  // Marathi RV BSI
  1690,  // Bengali CL BSI
  1692,  // Kannada CL BSI
  1693,  // Malayalam OV BSI
  1711,  // Nepali Saral
  1787,  // Telugu OV BSI
  1866,  // Konkani/Goan NT BSI
  1883,  // Bengali IRV
  1884,  // Punjabi IRV
  1979,  // Assamese IRV 2019
]);
const AUDIO_BIBLE_ID_BY_TEXT_BIBLE_ID = new Map([
  [111, 111],
  [339, 339],
  [1683, 1683],
  [1684, 1898],
  [1686, 1686],
  [1693, 1693],
  [1787, 1787],
]);

const buildPublicPageHeaders = () => ({
  Accept: "text/html",
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
});

const extractVersesFromContent = (content) => {
  const normalizedContent = String(content ?? "").trim();
  if (!normalizedContent) {
    return [];
  }

  const chunks = normalizedContent.split(/(?=\d{1,3}\s)/g);
  const verses = [];
  let fallbackNumber = 1;

  for (const chunk of chunks) {
    const normalizedChunk = String(chunk ?? "").trim();
    if (!normalizedChunk) {
      continue;
    }

    const match = /^(\d{1,3})\s+(.*)$/s.exec(normalizedChunk);
    if (match) {
      const number = Number.parseInt(match[1], 10) || fallbackNumber;
      const text = String(match[2] ?? "").trim();
      if (text) {
        verses.push({ number, text });
        fallbackNumber = number + 1;
      }
      continue;
    }

    verses.push({ number: fallbackNumber, text: normalizedChunk });
    fallbackNumber += 1;
  }

  return verses;
};

const mapChapterPayload = ({
  versionId,
  bookId,
  chapterNumber,
  content,
  verses,
  audioUrl,
  sourceType,
  sourceProvider,
}) => {
  const metadata = findBookMetadataById(bookId);
  const resolvedVerses =
    Array.isArray(verses) && verses.length > 0
      ? verses
      : extractVersesFromContent(content);

  return {
    versionId,
    languageCode: null,
    bookId,
    bookName: metadata?.englishTitle || bookId,
    chapterNumber,
    passageId: buildPassageId(bookId, chapterNumber),
    verseCount: resolvedVerses.length,
    content,
    verses: resolvedVerses,
    audio: {
      provider: audioUrl ? sourceProvider : null,
      url: audioUrl || null,
      storageKey: null,
    },
    source: {
      type: sourceType,
      provider: sourceProvider,
      fetchedAt: new Date(),
    },
  };
};

const getPublicPage = async (url) => {
  try {
    const response = await axios.get(url, {
      headers: buildPublicPageHeaders(),
      timeout: 15000,
      validateStatus: () => true,
    });

    if (response.status < 200 || response.status >= 300) {
      return null;
    }
    return response.data;
  } catch (_) {
    return null;
  }
};

const fetchAudioUrlFromPublicPage = async ({ versionId, passageId }) => {
  const audioVersionId =
    AUDIO_BIBLE_ID_BY_TEXT_BIBLE_ID.get(versionId) ?? versionId;
  const html = await getPublicPage(
    `https://www.bible.com/audio-bible/${audioVersionId}/${encodeURIComponent(
      passageId
    )}`
  );
  if (!html) {
    return null;
  }
  return parseBibleDotComAudioPage(html);
};

const fetchChapterFromPublicPage = async ({
  versionId,
  bookId,
  chapterNumber,
  passageId,
}) => {
  const html = await getPublicPage(
    `https://www.bible.com/bible/${versionId}/${encodeURIComponent(passageId)}`
  );
  if (!html) {
    return null;
  }

  const parsed = parseBibleDotComChapterPage({
    html,
    fallbackBibleId: versionId,
    fallbackPassageId: passageId,
  });
  if (!parsed) {
    return null;
  }

  return mapChapterPayload({
    versionId,
    bookId,
    chapterNumber,
    content: parsed.content,
    verses: parsed.verses,
    audioUrl: parsed.audioUrl,
    sourceType: "provider",
    sourceProvider: "bible-dot-com",
  });
};

const fetchChapterFromApi = async ({
  versionId,
  bookId,
  chapterNumber,
  passageId,
}) => {
  if (!config.youVersionAppKey) {
    return null;
  }

  try {
    const url = `${YOUVERSION_BASE_URL}/bibles/${versionId}/passages/${encodeURIComponent(
      passageId
    )}`;
    const response = await axios.get(url, {
      headers: {
        "x-yvp-app-key": config.youVersionAppKey,
      },
      timeout: 15000,
    });

    const content = extractScriptureContent(response.data).trim();
    if (!content) {
      return null;
    }

    const verses = extractVersesFromContent(content);
    let audioUrl = null;
    try {
      audioUrl = await fetchAudioUrlFromPublicPage({ versionId, passageId });
    } catch (_) {
      // audio URL is optional — continue without it
    }

    return mapChapterPayload({
      versionId,
      bookId,
      chapterNumber,
      content,
      verses,
      audioUrl,
      sourceType: "provider",
      sourceProvider: "youversion-api",
    });
  } catch (error) {
    if (error.response && [401, 403].includes(error.response.status)) {
      throw new AppError(502, "YouVersion API rejected the request", {
        upstreamStatus: error.response.status,
      });
    }
    return null;
  }
};

const createScriptureProvider = () => ({
  async fetchChapter({ versionId, bookId, chapterNumber, passageId }) {
    const preferPublicPage = PUBLIC_PAGE_PREFERRED_BIBLE_IDS.has(versionId);

    if (!preferPublicPage) {
      const apiChapter = await fetchChapterFromApi({
        versionId,
        bookId,
        chapterNumber,
        passageId,
      });
      if (apiChapter) {
        return apiChapter;
      }
    }

    const publicChapter = await fetchChapterFromPublicPage({
      versionId,
      bookId,
      chapterNumber,
      passageId,
    });
    if (publicChapter) {
      return publicChapter;
    }

    if (preferPublicPage) {
      const apiChapter = await fetchChapterFromApi({
        versionId,
        bookId,
        chapterNumber,
        passageId,
      });
      if (apiChapter) {
        return apiChapter;
      }
    }

    throw new AppError(502, "Failed to fetch scripture content from providers");
  },
});

module.exports = {
  createScriptureProvider,
  scriptureProvider: createScriptureProvider(),
  extractVersesFromContent,
};
