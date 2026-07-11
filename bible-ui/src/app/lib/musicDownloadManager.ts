// Tracks per-song download state outside any component's lifecycle — same
// reasoning as downloadManager.ts for the Bible downloader: navigating away
// (e.g. to Home while a song downloads) must not stop it, and any card
// showing that song anywhere should reflect the same live state.
//
// Also runs a small queue: only MAX_CONCURRENT_DOWNLOADS run at once. Queuing
// 20 songs used to fire all 20 downloadSingleSong() calls simultaneously,
// competing for the same bandwidth and backend capacity — now the rest wait
// their turn and start as slots free up, Netflix-style.
//
// Downloads require login and count against an account-wide quota (200
// regular songs, 100 Non-Stop Worship mixes — enforced server-side in
// musicDownloadService.js, not just tracked locally) so switching devices
// can't be used to get extra downloads. The actual audio file still only
// ever lives in this device's IndexedDB — there's no server-side blob
// storage (see DEPLOYMENT.md's free-tier constraints) — only the *count*
// is shared across devices via the account.
import { downloadSingleSong, DownloadSong, SongDownloadProgress } from './downloadMusic';
import { getToken, apiFetch } from './api';

export type SongDownloadStatus = 'idle' | 'queued' | 'downloading';
export type StartDownloadOutcome = 'started' | 'queued' | 'limit_reached' | 'not_authenticated';

export interface SongDownloadState {
  status: SongDownloadStatus;
  progress: SongDownloadProgress;
}

const IDLE_STATE: SongDownloadState = {
  status: 'idle',
  progress: { loaded: 0, total: 0 },
};

const MAX_CONCURRENT_DOWNLOADS = 3;

const stateByVideoId = new Map<string, SongDownloadState>();
// Song metadata for anything currently downloading/queued, so the Assets ▸
// Downloads screen can show a card for it (title/artist/image) before it's
// actually saved to IndexedDB — otherwise an in-progress download is
// invisible there until it finishes.
const songByVideoId = new Map<string, DownloadSong>();
const cancelFlags = new Map<string, boolean>();
const listeners = new Set<() => void>();

// FIFO of songs waiting for a free download slot.
const pendingQueue: DownloadSong[] = [];
let activeCount = 0;

// Set right before returning 'limit_reached', so the UI can show the exact
// server message (which names the actual limit) instead of a generic one.
let lastLimitMessage = 'Download limit reached.';

// getActiveDownloads() is read via useSyncExternalStore, which requires a
// stable reference when nothing changed — rebuilding the array on every call
// would look "changed" every render and defeat that. Cache it, and only
// rebuild when notify() actually fires.
let activeDownloadsSnapshot: Array<{ song: DownloadSong; state: SongDownloadState }> = [];
let activeDownloadsDirty = true;

function notify(): void {
  activeDownloadsDirty = true;
  for (const listener of listeners) listener();
}

export function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function getSnapshot(videoId: string): SongDownloadState {
  return stateByVideoId.get(videoId) ?? IDLE_STATE;
}

export function getActiveDownloads(): Array<{ song: DownloadSong; state: SongDownloadState }> {
  if (activeDownloadsDirty) {
    const result: Array<{ song: DownloadSong; state: SongDownloadState }> = [];
    for (const [videoId, state] of stateByVideoId) {
      const song = songByVideoId.get(videoId);
      if (song) result.push({ song, state });
    }
    activeDownloadsSnapshot = result;
    activeDownloadsDirty = false;
  }
  return activeDownloadsSnapshot;
}

export function isDownloading(videoId: string): boolean {
  const status = stateByVideoId.get(videoId)?.status;
  return status === 'downloading' || status === 'queued';
}

export function getLastLimitMessage(): string {
  return lastLimitMessage;
}

function releaseQuota(videoId: string): void {
  // Best-effort — if this fails, the record just lingers server-side and
  // corrects itself next time counts are checked against actual downloads.
  apiFetch(`/api/v1/users/me/music-downloads/${videoId}`, { method: 'DELETE' }).catch(() => {});
}

function startNextInQueue(): void {
  if (activeCount >= MAX_CONCURRENT_DOWNLOADS) return;
  const next = pendingQueue.shift();
  if (!next) return;
  runDownload(next);
}

function runDownload(song: DownloadSong): void {
  activeCount++;
  cancelFlags.set(song.videoId, false);
  songByVideoId.set(song.videoId, song);
  stateByVideoId.set(song.videoId, { status: 'downloading', progress: { loaded: 0, total: 0 } });
  notify();

  downloadSingleSong(
    song,
    (progress) => {
      stateByVideoId.set(song.videoId, { status: 'downloading', progress });
      notify();
    },
    () => cancelFlags.get(song.videoId) === true,
  )
    .then((success) => {
      if (!success) releaseQuota(song.videoId); // failed/cancelled — free the reserved slot
    })
    .finally(() => {
      stateByVideoId.delete(song.videoId);
      songByVideoId.delete(song.videoId);
      cancelFlags.delete(song.videoId);
      activeCount--;
      notify();
      startNextInQueue();
    });
}

export async function startSongDownload(song: DownloadSong): Promise<StartDownloadOutcome> {
  if (isDownloading(song.videoId)) return 'queued'; // already running or queued — never double-start
  if (!getToken()) return 'not_authenticated';

  // Reserves this download against the account's quota server-side before
  // any bytes move — the 200/100 cap is enforced there, not just locally.
  try {
    await apiFetch('/api/v1/users/me/music-downloads', {
      method: 'POST',
      body: JSON.stringify({
        videoId: song.videoId,
        title: song.title,
        artist: song.artist,
        image: song.image,
        language: song.language,
        isLongMix: song.isLongMix,
      }),
    });
  } catch (err) {
    lastLimitMessage = err instanceof Error ? err.message : 'Download limit reached.';
    return 'limit_reached';
  }

  if (activeCount < MAX_CONCURRENT_DOWNLOADS) {
    runDownload(song);
    return 'started';
  }

  pendingQueue.push(song);
  songByVideoId.set(song.videoId, song);
  stateByVideoId.set(song.videoId, { status: 'queued', progress: { loaded: 0, total: 0 } });
  notify();
  return 'queued';
}

export function cancelSongDownload(videoId: string): void {
  const status = stateByVideoId.get(videoId)?.status;
  if (status === 'queued') {
    // Hasn't started yet — just drop it from the queue, nothing to abort.
    const idx = pendingQueue.findIndex(s => s.videoId === videoId);
    if (idx !== -1) pendingQueue.splice(idx, 1);
    stateByVideoId.delete(videoId);
    songByVideoId.delete(videoId);
    releaseQuota(videoId);
    notify();
    return;
  }
  cancelFlags.set(videoId, true);
}
