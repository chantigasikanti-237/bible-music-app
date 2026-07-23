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

// Bible Brain serves its mp3s as "Content-Type: binary/octet-stream" rather
// than "audio/mpeg" (confirmed directly against their CDN), and from a
// third-party origin. Desktop Chrome tolerates that via content-sniffing,
// but the app's real target - an Android WebView - is typically much
// stricter about a mismatched Content-Type, so playback can silently fail
// there even though the file itself is a perfectly valid mp3. Proxying
// through our own server (same pattern already used for YouTube audio in
// audioService.js) serves it same-origin with the correct header instead of
// handing the client a cross-origin URL with a wrong one.
const streamChapterAudio = async ({ versionId, bookId, chapterNumber }, req, res) => {
  const resolved = await resolveBibleBrainAudioUrl({ versionId, bookId, chapterNumber });
  if (!resolved) {
    res.status(404).json({ success: false, message: "Audio not available for this chapter" });
    return;
  }

  try {
    const upstream = await axios.get(resolved.url, {
      responseType: "stream",
      headers: req.headers.range ? { Range: req.headers.range } : {},
      validateStatus: () => true,
    });

    res.status(upstream.status);
    res.setHeader("Content-Type", "audio/mpeg");
    res.setHeader("Accept-Ranges", "bytes");
    if (upstream.headers["content-length"]) {
      res.setHeader("Content-Length", upstream.headers["content-length"]);
    }
    if (upstream.headers["content-range"]) {
      res.setHeader("Content-Range", upstream.headers["content-range"]);
    }
    upstream.data.pipe(res);
    upstream.data.on("error", () => {
      if (!res.headersSent) res.status(502).end();
      else res.destroy();
    });
  } catch (_) {
    if (!res.headersSent) res.status(502).json({ success: false, message: "Failed to stream audio" });
  }
};

module.exports = { resolveBibleBrainAudioUrl, streamChapterAudio };
