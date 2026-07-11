const crypto = require("crypto");
const path = require("path");
const mongoose = require("mongoose");

require("dotenv").config({
  path: path.resolve(__dirname, "../.env"),
});

const Song = require("../src/models/Song");
const slugify = require("../src/utils/slugify");

const SOURCE_DB_NAME = "songs_db";
const SOURCE_COLLECTION_NAME = "songs";
const TARGET_DB_NAME = "bible_app";
const BATCH_SIZE = 500;

const LANGUAGE_CODE_BY_NAME = {
  english: "en",
  hindi: "hi",
  kannada: "kn",
  malayalam: "ml",
  telugu: "te",
};

const getMongoUri = () => {
  const uri = String(process.env.MONGO_URI || "").trim();
  if (!uri) {
    throw new Error("MONGO_URI is required");
  }
  return uri;
};

const normalizeText = (value) => String(value ?? "").trim();

const normalizeLanguageCode = (sourceSong) => {
  const explicitCode = normalizeText(
    sourceSong.languageCode || sourceSong.langCode || sourceSong.lang
  ).toLowerCase();
  if (/^[a-z]{2,3}(-[a-z0-9]+)?$/.test(explicitCode)) {
    return explicitCode;
  }

  const languageName = normalizeText(
    sourceSong.language || sourceSong.languageName
  ).toLowerCase();
  return LANGUAGE_CODE_BY_NAME[languageName] || "en";
};

const buildStableSlug = ({ title, sourceId }) => {
  const titleSlug = slugify(title);
  if (titleSlug) {
    return titleSlug;
  }

  const titleHash = crypto
    .createHash("sha1")
    .update(normalizeText(title).toLowerCase())
    .digest("hex")
    .slice(0, 12);

  return `song-${titleHash || slugify(sourceId)}`;
};

const normalizeLyricsSections = (sourceSong) => {
  if (Array.isArray(sourceSong.lyricsSections)) {
    return sourceSong.lyricsSections
      .map((section) => ({
        label: normalizeText(section.label) || null,
        text: normalizeText(section.text || section.lyrics || section.content),
      }))
      .filter((section) => section.text);
  }

  const lyrics = normalizeText(sourceSong.lyrics);
  if (!lyrics) {
    return [];
  }

  const lines = lyrics.split(/\r?\n/);
  const sections = [];
  let currentSection = null;
  let foundMarkers = false;

  const flushCurrentSection = () => {
    if (!currentSection) {
      return;
    }

    const text = normalizeText(currentSection.lines.join("\n"));
    if (text) {
      sections.push({
        label: currentSection.label,
        text,
      });
    }
  };

  for (const line of lines) {
    const markerMatch = /^\s*\[([^\]]+)\]\s*(.*)$/.exec(line);
    if (markerMatch) {
      foundMarkers = true;
      flushCurrentSection();
      currentSection = {
        label: normalizeText(markerMatch[1]) || null,
        lines: markerMatch[2] ? [markerMatch[2]] : [],
      };
      continue;
    }

    if (!currentSection) {
      currentSection = {
        label: null,
        lines: [],
      };
    }
    currentSection.lines.push(line);
  }

  flushCurrentSection();

  if (!foundMarkers || sections.length === 0) {
    return [
      {
        label: null,
        text: lyrics,
      },
    ];
  }

  return sections;
};

const buildTags = (sourceSong) => {
  const tags = new Set(["imported", SOURCE_DB_NAME]);

  if (Array.isArray(sourceSong.tags)) {
    for (const tag of sourceSong.tags) {
      const normalizedTag = normalizeText(tag);
      if (normalizedTag) {
        tags.add(normalizedTag);
      }
    }
  }

  const source = normalizeText(sourceSong.source);
  if (source) {
    tags.add(`source:${source}`);
  }

  return Array.from(tags);
};

const transformSong = (sourceSong) => {
  const title = normalizeText(sourceSong.title);
  if (!title) {
    return null;
  }

  const sourceId = normalizeText(sourceSong.songId || sourceSong.id || sourceSong._id);
  const languageCode = normalizeLanguageCode(sourceSong);
  const songId = normalizeText(sourceSong.songId || sourceSong.id) || sourceId;
  const slug = normalizeText(sourceSong.slug) || buildStableSlug({ title, sourceId });

  if (!songId || !slug || !languageCode) {
    return null;
  }

  return {
    songId,
    languageCode,
    title,
    slug,
    artist: normalizeText(sourceSong.artist) || null,
    lyricsSections: normalizeLyricsSections(sourceSong),
    audio: {
      provider: null,
      storageKey: null,
      url: null,
      file: null,
      durationSec: null,
    },
    tags: buildTags(sourceSong),
    isPublished:
      typeof sourceSong.isPublished === "boolean" ? sourceSong.isPublished : true,
  };
};

