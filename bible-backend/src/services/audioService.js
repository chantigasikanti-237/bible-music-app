const axios = require("axios");

const AppError = require("../utils/AppError");
const { ensureRedisConnection } = require("../config/redis");
const { config } = require("../config/env");

// yt-dlp options merged into every YouTube-facing call below — adds a proxy
// when YTDLP_PROXY_URL is configured, a no-op spread otherwise.
const ytdlpProxyOpts = () => (config.ytdlpProxyUrl ? { proxy: config.ytdlpProxyUrl } : {});

const YOUTUBE_SEARCH_URL = "https://www.googleapis.com/youtube/v3/search";
const YOUTUBE_VIDEOS_URL = "https://www.googleapis.com/youtube/v3/videos";
const MUSIC_VIDEO_CATEGORY_ID = "10";
const SONGS_PER_PAGE = 50;
const SONGS_TARGET = 100; // 2 pages per language; cached 24 h
const SONGS_DISPLAY_COUNT = 100; // full pool served per request
const SONGS_CACHE_TTL_SECONDS = 86400; // 24 hours — hard expiry if truly nobody asks
// How long cached list data is served without a background refresh. Shorter
// than the hard TTL above: a request for data older than this still gets an
// instant response from cache, but also kicks off a background refetch so
// the *next* request sees newer data — refresh only happens for combos
// someone actually asked for, so idle content never costs quota.
const LIST_FRESH_TTL_MS = 60 * 60 * 1000; // 1 hour

// How many songs at the top of a freshly-served list get their playback URL
// resolved in the background right away. Without this, the audio_url cache
// only warms when a user actually taps play — so the first tap on any list
// pays yt-dlp's ~5s resolution cost live. Resolving ahead of time means it's
// usually already cached by the time someone taps.
const PREWARM_TOP_N = 3;

// YouTube Shorts / status videos are typically ≤ 60 s — block anything under this threshold
const MIN_SONG_DURATION_SECONDS = 62;

// Videos at or above this length are "mixes" — long non-stop compilations,
// not individual songs. They belong exclusively in the "longmix" category;
// every other list (Trending, Hymns Mix, search, etc.) caps duration below
// this so a 1-hour compilation doesn't also show up as a "song" elsewhere.
const LONG_MIX_THRESHOLD_SECONDS = 20 * 60;

// Trending categories — each maps to a search-query suffix appended after the
// language name. "longmix" flips the usual upper bound into a floor of 20
// minutes, surfacing the non-stop compilation videos instead of songs.
const CATEGORIES = {
  hymns: { label: "Hymns Mix", querySuffix: "Christian Hymns Mix Compilation", maxDurationSeconds: LONG_MIX_THRESHOLD_SECONDS },
  longmix: { label: "Non-Stop Worship", querySuffix: "Nonstop Christian Worship Songs Mix", minDurationSeconds: LONG_MIX_THRESHOLD_SECONDS },
};

// YouTube signed audio URLs expire after ~6 h; cache them for 3 h to be safe
const AUDIO_URL_CACHE_TTL = 3 * 3600;

// Dedup concurrent yt-dlp calls for the same videoId (e.g. double-tap)
const _inflight = new Map();

// Guards against firing multiple overlapping background revalidations for
// the same list cache key while one is already in flight.
const _revalidating = new Set();

const shuffleSongs = (songs) => {
  const result = [...songs];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
};

if (!process.env.YOUTUBE_API_KEY) {
  console.warn(
    "[audioService] YOUTUBE_API_KEY is not set — audio/songs endpoints will return 503 until it is configured."
  );
}

const namedHtmlEntities = Object.freeze({
  amp: "&",
  apos: "'",
  gt: ">",
  lt: "<",
  quot: '"',
});

const sanitizeLanguage = (language) =>
  String(language ?? "")
    .trim()
    .replace(/\s+/g, " ")
    .slice(0, 80);

