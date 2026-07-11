require("dotenv").config();

const fs = require("fs");
const path = require("path");

const logger = require("../config/logger");
const { validateEnv } = require("../config/env");
const { connectDB, disconnectDB } = require("../config/db");
const { closeRedis } = require("../config/redis");
const { bibleChapterRepository } = require("../repositories/bibleChapterRepository");
const { bibleVerseRepository } = require("../repositories/bibleVerseRepository");
const { songRepository } = require("../repositories/songRepository");
const { findBookMetadataByTitle } = require("../utils/bookMetadata");
const { buildPassageId } = require("../utils/passage");
const slugify = require("../utils/slugify");
const { transliterateTitle } = require("../utils/transliterate");

const LOCAL_DATA_FILES = [
  {
    languageCode: "en",
    versionId: 111,
    sourcePath: path.resolve(__dirname, "../../../lib/data/en.json"),
  },
  {
    languageCode: "te",
    versionId: 1787,
    sourcePath: path.resolve(__dirname, "../../../lib/data/te.json"),
  },
];

const SONGS_FILE_PATH = path.resolve(__dirname, "../../../lib/data/songs.json");

const readJsonFile = (filePath) =>
  JSON.parse(fs.readFileSync(filePath, "utf8"));

const mapChapterPayload = ({
  versionId,
  languageCode,
  bookId,
  bookName,
  chapterNumber,
  verseTexts,
}) => {
  const verses = verseTexts.map((text, index) => ({
    number: index + 1,
    text: String(text ?? "").trim(),
  }));

  return {
    versionId,
    languageCode,
    bookId,
    bookName,
    chapterNumber,
    passageId: buildPassageId(bookId, chapterNumber),
    verseCount: verses.length,
    content: verses.map((verse) => `${verse.number} ${verse.text}`).join("\n"),
    verses,
    audio: {
      provider: null,
      url: null,
      storageKey: null,
    },
    source: {
      type: "import",
      provider: "bundled-json",
      fetchedAt: new Date(),
    },
  };
};

const inferSongLanguageCode = (song) => {
  const file = String(song.file || "").trim().toLowerCase();
  const match = /assets\/audio\/([^/]+)\//.exec(file);
  return match?.[1] || "en";
};

const importBibleContent = async () => {
  let importedChapterCount = 0;
  let importedVerseCount = 0;

  for (const entry of LOCAL_DATA_FILES) {
    const payload = readJsonFile(entry.sourcePath);
    for (const [bookTitle, chapters] of Object.entries(payload)) {
      const metadata = findBookMetadataByTitle(bookTitle, entry.languageCode);
      if (!metadata) {
        logger.warn("Skipping bundled Bible book with unknown metadata", {
          languageCode: entry.languageCode,
          bookTitle,
        });
        continue;
      }

      for (const [chapterKey, verseTexts] of Object.entries(chapters || {})) {
        const chapterNumber = Number(chapterKey);
        if (!Number.isInteger(chapterNumber) || chapterNumber <= 0) {
          continue;
        }
        if (!Array.isArray(verseTexts) || verseTexts.length === 0) {
          continue;
        }

        const chapterPayload = mapChapterPayload({
          versionId: entry.versionId,
          languageCode: entry.languageCode,
          bookId: metadata.id,
          bookName:
            entry.languageCode === "te" && metadata.teluguTitle
              ? metadata.teluguTitle
              : metadata.englishTitle,
          chapterNumber,
          verseTexts,
        });
        await bibleChapterRepository.upsertChapter(chapterPayload);
        await bibleVerseRepository.replaceChapterVerses(chapterPayload);
        importedChapterCount += 1;
        importedVerseCount += chapterPayload.verseCount;
      }
    }
  }

  return {
    importedChapterCount,
    importedVerseCount,
  };
};

const importSongs = async () => {
  const songs = readJsonFile(SONGS_FILE_PATH);
  let importedSongCount = 0;

  for (const song of songs) {
    const languageCode = inferSongLanguageCode(song);
    const title = String(song.title || "").trim();
    const slug = slugify(title || song.id);
    const songId = String(song.id || slug).trim();
    if (!songId || !slug || !title) {
      continue;
    }

    await songRepository.upsertSong({
      songId,
      languageCode,
      title,
      titleRomanized: transliterateTitle(title, languageCode),
      slug,
      artist: String(song.artist || "").trim() || null,
      lyricsSections: [],
      audio: {
        provider: "bundled-asset",
        storageKey: String(song.file || "").trim() || null,
        url: null,
        file: String(song.file || "").trim() || null,
        durationSec: null,
      },
      tags: ["bundled"],
      isPublished: true,
    });
    importedSongCount += 1;
  }

  return {
    importedSongCount,
  };
};

const main = async () => {
  validateEnv();
  await connectDB();

  const bibleImport = await importBibleContent();
  const songsImport = await importSongs();

  logger.info("Bundled content import completed", {
    ...bibleImport,
    ...songsImport,
  });
};

main()
  .catch((error) => {
    logger.error("Bundled content import failed", {
      error: error.message,
      stack: error.stack || null,
    });
    process.exitCode = 1;
  })
  .finally(async () => {
    await closeRedis();
    await disconnectDB();
  });
