import { useSyncExternalStore } from 'react';
import { useLocation } from 'react-router';
import { AnimatePresence } from 'motion/react';
import { MiniPlayer, type PlayerSong } from './MiniPlayer';
import {
  subscribe, getSnapshot, togglePlay, playNext, playPrev, seekTo, stopPlayer,
  toggleExpand, isFav, toggleFav, requestAddToPlaylist, downloadCurrent,
  getBibleMiniPlayerEnabled,
  type Song,
} from '../lib/playerStore';

const toPlayerSong = (s: Song): PlayerSong => ({
  videoId: s.videoId, title: s.title, artist: s.artist, image: s.image,
});

// Mounted once in Root.tsx so the player (and the song itself) survives
// navigation instead of unmounting with the Songs screen.
export function GlobalPlayer() {
  const location = useLocation();
  const snap = useSyncExternalStore(subscribe, getSnapshot);

  if (!snap.song) return null;

  // Home has its own live "Last Played / Now Playing" card that already
  // does this job — a second floating bar on top of it would just be a
  // duplicate. The full-screen player can still open from Home though.
  if (!snap.expanded && location.pathname === '/') return null;

  // Preferences ▸ Language ▸ "Mini Player for Bible" — lets it be hidden
  // while reading, without affecting any other tab. Full-screen still opens.
  if (!snap.expanded && location.pathname.startsWith('/bible') && !getBibleMiniPlayerEnabled()) return null;

  return (
    <AnimatePresence>
      <MiniPlayer
        song={toPlayerSong(snap.song)}
        isPlaying={snap.isPlaying}
        isLoading={snap.loadingId === snap.song.videoId}
        currentTime={snap.currentTime}
        duration={snap.duration}
        expanded={snap.expanded}
        isFav={isFav(snap.song.videoId)}
        queue={snap.queue.map(toPlayerSong)}
        queueIndex={snap.queueIndex}
        onToggleExpand={toggleExpand}
        onTogglePlay={togglePlay}
        onClose={stopPlayer}
        onNext={snap.queue.length > 1 ? playNext : undefined}
        onPrev={snap.queue.length > 1 ? playPrev : undefined}
        onSeek={seekTo}
        onToggleFav={() => snap.song && toggleFav(snap.song)}
        onAddToPlaylist={() => snap.song && requestAddToPlaylist(snap.song)}
        onDownload={downloadCurrent}
      />
    </AnimatePresence>
  );
}
