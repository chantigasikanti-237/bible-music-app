const decodeHtmlEntities = (value) =>
  String(value ?? "")
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) =>
      String.fromCodePoint(Number.parseInt(hex, 16))
    )
    .replace(/&#(\d+);/g, (_, decimal) =>
      String.fromCodePoint(Number.parseInt(decimal, 10))
    )
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">");

const cleanPlainText = (value) =>
  decodeHtmlEntities(String(value ?? ""))
    .replace(/<[^>]*>/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const extractNextDataJson = (html) => {
  const match =
    /<script id="__NEXT_DATA__" type="application\/json">([\s\S]*?)<\/script>/i.exec(
      String(html ?? "")
    );
  return match ? match[1] : null;
};

const asObject = (value) =>
  value && typeof value === "object" && !Array.isArray(value) ? value : null;

const asString = (value) => {
  if (typeof value !== "string") {
    return null;
  }

  const trimmed = value.trim();
  return trimmed ? trimmed : null;
};

const normalizeExternalUrl = (value) => {
  const normalized = asString(value);
  if (!normalized) {
    return null;
  }
  if (normalized.startsWith("//")) {
    return `https:${normalized}`;
  }
  return normalized;
};

const parseVerseNumber = (usfm) => {
  const normalized = asString(usfm);
  if (!normalized) {
    return null;
  }

  const parts = normalized.split(".");
  if (parts.length === 0) {
    return null;
  }

  const parsed = Number.parseInt(parts[parts.length - 1], 10);
  return Number.isFinite(parsed) ? parsed : null;
};

const parseVerseNumberFromLabel = (value) => {
  const match = /^\s*(\d{1,3})\b/.exec(String(value ?? ""));
  if (!match) {
    return null;
  }

  const parsed = Number.parseInt(match[1], 10);
  return Number.isFinite(parsed) ? parsed : null;
};

const extractBalancedSpan = (html, startIndex) => {
  const openingEnd = html.indexOf(">", startIndex);
  if (openingEnd === -1) {
    return null;
  }

  let cursor = openingEnd + 1;
  let depth = 1;
  while (cursor < html.length) {
    const nextOpen = html.indexOf("<span", cursor);
    const nextClose = html.indexOf("</span>", cursor);
    if (nextClose === -1) {
      return null;
    }

    if (nextOpen !== -1 && nextOpen < nextClose) {
      depth += 1;
      cursor = nextOpen + 5;
      continue;
    }

    depth -= 1;
    cursor = nextClose + 7;
    if (depth === 0) {
      return html.slice(startIndex, cursor);
    }
  }

  return null;
};

const extractTextFromSpansByClass = (html, className) => {
  const results = [];
  let searchIdx = 0;
  const searchStr = `<span class="${className}"`;

  while (searchIdx < html.length) {
    const startIdx = html.indexOf(searchStr, searchIdx);
    if (startIdx === -1) {
      break;
    }

    const spanHtml = extractBalancedSpan(html, startIdx);
    if (!spanHtml) {
      const tagEnd = html.indexOf('>', startIdx);
      searchIdx = tagEnd !== -1 ? tagEnd + 1 : startIdx + 1;
      continue;
    }

    const openingEnd = spanHtml.indexOf('>');
    if (openingEnd !== -1) {
      results.push(spanHtml.slice(openingEnd + 1, spanHtml.length - 7));
    }

    searchIdx = startIdx + spanHtml.length;
  }

  return results;
};

const extractVersesFromChapterHtml = (chapterHtml) => {
  const html = String(chapterHtml ?? "");
  const verseTextByNumber = new Map();
  let searchIndex = 0;

  while (searchIndex < html.length) {
    const startIndex = html.indexOf('<span class="verse', searchIndex);
    if (startIndex === -1) {
      break;
    }

    const verseHtml = extractBalancedSpan(html, startIndex);
    if (!verseHtml) {
      const tagEnd = html.indexOf('>', startIndex);
      searchIndex = tagEnd !== -1 ? tagEnd + 1 : startIndex + 1;
      continue;
    }

    searchIndex = startIndex + verseHtml.length;

    const dataUsfmMatch = /data-usfm="([^"]+)"/i.exec(verseHtml);
    const verseNumber =
      parseVerseNumber(dataUsfmMatch ? dataUsfmMatch[1] : null) ||
      parseVerseNumberFromLabel(cleanPlainText(verseHtml));
    if (!verseNumber) {
      continue;
    }

    const contentParts = extractTextFromSpansByClass(verseHtml, 'content');
    const mergedSegment = cleanPlainText(contentParts.join(' '));
    if (!mergedSegment) {
      continue;
    }

    const previous = verseTextByNumber.get(verseNumber);
    verseTextByNumber.set(
      verseNumber,
      previous ? cleanPlainText(`${previous} ${mergedSegment}`) : mergedSegment
    );
  }

  return [...verseTextByNumber.entries()]
    .sort((left, right) => left[0] - right[0])
    .map(([number, text]) => ({ number, text }))
    .filter((verse) => verse.text);
};

