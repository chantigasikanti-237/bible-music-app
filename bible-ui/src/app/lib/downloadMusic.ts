import { saveSongAudioOffline } from './offlineMusicStore';

export interface DownloadSong {
  videoId: string;
  title: string;
  artist: string;
  image: string;
  language: string;
  isLongMix: boolean;
}

export interface SongDownloadProgress {
  loaded: number;
  total: number; // 0 when the server didn't send a Content-Length
}

// YouTube's CDN throttles audio delivery to as little as ~30 KB/s for
// server-resolved (non-browser) sessions — verified directly against the
// CDN, independent of our proxy. A whole song in one request can take
// several minutes, which is fine locally but would get cut off by
// Cloudflare's ~100s proxy timeout once this is deployed there. So the
// download is split into Range-request chunks small enough that even at
// this worst-case throttle, no single request runs anywhere near that
// limit (600 KB / 8 KB/s ≈ 75s — well under 100s with margin to spare).
const CHUNK_SIZE_BYTES = 600 * 1024;

// A Range request to the CDN can drop mid-transfer (ECONNRESET) — observed
// directly while testing this. Retrying just that one chunk is much cheaper
// than failing the whole multi-minute download over a transient blip.
const MAX_CHUNK_ATTEMPTS = 3;
const RETRY_BACKOFF_MS = 1000;

// Downloads a single song with real byte-level progress (via a stream
// reader) and supports mid-stream cancellation — used for the per-song
// download button on each Asset card (Netflix-style: download individual
// items where you browse them, not a separate bulk-download page).
export async function downloadSingleSong(
  song: DownloadSong,
  onProgress: (progress: SongDownloadProgress) => void,
  isCancelled: () => boolean,
): Promise<boolean> {
  try {
    // Fetch through our own backend's stream proxy, not the resolved YouTube
    // CDN URL — that CDN doesn't send CORS headers, so fetch()/blob() (needed
    // to actually store the bytes) would be blocked. Playback elsewhere uses
    // <audio src> instead, which isn't CORS-gated, so it can use the raw CDN
    // URL fine — only downloading needs the proxy.
    const chunks: BlobPart[] = [];
    let start = 0;
    let total = 0;
    let loaded = 0;
    let contentType = 'audio/mpeg';

    while (true) {
      if (isCancelled()) return false;

      const end = start + CHUNK_SIZE_BYTES - 1;
      let rangeHonored = false;
      let chunkBytes = 0;
      let chunkSucceeded = false;

      for (let attempt = 0; attempt < MAX_CHUNK_ATTEMPTS && !chunkSucceeded; attempt++) {
        if (attempt > 0) {
          await new Promise(r => setTimeout(r, RETRY_BACKOFF_MS * attempt));
        }
        if (isCancelled()) return false;

        // Bytes for this attempt stay local until the whole chunk reads
        // cleanly — a failed/reset attempt discards its partial bytes
        // instead of committing them, so a retry can't duplicate data.
        const localChunks: BlobPart[] = [];
        let localBytes = 0;

        try {
          const res = await fetch(`/api/audio/stream/${song.videoId}`, {
            headers: { Range: `bytes=${start}-${end}` },
          });
          if (!res.ok || !res.body) continue;

          // 206 = the server actually honored our Range request, so more
          // chunks remain to fetch. A 200 means it ignored Range and sent
          // the whole file in this one response — treat that as complete.
          rangeHonored = res.status === 206;
          contentType = res.headers.get('content-type') || contentType;
          const contentRange = res.headers.get('content-range'); // "bytes 0-614399/5915177"
          if (contentRange) {
            const match = contentRange.match(/\/(\d+)$/);
            if (match) total = Number(match[1]);
          }

          const reader = res.body.getReader();
          while (true) {
            if (isCancelled()) {
              await reader.cancel();
              return false;
            }
            const { done, value } = await reader.read();
            if (done) break;
            if (value) {
              localChunks.push(value);
              localBytes += value.byteLength;
            }
          }

          chunks.push(...localChunks);
          chunkBytes = localBytes;
          loaded += localBytes;
          onProgress({ loaded, total: total || loaded });
          chunkSucceeded = true;
        } catch {
          // Network error mid-chunk (e.g. ECONNRESET) — loop retries with backoff.
        }
      }

      if (!chunkSucceeded) return false;
      if (!rangeHonored || chunkBytes === 0) break;
      start += chunkBytes;
      if (total > 0 && start >= total) break;
    }

    const blob = new Blob(chunks, { type: contentType });
    await saveSongAudioOffline({
      videoId: song.videoId,
      title: song.title,
      artist: song.artist,
      image: song.image,
      language: song.language,
      isLongMix: song.isLongMix,
      blob,
      mimeType: blob.type,
    });
    return true;
  } catch {
    return false;
  }
}