const decodeHtmlEntities = (value) =>
  String(value ?? "")
    .replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (match, entity) => {
      const normalizedEntity = entity.toLowerCase();

      if (normalizedEntity.startsWith("#x")) {
        const codePoint = Number.parseInt(normalizedEntity.slice(2), 16);
        return Number.isFinite(codePoint)
          ? String.fromCodePoint(codePoint)
          : match;
      }

      if (normalizedEntity.startsWith("#")) {
        const codePoint = Number.parseInt(normalizedEntity.slice(1), 10);
        return Number.isFinite(codePoint)
          ? String.fromCodePoint(codePoint)
          : match;
      }

      return namedHtmlEntities[normalizedEntity] || match;
    })
    .replace(/\s+/g, " ")
    .trim();

// Parse ISO 8601 duration string (e.g. "PT1M2S", "PT45S") → total seconds
const parseIso8601Duration = (duration) => {
  if (!duration) return null;
  const m = duration.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/);
  if (!m) return null;
  return (parseInt(m[1] || "0", 10) * 3600)
       + (parseInt(m[2] || "0", 10) * 60)
       +  parseInt(m[3] || "0", 10);
};

// Batch-fetch contentDetails for up to 50 video IDs; returns Map<videoId, durationSeconds>
const fetchDurations = async (httpClient, videoIds, apiKey) => {
  if (!videoIds.length) return new Map();
  try {
    const response = await httpClient.get(YOUTUBE_VIDEOS_URL, {
      params: {
        part: "contentDetails",
        id: videoIds.join(","),
        key: apiKey,
        maxResults: 50,
      },
      timeout: 10000,
    });
    const map = new Map();
    for (const item of (response.data?.items || [])) {
      const secs = parseIso8601Duration(item?.contentDetails?.duration);
      if (secs !== null) map.set(item.id, secs);
    }
    return map;
  } catch (err) {
    // Non-fatal: if duration lookup fails we let all through
    console.warn("[audioService] fetchDurations failed:", err.message);
    return new Map();
  }
};

const mapYouTubeItemToSong = (item) => {
  const snippet = item?.snippet || {};
  const thumbnails = snippet.thumbnails || {};

  return {
    id: String(item?.id?.videoId || ""),
    title: decodeHtmlEntities(snippet.title),
    thumbnail:
      thumbnails.high?.url ||
      thumbnails.medium?.url ||
      thumbnails.default?.url ||
      "",
    channelTitle: decodeHtmlEntities(snippet.channelTitle),
    publishedAt: snippet.publishedAt || null,
  };
};

const youtubedl = require("youtube-dl-exec");
const https = require("https");
const http = require("http");

// Search YouTube via yt-dlp (no API key required — used as quota fallback).
// Two parallel queries of 20 each (40 total) — keeps each search fast (~5s)
// while doubling results. Results are deduplicated by video ID.
const YTDLP_SEARCH_COUNT = 35;

const _runYtdlpSearch = async (
  query,
  minDurationSeconds = MIN_SONG_DURATION_SECONDS,
  maxDurationSeconds = LONG_MIX_THRESHOLD_SECONDS
) => {
  try {
    const result = await youtubedl(`ytsearch${YTDLP_SEARCH_COUNT}:${query}`, {
      dumpSingleJson: true,
      noWarnings: true,
      flatPlaylist: true,
      ...ytdlpProxyOpts(),
    });
    return (result?.entries || [])
      .filter((e) => e.id && e.title && (e.duration == null || (e.duration >= minDurationSeconds && e.duration < maxDurationSeconds)))
      .map((e) => ({
        id: String(e.id),
        title: String(e.title || "").trim(),
        thumbnail: e.thumbnail || (e.thumbnails?.[0]?.url) || "",
        channelTitle: String(e.channel || e.uploader || "").trim(),
        publishedAt: null,
      }));
  } catch (err) {
    console.error(`[audioService] yt-dlp search failed (${query}):`, err.message);
    return [];
  }
};

const _dedupe = (batches) => {
  const seen = new Set();
  const combined = [];
  for (const track of batches.flat()) {
    if (!seen.has(track.id)) {
      seen.add(track.id);
      combined.push(track);
    }
  }
  return combined;
};