const getSongKey = (song) => `${song.languageCode}:${song.slug}`;

const getBulkWriteErrorSummary = (error) => {
  const writeErrors =
    error.writeErrors ||
    error.result?.getWriteErrors?.() ||
    error.result?.result?.writeErrors ||
    [];

  const duplicateErrors = writeErrors.filter((entry) => {
    const code = entry.code || entry.err?.code;
    return code === 11000;
  });

  return {
    insertedCount:
      error.result?.insertedCount ||
      error.result?.nInserted ||
      error.result?.result?.nInserted ||
      0,
    duplicateCount: duplicateErrors.length,
    failedCount: writeErrors.length - duplicateErrors.length,
    firstFailure: writeErrors.find((entry) => {
      const code = entry.code || entry.err?.code;
      return code !== 11000;
    }),
  };
};

const createInitialSummary = () => ({
  sourceTotal: 0,
  scanned: 0,
  prepared: 0,
  inserted: 0,
  skippedDuplicates: 0,
  skippedInvalid: 0,
  failed: 0,
  byLanguage: {},
});

const incrementLanguageSummary = (summary, languageCode) => {
  summary.byLanguage[languageCode] = (summary.byLanguage[languageCode] || 0) + 1;
};

const migrateSongs = async () => {
  await mongoose.connect(getMongoUri(), {
    autoIndex: false,
  });

  const targetDbName = mongoose.connection.db.databaseName;
  if (targetDbName !== TARGET_DB_NAME) {
    throw new Error(
      `Refusing to migrate into ${targetDbName}. MONGO_URI must point to ${TARGET_DB_NAME}.`
    );
  }

  await Song.init();

  const sourceDb = mongoose.connection.useDb(SOURCE_DB_NAME, {
    useCache: true,
  }).db;
  const sourceCollection = sourceDb.collection(SOURCE_COLLECTION_NAME);

  const summary = createInitialSummary();
  summary.sourceTotal = await sourceCollection.estimatedDocumentCount();

  const existingSongs = await Song.find({}, { languageCode: 1, slug: 1 })
    .lean()
    .exec();
  const seenSongKeys = new Set(existingSongs.map(getSongKey));

  const insertBatch = async (batch) => {
    if (batch.length === 0) {
      return;
    }

    try {
      const result = await Song.bulkWrite(
        batch.map((song) => ({
          insertOne: {
            document: song,
          },
        })),
        {
          ordered: false,
        }
      );
      summary.inserted += result.insertedCount || 0;
    } catch (error) {
      const errorSummary = getBulkWriteErrorSummary(error);
      summary.inserted += errorSummary.insertedCount;
      summary.skippedDuplicates += errorSummary.duplicateCount;
      summary.failed += errorSummary.failedCount;

      if (errorSummary.failedCount > 0) {
        const firstFailure = errorSummary.firstFailure?.err || errorSummary.firstFailure;
        throw new Error(
          `Bulk insert failed for ${errorSummary.failedCount} song(s): ${
            firstFailure?.errmsg || firstFailure?.message || error.message
          }`
        );
      }
    }
  };

  let batch = [];
  const songs = await sourceCollection.find({}).toArray();

  for (const song of songs) {
    summary.scanned += 1;

    const transformedSong = transformSong(song);
    if (!transformedSong) {
      summary.skippedInvalid += 1;
      continue;
    }

    const songKey = getSongKey(transformedSong);
    if (seenSongKeys.has(songKey)) {
      summary.skippedDuplicates += 1;
      continue;
    }

    seenSongKeys.add(songKey);
    summary.prepared += 1;
    incrementLanguageSummary(summary, transformedSong.languageCode);
    batch.push(transformedSong);

    if (batch.length >= BATCH_SIZE) {
      await insertBatch(batch);
      batch = [];
    }
  }

  await insertBatch(batch);

  const targetTotal = await Song.estimatedDocumentCount();

  return {
    source: `${SOURCE_DB_NAME}.${SOURCE_COLLECTION_NAME}`,
    target: `${TARGET_DB_NAME}.${Song.collection.collectionName}`,
    ...summary,
    targetTotal,
  };
};

migrateSongs()
  .then((summary) => {
    console.log("Song migration completed");
    console.log(JSON.stringify(summary, null, 2));
  })
  .catch((error) => {
    console.error("Song migration failed");
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
