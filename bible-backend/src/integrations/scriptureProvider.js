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

const parseVerseNumberFromTitle = (entry) => {
  const fromTitle = Number.parseInt(String(entry?.title ?? ""), 10);
  if (Number.isFinite(fromTitle)) {
    return fromTitle;
  }
  const lastSegment = String(entry?.passage_id ?? "").split(".").pop();
  const fromPassageId = Number.parseInt(lastSegment, 10);
  return Number.isFinite(fromPassageId) ? fromPassageId : null;
};

// The API's /passages/:passageId endpoint returns an entire chapter as one
// flat, unnumbered block of text with no verse boundaries at all - fine for
// display, useless for anything that needs a specific verse (bookmarking,
// notes, "jump to verse 16", sharing a single verse). /verses lists which
// verses exist in the chapter (numbers + their own single-verse passage
// IDs, e.g. GEN.1.16) but not their text; re-requesting /passages/ with
// each of those single-verse IDs does return that verse's own text alone -
// so building a proper verses array means one list call plus one call per
// verse. Heavier than the old single-request approach, but this only ever
// runs once per chapter (the result is cached in Mongo forever afterward).
const fetchVersesFromApi = async ({ versionId, bookId, chapterNumber }) => {
  const listUrl = `${YOUVERSION_BASE_URL}/bibles/${versionId}/books/${encodeURIComponent(
    bookId
  )}/chapters/${chapterNumber}/verses`;
  const listResponse = await axios.get(listUrl, {
    headers: { "x-yvp-app-key": config.youVersionAppKey },
    timeout: 15000,
  });
  const entries = Array.isArray(listResponse.data?.data)
    ? listResponse.data.data
    : [];
  if (entries.length === 0) {
    return [];
  }

  const results = await Promise.all(
    entries.map(async (entry) => {
      const number = parseVerseNumberFromTitle(entry);
      const versePassageId =
        typeof entry?.passage_id === "string" && entry.passage_id.trim()
          ? entry.passage_id.trim()
          : null;
      if (!number || !versePassageId) {
        return null;
      }
      try {
        const verseResponse = await axios.get(
          `${YOUVERSION_BASE_URL}/bibles/${versionId}/passages/${encodeURIComponent(
            versePassageId
          )}`,
          { headers: { "x-yvp-app-key": config.youVersionAppKey }, timeout: 15000 }
        );
        const text = extractScriptureContent(verseResponse.data).trim();
        return text ? { number, text } : null;
      } catch (_) {
        return null;
      }
    })
  );

  return results.filter(Boolean).sort((left, right) => left.number - right.number);
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
    const verses = await fetchVersesFromApi({ versionId, bookId, chapterNumber });
    if (verses.length === 0) {
      return null;
    }

    const content = verses.map((verse) => `${verse.number} ${verse.text}`).join("\n");
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
  } catch (_) {
    // Covers a bad/missing key same as any other API failure - now that this
    // runs first for every version instead of as a last resort, throwing
    // here would skip the bible.com fallback entirely for whichever
    // translations the key doesn't happen to cover.
    return null;
  }
};

const createScriptureProvider = () => ({
  // The licensed YouVersion API is the real, supported access path (see the
  // account's active Bible Licensing agreements) - tried first for every
  // version. Scraping bible.com's public page is a fallback only, for
  // whatever the API doesn't happen to return (or has no key for), not the
  // default: unlike the API, a scrape is subject to bible.com rate-limiting/
  // blocking specific requester IPs, which doesn't discriminate by license.
  async fetchChapter({ versionId, bookId, chapterNumber, passageId }) {
    const apiChapter = await fetchChapterFromApi({
      versionId,
      bookId,
      chapterNumber,
      passageId,
    });
    if (apiChapter) {
      return apiChapter;
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

    throw new AppError(502, "Failed to fetch scripture content from providers");
  },
});

module.exports = {
  createScriptureProvider,
  scriptureProvider: createScriptureProvider(),
  extractVersesFromContent,
};
