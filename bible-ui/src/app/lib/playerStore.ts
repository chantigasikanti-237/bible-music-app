// Music playback, outside any single screen's lifecycle — same reasoning as
// musicDownloadManager.ts and userProfileStore.ts. Without this, navigating
// away from /songs (to Home, Bible, etc.) used to unmount the <audio>
// element along with the screen and kill playback entirely. Mirrors the
// subscribe/getSnapshot pattern those two already use in this codebase.
import { getSongAudioBlobUrlOffline } from './offlineMusicStore';
import { startSongDownload, getLastLimitMessage, type StartDownloadOutcome } from './musicDownloadManager';
import { router } from '../routes';

export interface Song {
  videoId: string;
  title: string;
  artist: string;
  image: string;
  language: string;
  isLongMix: boolean;
}

export interface PlayerSnapshot {
  song: Song | null;
  isPlaying: boolean;
  loadingId: string | null;
  currentTime: number;
  duration: number;
  expanded: boolean;
  queue: Song[];
  queueIndex: number;
  favorites: Song[];
  addToPlaylistRequest: Song | null;
}

const FAVS_KEY = 'music_favorites_v2';
const LAST_PLAYED_KEY = 'music_last_played_v1';
const BIBLE_MINI_PLAYER_KEY = 'bible_mini_player_enabled';

// Preferences ▸ Language toggle — lets the floating mini player be hidden
// while on the Bible tab specifically. Defaults on (today's behavior).
export const getBibleMiniPlayerEnabled = (): boolean => {
  const raw = localStorage.getItem(BIBLE_MINI_PLAYER_KEY);
  return raw === null ? true : raw === 'true';
};

export const setBibleMiniPlayerEnabled = (enabled: boolean): void => {
  localStorage.setItem(BIBLE_MINI_PLAYER_KEY, enabled ? 'true' : 'false');
};

const getStoredFavs = (): Song[] => {
  try { return JSON.parse(localStorage.getItem(FAVS_KEY) || '[]'); } catch { return []; }
};
const saveStoredFavs = (songs: Song[]) => localStorage.setItem(FAVS_KEY, JSON.stringify(songs));

let state: PlayerSnapshot = {
  song: null,
  isPlaying: false,
  loadingId: null,
  currentTime: 0,
  duration: 0,
  expanded: false,
  queue: [],
  queueIndex: 0,
  favorites: getStoredFavs(),
  addToPlaylistRequest: null,
};

let audio: HTMLAudioElement | null = null;
const listeners = new Set<() => void>();

function setState(patch: Partial<PlayerSnapshot>): void {
  state = { ...state, ...patch };
  for (const listener of listeners) listener();
}

export function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function getSnapshot(): PlayerSnapshot {
  return state;
}

/* ── Favorites ───────────────────────────────────────────── */
export function isFav(videoId: string): boolean {
  return state.favorites.some(f => f.videoId === videoId);
}

export function toggleFav(song: Song): void {
  const next = state.favorites.some(f => f.videoId === song.videoId)
    ? state.favorites.filter(f => f.videoId !== song.videoId)
    : [song, ...state.favorites];
  saveStoredFavs(next);
  setState({ favorites: next });
}

/* ── Core audio ──────────────────────────────────────────── */
async function loadAndPlay(song: Song): Promise<void> {
  // Persist so Home screen can show the last played song
  try { localStorage.setItem(LAST_PLAYED_KEY, JSON.stringify(song)); } catch {}
  setState({ loadingId: song.videoId, currentTime: 0, duration: 0 });
  try {
    const offlineUrl = await getSongAudioBlobUrlOffline(song.videoId);
    // Online path plays through our own /stream proxy, not the raw
    // extracted URL /api/audio/url returns - that URL is IP-locked to
    // whichever server made the yt-dlp extraction request (ours, via a
    // residential proxy), so a client fetching it directly - the phone,
    // on its own IP - always gets rejected. /stream re-fetches and pipes
    // the bytes server-side, keeping the same IP throughout, and needs no
    // separate URL round-trip since it resolves the video ID itself.
    const url = offlineUrl || `/api/audio/stream/${song.videoId}`;
    audio?.pause();
    const el = new Audio(url);
    el.ontimeupdate = () => setState({ currentTime: el.currentTime });
    el.ondurationchange = () => setState({ duration: isFinite(el.duration) ? el.duration : 0 });
    el.onended = () => { setState({ isPlaying: false }); playNext(); };
    el.onerror = () => { setState({ isPlaying: false, loadingId: null }); };
    audio = el;
    await el.play();
    setState({ isPlaying: true });
  } catch (err) {
    console.error('[playerStore] loadAndPlay failed for', song.videoId, err);
    setState({ isPlaying: false });
  } finally {
    setState({ loadingId: null });
  }
}