const searchWithYtdlpCategory = async (query, minDurationSeconds, maxDurationSeconds = LONG_MIX_THRESHOLD_SECONDS) => {
  const results = await _runYtdlpSearch(query, minDurationSeconds, maxDurationSeconds);
  return results.filter(_isChristianContent);
};

const searchWithYtdlp = async (language) => {
  const [batch1, batch2, batch3] = await Promise.all([
    _runYtdlpSearch(`${language} Christian Songs worship`),
    _runYtdlpSearch(`${language} Jesus Songs praise`),
    _runYtdlpSearch(`${language} devotional gospel songs`),
  ]);
  return _dedupe([batch1, batch2, batch3]);
};

// Keywords that strongly indicate non-Christian / secular / movie content.
// If a title or channel contains any of these (case-insensitive) it is dropped.
const SECULAR_BLOCK_PATTERNS = [
  /\b(movie|film|cinema|bollywood|tollywood|kollywood|mollywood|sandalwood|lollywood)\b/i,
  /\b(item\s*song|dance\s*number|dance\s*song|bar\s*song|cabaret)\b/i,
  /\b(romantic|love\s*song|breakup|sad\s*song|party\s*song|club\s*song|dj\s*remix|remix)\b/i,
  /\b(album|movie\s*songs|film\s*songs|songs?\s*jukebox|audio\s*jukebox)\b/i,
  /\b(video\s*song|lyric\s*video|full\s*movie|trailer|teaser|promo)\b/i,
];

// Keywords that confirm Christian / gospel content — at least one must be present.
const CHRISTIAN_ALLOW_PATTERNS = [
  /\b(christian|gospel|worship|praise|devotional|hymn|church|jesus|christ|god|lord|holy|prayer|bible|blessed|glory|amen|hallelujah|savior|saviour|sanctuary|revival)\b/i,
  /\b(carnatic\s*christian|telugu\s*christian|hindi\s*christian|tamil\s*christian|malayalam\s*christian|kannada\s*christian|marathi\s*christian)\b/i,
];

const _isChristianContent = (track) => {
  const text = `${track.title} ${track.channelTitle}`.toLowerCase();
  // Block if secular markers found
  if (SECULAR_BLOCK_PATTERNS.some((re) => re.test(text))) return false;
  // Allow if Christian markers found
  if (CHRISTIAN_ALLOW_PATTERNS.some((re) => re.test(text))) return true;
  // Default: allow (search already includes Christian keywords, so most results should be fine)
  return true;
};

const searchSongsByQuery = async (query) => {
  // Always append Christian context so YouTube returns relevant results
  const christianQuery = `${query} Christian worship song`;
  const results = await _runYtdlpSearch(christianQuery);
  // _runYtdlpSearch's default max duration already excludes long mixes, so
  // search results are always regular-length songs.
  return results.filter(_isChristianContent).map((s) => ({ ...s, isLongMix: false }));
};

const isQuotaExceeded = (error) => {
  if (error.response?.status === 429) return true;
  const errors = error.response?.data?.error?.errors;
  if (Array.isArray(errors)) {
    return errors.some(
      (e) => e.reason === "quotaExceeded" || e.reason === "rateLimitExceeded"
    );
  }
  return false;
};

// In-process fallback cache, checked before Redis. Without this, every cache
// "hit" still cost a network round trip to Redis (or, with no REDIS_URL set
// at all, silently never cached anything — every request re-ran the full
// YouTube search / yt-dlp resolution, 1-6+ seconds each time). A plain Map
// lookup is sub-millisecond and needs no external service, so this is what
// actually gets responses down to milliseconds in this environment. It also
// speeds up the Redis-backed path: repeat requests on the same process skip
// the Redis round trip entirely instead of paying ~1-5ms every time.
const memoryCache = new Map(); // key -> { value, expiresAt }

const memoryCacheGet = (key) => {
  const entry = memoryCache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    memoryCache.delete(key);
    return null;
  }
  return entry.value;
};

const memoryCacheSet = (key, value, ttlSeconds) => {
  memoryCache.set(key, { value, expiresAt: Date.now() + ttlSeconds * 1000 });
};