const extractPublicPageAudioUrl = (chapterInfo) => {
  const normalizedChapterInfo = asObject(chapterInfo);
  const audioChapterInfo = normalizedChapterInfo?.audioChapterInfo;
  if (!Array.isArray(audioChapterInfo) || audioChapterInfo.length === 0) {
    return null;
  }

  const firstAudio = asObject(audioChapterInfo[0]);
  const downloadUrls = asObject(firstAudio?.download_urls);
  if (!downloadUrls) {
    return null;
  }

  return (
    normalizeExternalUrl(downloadUrls.format_mp3_64k) ||
    normalizeExternalUrl(downloadUrls.format_mp3_128k) ||
    normalizeExternalUrl(downloadUrls.format_mp3_32k) ||
    normalizeExternalUrl(downloadUrls.format_hls)
  );
};

const parseBibleDotComChapterPage = ({
  html,
  fallbackBibleId,
  fallbackPassageId,
}) => {
  const nextDataJson = extractNextDataJson(html);
  if (!nextDataJson) {
    return null;
  }

  let decoded;
  try {
    decoded = JSON.parse(nextDataJson);
  } catch (_) {
    return null;
  }

  const root = asObject(decoded);
  const pageProps = asObject(asObject(root?.props)?.pageProps);
  const chapterInfo = asObject(pageProps?.chapterInfo);
  const chapterHtml = asString(chapterInfo?.content);
  if (!chapterHtml) {
    return null;
  }

  const verses = extractVersesFromChapterHtml(chapterHtml);
  if (verses.length === 0) {
    return null;
  }

  const versionData = asObject(pageProps?.versionData);
  const resolvedBibleId = Number.parseInt(versionData?.id, 10);
  return {
    bibleId: Number.isFinite(resolvedBibleId)
      ? resolvedBibleId
      : fallbackBibleId,
    passageId: asString(pageProps?.passageId) || fallbackPassageId,
    content: verses.map((verse) => `${verse.number} ${verse.text}`.trim()).join("\n"),
    audioUrl: extractPublicPageAudioUrl(chapterInfo),
    verses,
  };
};

const parseBibleDotComAudioPage = (html) => {
  const nextDataJson = extractNextDataJson(html);
  if (!nextDataJson) {
    return null;
  }

  let decoded;
  try {
    decoded = JSON.parse(nextDataJson);
  } catch (_) {
    return null;
  }

  const root = asObject(decoded);
  const pageProps = asObject(asObject(root?.props)?.pageProps);
  const chapterInfo = asObject(pageProps?.chapterInfo);
  return extractPublicPageAudioUrl(chapterInfo);
};

module.exports = {
  parseBibleDotComAudioPage,
  parseBibleDotComChapterPage,
};
