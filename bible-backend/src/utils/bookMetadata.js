const fs = require("fs");
const path = require("path");

let cachedMetadata = null;
let cachedLocalizedTitles = null;

const metadataFilePath = path.resolve(
  __dirname,
  "../../../lib/config/bible_book_metadata.dart"
);

const titlesFilePath = path.resolve(
  __dirname,
  "../../../lib/config/bible_book_titles.dart"
);

const parseMetadataFile = () => {
  const raw = fs.readFileSync(metadataFilePath, "utf8");
  const matches = raw.matchAll(/BibleBookMetadata\(([\s\S]*?)\),/g);
  const books = [];

  for (const match of matches) {
    const block = match[1];
    const id = /id:\s'([^']+)'/.exec(block)?.[1] || "";
    const englishTitle = /englishTitle:\s'([^']+)'/.exec(block)?.[1] || "";
    const teluguTitle = /teluguTitle:\s'([^']+)'/.exec(block)?.[1] || "";
    const chapterCount = Number.parseInt(
      /chapterCount:\s(\d+)/.exec(block)?.[1] || "0",
      10
    );
    const canon = /canon:\s'([^']+)'/.exec(block)?.[1] || "";

    if (!id || !englishTitle) {
      continue;
    }

    books.push({
      id,
      englishTitle,
      teluguTitle,
      chapterCount,
      canon,
      audioSlug: englishTitle
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "_")
        .replace(/^_+|_+$/g, ""),
    });
  }

  return books;
};

// Parse localizedBibleBookTitles from Dart map file
// Returns { 'hi': { 'GEN': 'उत्पत्ति', ... }, 'te': { ... }, ... }
const parseLocalizedTitles = () => {
  const raw = fs.readFileSync(titlesFilePath, "utf8");
  const result = {};

  // Match each language block: 'xx': <String, String>{ ... },
  const langBlockRe = /'([a-z]{2})':\s*<String,\s*String>\{([\s\S]*?)\},/g;
  for (const langMatch of raw.matchAll(langBlockRe)) {
    const langCode = langMatch[1];
    const blockContent = langMatch[2];
    const books = {};
    const entryRe = /'([A-Z0-9]+)':\s*'([^']+)'/g;
    for (const entryMatch of blockContent.matchAll(entryRe)) {
      books[entryMatch[1]] = entryMatch[2];
    }
    result[langCode] = books;
  }

  return result;
};

const getBookMetadataList = () => {
  if (!cachedMetadata) {
    cachedMetadata = parseMetadataFile();
  }
  return cachedMetadata;
};

const getLocalizedTitles = () => {
  if (!cachedLocalizedTitles) {
    cachedLocalizedTitles = parseLocalizedTitles();
  }
  return cachedLocalizedTitles;
};

// Return localized title for a bookId + languageCode, fallback to englishTitle
const getLocalizedBookTitle = (bookId, languageCode) => {
  const normalizedLang = String(languageCode || "").trim().toLowerCase();
  const normalizedId = String(bookId || "").trim().toUpperCase();

  if (normalizedLang && normalizedLang !== "en") {
    const titles = getLocalizedTitles();
    const localized = titles[normalizedLang]?.[normalizedId];
    if (localized) return localized;
  }

  const meta = findBookMetadataById(normalizedId);
  return meta?.englishTitle || normalizedId;
};

const findBookMetadataById = (bookId) => {
  const normalizedBookId = String(bookId ?? "").trim().toUpperCase();
  return (
    getBookMetadataList().find((book) => book.id === normalizedBookId) || null
  );
};

const findBookMetadataByTitle = (bookTitle, languageCode = "en") => {
  const normalizedBookTitle = String(bookTitle ?? "").trim().toLowerCase();
  if (!normalizedBookTitle) {
    return null;
  }

  return (
    getBookMetadataList().find((book) => {
      const titles = [book.englishTitle];
      if (book.teluguTitle) {
        titles.push(book.teluguTitle);
      }
      if (languageCode === "te" && book.teluguTitle) {
        titles.unshift(book.teluguTitle);
      }
      return titles.some(
        (title) => String(title).trim().toLowerCase() === normalizedBookTitle
      );
    }) || null
  );
};

module.exports = {
  getBookMetadataList,
  getLocalizedTitles,
  getLocalizedBookTitle,
  findBookMetadataById,
  findBookMetadataByTitle,
};