const prewarmTopSongs = (songs, service) => {
  for (const song of songs.slice(0, PREWARM_TOP_N)) {
    service.getStreamUrl(song.id).catch(() => {});
  }
};

const createAudioService = ({ httpClient = axios } = {}) => {
  const songCacheGet = async (key) => {
    const inMemory = memoryCacheGet(key);
    if (inMemory !== null) return inMemory;

    const client = await ensureRedisConnection();
    if (!client) return null;
    try {
      const raw = await client.get(key);
      return raw ? JSON.parse(raw) : null;
    } catch (err) {
      console.warn(`[audioService] Cache GET failed for key "${key}":`, err.message);
      return null;
    }
  };

  const songCacheSet = async (key, value, ttl = SONGS_CACHE_TTL_SECONDS) => {
    memoryCacheSet(key, value, ttl);

    const client = await ensureRedisConnection();
    if (!client) return;
    try {
      await client.set(key, JSON.stringify(value), "EX", ttl);
    } catch (err) {
      console.warn(`[audioService] Cache SET failed for key "${key}":`, err.message);
    }
  };

  // Stale-while-revalidate for song lists. A cache hit is always returned
  // immediately, even if older than LIST_FRESH_TTL_MS — the caller never
  // waits on YouTube/yt-dlp. If the entry is stale, a background refetch is
  // fired (deduped via _revalidating) so the *next* request gets fresh data.
  // A cache miss still fetches synchronously, same as before.
  const getListWithRevalidate = async (cacheKey, fetchFresh) => {
    const cached = await songCacheGet(cacheKey);
    if (cached) {
      const age = Date.now() - cached.cachedAt;
      if (age > LIST_FRESH_TTL_MS && !_revalidating.has(cacheKey)) {
        _revalidating.add(cacheKey);
        fetchFresh()
          .then((fresh) => songCacheSet(cacheKey, { data: fresh, cachedAt: Date.now() }))
          .catch((err) =>
            console.warn(`[audioService] Background revalidate failed for "${cacheKey}":`, err.message)
          )
          .finally(() => _revalidating.delete(cacheKey));
      }
      return cached.data;
    }

    const fresh = await fetchFresh();
    await songCacheSet(cacheKey, { data: fresh, cachedAt: Date.now() });
    return fresh;
  };

  // Pulls a fresh pool of songs for a language from the YouTube Data API,
  // falling back to yt-dlp search on quota exhaustion or API failure.
  // Shared by the cold-cache path and stale-while-revalidate's background
  // refresh, so both go through identical filtering logic.
  const fetchFreshLanguageSongs = async (cleanLanguage) => {
    const allSongs = [];
    let pageToken;

    try {
      while (allSongs.length < SONGS_TARGET) {
        const params = {
          part: "snippet",
          type: "video",
          videoCategoryId: MUSIC_VIDEO_CATEGORY_ID,
          maxResults: SONGS_PER_PAGE,
          q: `${cleanLanguage} Christian Songs`,
          key: process.env.YOUTUBE_API_KEY,
        };
        if (pageToken) {
          params.pageToken = pageToken;
        }

        const response = await httpClient.get(YOUTUBE_SEARCH_URL, {
          params,
          timeout: 10000,
        });

        const pageSongs = (response.data?.items || [])
          .map((item) => ({ ...mapYouTubeItemToSong(item), isLongMix: false }))
          .filter((song) => Boolean(song.id));

        // Fetch durations and strip YouTube Shorts / status videos (< 62 s)
        // as well as long non-stop mixes (>= 20 min) — those belong only in
        // the "Non-Stop Worship" category, not the general trending list.
        const durationMap = await fetchDurations(
          httpClient,
          pageSongs.map((s) => s.id),
          process.env.YOUTUBE_API_KEY
        );
        const items = pageSongs.filter((song) => {
          const secs = durationMap.get(song.id);
          const durationOk = secs == null || (secs >= MIN_SONG_DURATION_SECONDS && secs < LONG_MIX_THRESHOLD_SECONDS);
          return durationOk && _isChristianContent({ title: song.title, channelTitle: song.channelTitle });
        });

        allSongs.push(...items);

        pageToken = response.data?.nextPageToken;
        if (!pageToken || items.length < SONGS_PER_PAGE) {
          break;
        }
      }
    } catch (error) {
      if (isQuotaExceeded(error)) {
        console.warn(
          `[audioService] YouTube API quota exceeded for "${cleanLanguage}" — falling back to yt-dlp search.`
        );
        const fallback = (await searchWithYtdlp(cleanLanguage)).map((s) => ({ ...s, isLongMix: false }));
        if (fallback.length > 0) {
          return fallback;
        }
        throw new AppError(
          429,
          "YouTube API quota exceeded. Devotional content will be available again tomorrow."
        );
      }

      if (allSongs.length === 0) {
        console.error(
          "[audioService] YouTube API search failed:",
          error.response?.data || { message: error.message }
        );
        // Try yt-dlp as a last resort
        const fallback = (await searchWithYtdlp(cleanLanguage)).map((s) => ({ ...s, isLongMix: false }));
        if (fallback.length > 0) {
          return fallback;
        }
        throw new AppError(
          502,
          "Unable to fetch worship audio right now. Please try again later."
        );
      }

      // Partial results: a later page failed — return what was already fetched
      console.error(
        "[audioService] YouTube API pagination failed partway through:",
        error.response?.data || { message: error.message }
      );
    }

    return allSongs.slice(0, SONGS_TARGET);
  };

  // Same shape as fetchFreshLanguageSongs, but for a Trending category
  // (Hymns Mix / Non-Stop Worship), which uses a fixed search query suffix
  // and a category-specific duration window instead of the general one.
  const fetchFreshCategorySongs = async (categoryKey, cleanLanguage, minDuration, maxDuration, searchQuery) => {
    const allSongs = [];
    let pageToken;

    try {
      while (allSongs.length < SONGS_TARGET) {
        const params = {
          part: "snippet",
          type: "video",
          videoCategoryId: MUSIC_VIDEO_CATEGORY_ID,
          maxResults: SONGS_PER_PAGE,
          q: searchQuery,
          key: process.env.YOUTUBE_API_KEY,
        };
        if (pageToken) {
          params.pageToken = pageToken;
        }

        const response = await httpClient.get(YOUTUBE_SEARCH_URL, {
          params,
          timeout: 10000,
        });

        const pageSongs = (response.data?.items || [])
          .map((item) => ({ ...mapYouTubeItemToSong(item), isLongMix: categoryKey === "longmix" }))
          .filter((song) => Boolean(song.id));

        const durationMap = await fetchDurations(
          httpClient,
          pageSongs.map((s) => s.id),
          process.env.YOUTUBE_API_KEY
        );
        const items = pageSongs.filter((song) => {
          const secs = durationMap.get(song.id);
          const durationOk = secs == null || (secs >= minDuration && secs < maxDuration);
          return durationOk && _isChristianContent({ title: song.title, channelTitle: song.channelTitle });
        });

        allSongs.push(...items);

        pageToken = response.data?.nextPageToken;
        if (!pageToken || items.length < SONGS_PER_PAGE) {
          break;
        }
      }
    } catch (error) {
      if (isQuotaExceeded(error)) {
        console.warn(
          `[audioService] YouTube API quota exceeded for category "${categoryKey}/${cleanLanguage}" — falling back to yt-dlp search.`
        );
        const fallback = (await searchWithYtdlpCategory(searchQuery, minDuration, maxDuration))
          .map((s) => ({ ...s, isLongMix: categoryKey === "longmix" }));
        if (fallback.length > 0) {
          return fallback;
        }
        throw new AppError(
          429,
          "YouTube API quota exceeded. This category will be available again tomorrow."
        );
      }

      if (allSongs.length === 0) {
        console.error(
          "[audioService] YouTube API category search failed:",
          error.response?.data || { message: error.message }
        );
        const fallback = (await searchWithYtdlpCategory(searchQuery, minDuration, maxDuration))
          .map((s) => ({ ...s, isLongMix: categoryKey === "longmix" }));
        if (fallback.length > 0) {
          return fallback;
        }
        throw new AppError(
          502,
          "Unable to fetch this category right now. Please try again later."
        );
      }

      console.error(
        "[audioService] YouTube API category pagination failed partway through:",
        error.response?.data || { message: error.message }
      );
    }

    return allSongs.slice(0, SONGS_TARGET);
  };

  return {
    async getStreamUrl(videoId) {
      if (!videoId || !/^[a-zA-Z0-9_-]{11}$/.test(videoId)) {
        throw new AppError(400, "Invalid video ID");
      }

      // 1. Redis cache — replays are instant, no yt-dlp needed
      const cacheKey = `audio_url:v1:${videoId}`;
      const cached = await songCacheGet(cacheKey);
      if (cached) {
        console.log(`[audioService] cache hit for audio URL ${videoId}`);
        return cached;
      }

      // 2. Dedup — if another request is already running yt-dlp for this videoId, share it
      if (_inflight.has(videoId)) {
        return _inflight.get(videoId);
      }

      const promise = (async () => {
        try {
          const result = await youtubedl(`https://www.youtube.com/watch?v=${videoId}`, {
            getUrl: true,
            noWarnings: true,
            format: "bestaudio[ext=webm]/bestaudio[ext=m4a]/bestaudio/best",
            socketTimeout: 15,
            // "android_vr" client sidesteps YouTube's "Sign in to confirm
            // you're not a bot" block that the default client chain started
            // hitting — the web/android/ios clients all fail or need a PO
            // Token now, android_vr doesn't (see yt-dlp issue #12482).
            extractorArgs: "youtube:player_client=android_vr",
            ...ytdlpProxyOpts(),
          });
          const rawUrl = String(result || "").trim().split("\n")[0];
          if (!rawUrl || !rawUrl.startsWith("http")) {
            throw new AppError(502, "No playable audio format found for this video");
          }
          // Cache so any replay within 3 h is instant
          await songCacheSet(cacheKey, rawUrl, AUDIO_URL_CACHE_TTL);
          return rawUrl;
        } catch (err) {
          if (err instanceof AppError) throw err;
          console.error(`[audioService] yt-dlp getUrl failed for ${videoId}:`, err.message);
          throw new AppError(502, "Unable to retrieve audio URL from YouTube");
        } finally {
          _inflight.delete(videoId);
        }
      })();

      _inflight.set(videoId, promise);
      return promise;
    },

    async streamAudio(videoId, req, res) {
      if (!videoId || !/^[a-zA-Z0-9_-]{11}$/.test(videoId)) {
        throw new AppError(400, "Invalid video ID");
      }

      // --get-url with an audio-only format selector is 3–4× faster than
      // dumpSingleJson (~2-3 s vs 8-10 s), keeping us under ExoPlayer's
      // 8-second read timeout.  The URL is proxied server-side so the same IP
      // that extracted it fetches it — no IP-mismatch 403.
      //
      // Reuses the same cache as getStreamUrl: a full download is now split
      // client-side into several Range-request chunks (see downloadMusic.ts)
      // to stay under Cloudflare's ~100s proxy timeout in production, so this
      // gets called multiple times per song — without this cache each chunk
      // would pay its own ~5s yt-dlp resolution cost.
      const cacheKey = `audio_url:v1:${videoId}`;
      let audioUrl = await songCacheGet(cacheKey);

      if (!audioUrl) {
        try {
          const result = await youtubedl(
            `https://www.youtube.com/watch?v=${videoId}`,
            {
              getUrl: true,
              noWarnings: true,
              format: "bestaudio[ext=webm]/bestaudio[ext=m4a]/bestaudio/best",
              socketTimeout: 15,
              extractorArgs: "youtube:player_client=android_vr",
              ...ytdlpProxyOpts(),
            }
          );
          audioUrl = String(result || "").trim().split("\n")[0];
          if (audioUrl && audioUrl.startsWith("http")) {
            await songCacheSet(cacheKey, audioUrl, AUDIO_URL_CACHE_TTL);
          }
        } catch (err) {
          console.error(`[audioService] yt-dlp getUrl failed for ${videoId}:`, err.message);
          throw new AppError(502, "Unable to retrieve audio stream from YouTube");
        }
      }

      if (!audioUrl || !audioUrl.startsWith("http")) {
        throw new AppError(502, "No playable audio format found for this video");
      }

      // Pass through Range header so ExoPlayer can seek and resume.
      const proxyHeaders = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Referer": "https://www.youtube.com/",
        "Origin": "https://www.youtube.com",
      };
      if (req.headers.range) proxyHeaders["Range"] = req.headers.range;

      res.setHeader("Accept-Ranges", "bytes");

      const protocol = audioUrl.startsWith("https") ? https : http;
      const audioReq = protocol.get(audioUrl, { headers: proxyHeaders }, (audioRes) => {
        // Forward the real Content-Type, Content-Length, Content-Range.
        const ct = audioRes.headers["content-type"];
        res.setHeader("Content-Type", ct || "audio/webm");
        if (audioRes.headers["content-length"]) {
          res.setHeader("Content-Length", audioRes.headers["content-length"]);
        }
        if (audioRes.headers["content-range"]) {
          res.setHeader("Content-Range", audioRes.headers["content-range"]);
        }
        res.status(audioRes.statusCode || 200);
        audioRes.pipe(res);
        audioRes.on("error", (err) => {
          console.error(`[audioService] Proxy stream error for ${videoId}:`, err.message);
          if (!res.headersSent) res.status(502).end();
          else res.destroy();
        });
      });

      audioReq.on("error", (err) => {
        console.error(`[audioService] HTTP request error for ${videoId}:`, err.message);
        if (!res.headersSent) res.status(502).end();
        else res.destroy();
      });

      req.on("close", () => audioReq.destroy());
    },

    async listSongsByLanguage(language) {
      if (!process.env.YOUTUBE_API_KEY) {
        throw new AppError(503, "Audio service is unavailable: YOUTUBE_API_KEY is not configured");
      }

      const cleanLanguage = sanitizeLanguage(language);

      if (!cleanLanguage) {
        throw new AppError(400, "language is required");
      }

      const cacheKey = `songs:v3:${cleanLanguage.toLowerCase()}`;
      const pool = await getListWithRevalidate(cacheKey, () => fetchFreshLanguageSongs(cleanLanguage));
      const results = shuffleSongs(pool).slice(0, SONGS_DISPLAY_COUNT);
      prewarmTopSongs(results, this);
      return results;
    },

    listCategories() {
      return Object.entries(CATEGORIES).map(([key, value]) => ({ key, label: value.label }));
    },

    async listSongsByCategory(language, categoryKey) {
      if (!process.env.YOUTUBE_API_KEY) {
        throw new AppError(503, "Audio service is unavailable: YOUTUBE_API_KEY is not configured");
      }

      const category = CATEGORIES[categoryKey];
      if (!category) {
        throw new AppError(400, `Unknown category: ${categoryKey}`);
      }

      const cleanLanguage = sanitizeLanguage(language);
      if (!cleanLanguage) {
        throw new AppError(400, "language is required");
      }

      const minDuration = category.minDurationSeconds ?? MIN_SONG_DURATION_SECONDS;
      const maxDuration = category.maxDurationSeconds ?? Infinity;
      const searchQuery = `${cleanLanguage} ${category.querySuffix}`;
      const cacheKey = `songs:category:v2:${categoryKey}:${cleanLanguage.toLowerCase()}`;

      const pool = await getListWithRevalidate(cacheKey, () =>
        fetchFreshCategorySongs(categoryKey, cleanLanguage, minDuration, maxDuration, searchQuery)
      );
      const results = shuffleSongs(pool).slice(0, SONGS_DISPLAY_COUNT);
      prewarmTopSongs(results, this);
      return results;
    },

    async searchSongs(query) {
      const cleanQuery = sanitizeLanguage(query);
      if (!cleanQuery) throw new AppError(400, "query is required");
      return searchSongsByQuery(cleanQuery);
    },
  };
};

module.exports = {
  createAudioService,
  audioService: createAudioService(),
  decodeHtmlEntities,
  mapYouTubeItemToSong,
  sanitizeLanguage,
};
