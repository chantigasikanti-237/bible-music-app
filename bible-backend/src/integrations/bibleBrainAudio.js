const axios = require("axios");

const { config } = require("../config/env");
const { findBookMetadataById } = require("../utils/bookMetadata");

const BIBLE_BRAIN_BASE_URL = "https://4.dbt.io/api";

// Bible Brain (Faith Comes By Hearing) fileset IDs for the audio Bible
// matching each version we already use for text. Only versions with a real,
// licensed Bible Brain audio recording are listed here — everything else
// keeps falling back to whatever scriptureProvider already does for audio.
const FILESET_BY_VERSION_ID = new Map([
  [111, { ot: "ENGKJVO1DA", nt: "ENGKJVN1DA" }], // English (KJV)
  [1895, { ot: "TELDPIO1DA", nt: "TELDPIN1DA" }], // Telugu IRV
  [1980, { ot: "HINDPIO1DA", nt: "HINBCSN1DA" }], // Hindi IRV
  [1899, { ot: "TAMDPIO1DA", nt: "TAMDPIN1DA" }], // Tamil IRV
  [1912, { ot: "MALDPIO1DA", nt: "MALDPIN1DA" }], // Malayalam IRV
  [1898, { ot: "KANDPIO1DA", nt: "KANDPIN1DA" }], // Kannada IRV
  [1910, { ot: "MARDPIO1DA", nt: "MARDPIN1DA" }], // Marathi IRV
  [1884, { ot: "PANDPIO1DA", nt: "PANDPIN1DA" }], // Punjabi IRV
  [1979, { ot: "ASMDPIO1DA", nt: "ASMDPIN1DA" }], // Assamese IRV
  [1883, { ot: "BENDPIO1DA", nt: "BENDPIN1DA" }], // Bengali IRV
]);

// Resolves a live, playable audio URL for one chapter via the licensed Bible
// Brain API. Returns null (never throws) whenever this version/chapter isn't
// covered or the lookup fails, so callers can fall back to whatever audio is
// already on the chapter without special-casing errors.
const resolveBibleBrainAudioUrl = async ({ versionId, bookId, chapterNumber }) => {
  if (!config.bibleBrainApiKey) {
    return null;
  }

  const filesets = FILESET_BY_VERSION_ID.get(versionId);
  if (!filesets) {
    return null;
  }

  const metadata = findBookMetadataById(bookId);
  const filesetId = metadata?.canon === "NT" ? filesets.nt : filesets.ot;
  if (!filesetId) {
    return null;
  }

  try {
    const response = await axios.get(
      `${BIBLE_BRAIN_BASE_URL}/bibles/filesets/${filesetId}/${bookId}/${chapterNumber}`,
      { params: { v: 4, key: config.bibleBrainApiKey }, timeout: 15000 }
    );
    const entry = response.data?.data?.[0];
    const url = typeof entry?.path === "string" ? entry.path.trim() : "";
    if (!url) {
      return null;
    }
    return { provider: "bible-brain", url, duration: entry.duration ?? null };
  } catch (_) {
    return null;
  }
};

module.exports = { resolveBibleBrainAudioUrl };