/* ── Public player actions ───────────────────────────────── */
export function startSong(song: Song, queue: Song[] = []): void {
  // Same song already loaded → just expand / resume
  if (state.song?.videoId === song.videoId) {
    setState({ expanded: true });
    if (audio && !state.isPlaying) {
      audio.play().then(() => setState({ isPlaying: true })).catch(err => {
        console.error('[playerStore] resume play() failed for', song.videoId, err);
      });
    }
    return;
  }
  const q = queue.length > 0 ? queue : [song];
  const idx = q.findIndex(s => s.videoId === song.videoId);
  setState({ song, expanded: true, queue: q, queueIndex: idx >= 0 ? idx : 0 });
  loadAndPlay(song);
}

export function togglePlay(): void {
  if (!audio) return;
  if (state.isPlaying) {
    audio.pause();
    setState({ isPlaying: false });
  } else {
    audio.play().then(() => setState({ isPlaying: true })).catch(err => {
      console.error('[playerStore] togglePlay play() failed', err);
    });
  }
}

export function playNext(): void {
  if (state.queue.length < 2) return;
  const nextIdx = (state.queueIndex + 1) % state.queue.length;
  const song = state.queue[nextIdx];
  setState({ queueIndex: nextIdx, song });
  loadAndPlay(song);
}

export function playPrev(): void {
  if (state.queue.length === 0) return;
  // Within first 3s → go to prev; otherwise restart
  if (audio && audio.currentTime > 3) {
    audio.currentTime = 0;
    return;
  }
  const prevIdx = (state.queueIndex - 1 + state.queue.length) % state.queue.length;
  const song = state.queue[prevIdx];
  setState({ queueIndex: prevIdx, song });
  loadAndPlay(song);
}

export function seekTo(frac: number): void {
  if (!audio || !state.duration) return;
  audio.currentTime = frac * state.duration;
  setState({ currentTime: frac * state.duration });
}

export function stopPlayer(): void {
  audio?.pause();
  audio = null;
  setState({
    song: null, isPlaying: false, currentTime: 0, duration: 0,
    expanded: false, queue: [], queueIndex: 0,
  });
}

export function setExpanded(expanded: boolean): void {
  setState({ expanded });
}

export function toggleExpand(): void {
  setState({ expanded: !state.expanded });
}

/* ── Cross-route "Add to Playlist" ──────────────────────────
 * The full-screen player can be reached from any route, but the picker
 * sheet UI only exists on the Songs screen. Stash the request here; if
 * we're not already there, hop over so Songs.tsx's effect can pick it up
 * and open the sheet. */
export function requestAddToPlaylist(song: Song): void {
  setState({ addToPlaylistRequest: song });
  // router.state is explicitly documented as internal-only in react-router's
  // types (only .navigate() is the supported outside-a-component API) — read
  // the path straight from the browser instead.
  if (window.location.pathname !== '/songs') {
    router.navigate('/songs');
  }
}

export function clearAddToPlaylistRequest(): void {
  setState({ addToPlaylistRequest: null });
}

/* ── Download current song ──────────────────────────────────
 * Was firing a raw browser file download straight from the stream endpoint
 * - bypassed auth, quota, IndexedDB storage, and the chunked-download retry
 * logic, so it never showed up in Assets > Downloads and wasn't resilient
 * to Cloudflare's proxy timeout on a real deploy. Route through the same
 * manager every other download button in the app uses. */
export async function downloadCurrent(): Promise<void> {
  const song = state.song;
  if (!song) return;
  const outcome: StartDownloadOutcome = await startSongDownload(song);
  if (outcome === 'not_authenticated') {
    if (window.confirm('Sign in to download songs for offline listening. Go to the sign-in screen now?')) {
      router.navigate('/login');
    }
  } else if (outcome === 'limit_reached') {
    window.alert(getLastLimitMessage());
  }
}
