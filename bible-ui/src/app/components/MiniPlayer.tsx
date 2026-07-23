import { useRef, useState, useEffect } from 'react';
import { motion, AnimatePresence, useDragControls } from 'motion/react';
import { Play, Pause, SkipForward, SkipBack, X, Heart, ChevronDown, Music, Download, Shuffle, Repeat, ListPlus, ListMusic } from 'lucide-react';

export interface PlayerSong {
  videoId: string;
  title: string;
  artist: string;
  image: string;
}

interface MiniPlayerProps {
  song: PlayerSong;
  isPlaying: boolean;
  isLoading?: boolean;
  currentTime: number;
  duration: number;
  expanded: boolean;
  isFav?: boolean;
  queue?: PlayerSong[];
  queueIndex?: number;
  onToggleExpand: () => void;
  onTogglePlay: () => void;
  onClose: () => void;
  onNext?: () => void;
  onPrev?: () => void;
  onSeek?: (fraction: number) => void;
  onToggleFav?: () => void;
  onDownload?: () => void;
  onAddToPlaylist?: () => void;
}

const fmt = (secs: number) => {
  if (!secs || isNaN(secs) || !isFinite(secs)) return '0:00';
  const m = Math.floor(secs / 60);
  const s = Math.floor(secs % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
};

export function MiniPlayer({
  song, isPlaying, isLoading = false, currentTime, duration,
  expanded, isFav = false, queue = [], queueIndex = 0,
  onToggleExpand, onTogglePlay, onClose,
  onNext, onPrev, onSeek, onToggleFav, onDownload, onAddToPlaylist,
}: MiniPlayerProps) {
  const progress = duration > 0 ? Math.min(1, currentTime / duration) : 0;
  const progressBarRef = useRef<HTMLDivElement>(null);
  const [shuffle, setShuffle] = useState(false);
  const [repeat, setRepeat] = useState(false);
  const [dragging, setDragging] = useState(false);
  const [queueExpanded, setQueueExpanded] = useState(false);
  const queueDragControls = useDragControls();

  // Collapse the queue sheet whenever the full player itself closes, so it
  // doesn't reopen straight into the queue next time.
  useEffect(() => {
    if (!expanded) setQueueExpanded(false);
  }, [expanded]);

  const handleSeek = (e: React.MouseEvent<HTMLDivElement> | React.TouchEvent<HTMLDivElement>) => {
    if (!onSeek || !progressBarRef.current) return;
    const rect = progressBarRef.current.getBoundingClientRect();
    const clientX = 'touches' in e ? e.touches[0].clientX : e.clientX;
    const frac = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
    onSeek(frac);
  };

  return (
    <AnimatePresence mode="wait">
      {expanded ? (
        /* ── FULL SCREEN PLAYER ─────────────────────────────────── */
        <motion.div
          key="full"
          initial={{ y: '100%' }}
          animate={{ y: 0 }}
          exit={{ y: '100%' }}
          transition={{ type: 'spring', damping: 32, stiffness: 300 }}
          className="fixed top-0 bottom-0 left-0 md:left-[72px] xl:left-[220px] right-0 z-[48] flex flex-col select-none overflow-hidden"
          style={{ background: '#060f0a' }}
        >
          {/* Blurred album art background */}
          {song.image && (
            <img
              src={song.image} alt="" aria-hidden
              className="absolute inset-0 w-full h-full object-cover pointer-events-none"
              style={{ filter: 'blur(60px)', transform: 'scale(1.5)', opacity: 0.45 }}
            />
          )}
          {/* Multi-stop gradient overlay */}
          <div className="absolute inset-0 pointer-events-none"
            style={{ background: 'linear-gradient(180deg, rgba(6,15,10,0.55) 0%, rgba(6,15,10,0.5) 30%, rgba(6,15,10,0.75) 65%, rgba(6,15,10,0.97) 100%)' }} />

          {/* Content */}
          <div className="relative z-10 flex flex-col h-full">

            {/* Drag handle */}
            <div className="flex justify-center pt-3 pb-1 flex-shrink-0">
              <div className="w-10 h-1 rounded-full bg-white/25" />
            </div>

            {/* Top bar */}
            <div className="flex items-center justify-between px-5 pt-2 pb-2 flex-shrink-0">
              <motion.button whileTap={{ scale: 0.88 }} onClick={onToggleExpand}
                className="w-10 h-10 rounded-full bg-white/10 flex items-center justify-center">
                <ChevronDown size={20} className="text-white" />
              </motion.button>

              <div className="text-center">
                <p className="text-white/40 text-[10px] font-bold tracking-[0.25em] uppercase">Now Playing</p>
              </div>

              <motion.button whileTap={{ scale: 0.88 }} onClick={onClose}
                className="w-10 h-10 rounded-full bg-white/10 flex items-center justify-center">
                <X size={16} className="text-white" />
              </motion.button>
            </div>

            {/* ── Artwork ── */}
            <div className="flex items-center justify-center px-8 py-2 flex-shrink-0">
              <motion.div
                animate={{ scale: isPlaying ? 1 : 0.88 }}
                transition={{ type: 'spring', stiffness: 140, damping: 20 }}
                className="w-full rounded-[24px] overflow-hidden bg-white/5"
                style={{
                  maxWidth: 280,
                  aspectRatio: '1',
                  boxShadow: '0 32px 80px rgba(0,0,0,0.8), 0 8px 32px rgba(0,0,0,0.5)',
                }}
              >
                {song.image
                  ? <img src={song.image} alt={song.title} className="w-full h-full object-cover" />
                  : <div className="w-full h-full flex items-center justify-center"><Music size={64} className="text-white/20" /></div>
                }
              </motion.div>
            </div>

            {/* ── Song info + actions ── */}
            <div className="px-6 pt-4 pb-3 flex items-center gap-4 flex-shrink-0">
              <div className="flex-1 min-w-0">
                <h2 className="text-white text-[18px] font-bold leading-tight truncate">{song.title}</h2>
                <p className="text-white/50 text-[13px] mt-1 truncate">{song.artist}</p>
              </div>

              {/* Fav */}
              <motion.button whileTap={{ scale: 0.82 }} onClick={onToggleFav}
                className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0">
                <motion.div
                  animate={{ scale: isFav ? [1, 1.3, 1] : 1 }}
                  transition={{ duration: 0.3 }}
                >
                  <Heart size={22} className={isFav ? 'text-rose-400 fill-rose-400' : 'text-white/40'} />
                </motion.div>
              </motion.button>

              {/* Add to playlist */}
              {onAddToPlaylist && (
                <motion.button whileTap={{ scale: 0.82 }} onClick={onAddToPlaylist}
                  className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0" title="Add to playlist">
                  <ListPlus size={22} className="text-white/40" />
                </motion.button>
              )}

              {/* Download — only visible when favorited */}
              <AnimatePresence>
                {isFav && (
                  <motion.button
                    initial={{ opacity: 0, scale: 0.5, width: 0 }}
                    animate={{ opacity: 1, scale: 1, width: 40 }}
                    exit={{ opacity: 0, scale: 0.5, width: 0 }}
                    transition={{ type: 'spring', stiffness: 300, damping: 24 }}
                    whileTap={{ scale: 0.82 }}
                    onClick={onDownload}
                    className="h-10 rounded-full flex items-center justify-center flex-shrink-0 overflow-hidden"
                  >
                    <Download size={20} className="text-[#6EE7B7]" />
                  </motion.button>
                )}
              </AnimatePresence>
            </div>

            {/* ── Progress bar ── */}
            <div className="px-6 pb-3 flex-shrink-0">
              <div
                ref={progressBarRef}
                onClick={handleSeek}
                onTouchMove={handleSeek}
                onMouseDown={() => setDragging(true)}
                onMouseUp={() => setDragging(false)}
                className="relative py-3 cursor-pointer group"
              >
                <div className="relative h-[4px] bg-white/15 rounded-full">
                  <motion.div
                    className="h-full bg-white rounded-full"
                    style={{ width: `${progress * 100}%` }}
                  />
                  {/* Scrubber dot */}
                  <motion.div
                    className="absolute top-1/2 -translate-y-1/2 rounded-full bg-white"
                    animate={{ width: dragging ? 18 : 14, height: dragging ? 18 : 14 }}
                    transition={{ duration: 0.15 }}
                    style={{
                      left: `calc(${progress * 100}% - 7px)`,
                      boxShadow: '0 2px 10px rgba(0,0,0,0.6)',
                    }}
                  />
                </div>
              </div>
              <div className="flex justify-between -mt-1">
                <span className="text-white/35 text-[11px] font-medium tabular-nums">{fmt(currentTime)}</span>
                <span className="text-white/35 text-[11px] font-medium tabular-nums">{fmt(duration)}</span>
              </div>
            </div>

            {/* ── Playback controls ── */}
            <div className="px-6 pb-4 flex-shrink-0">
              {/* Shuffle + Prev + Play + Next + Repeat */}
              <div className="flex items-center justify-between">

                {/* Shuffle */}
                <motion.button whileTap={{ scale: 0.85 }} onClick={() => setShuffle(s => !s)}
                  className="w-11 h-11 flex items-center justify-center rounded-full">
                  <Shuffle size={18} className={shuffle ? 'text-[#6EE7B7]' : 'text-white/35'} />
                </motion.button>

                {/* Prev */}
                <motion.button
                  whileTap={{ scale: 0.88 }} onClick={onPrev} disabled={!onPrev}
                  className="w-14 h-14 rounded-full bg-white/10 flex items-center justify-center disabled:opacity-20"
                >
                  <SkipBack size={22} className="text-white" fill="white" />
                </motion.button>

                {/* Play / Pause */}
                <motion.button
                  whileTap={{ scale: 0.92 }} onClick={onTogglePlay}
                  className="w-[70px] h-[70px] rounded-full bg-white flex items-center justify-center flex-shrink-0"
                  style={{ boxShadow: '0 8px 30px rgba(0,0,0,0.55), 0 2px 8px rgba(0,0,0,0.3)' }}
                >
                  {isLoading
                    ? <div className="w-6 h-6 border-[2.5px] border-[#163A2D] border-t-transparent rounded-full animate-spin" />
                    : isPlaying
                      ? <Pause size={28} className="text-[#0a1f14]" fill="#0a1f14" />
                      : <Play size={28} className="text-[#0a1f14] ml-1" fill="#0a1f14" />
                  }
                </motion.button>

                {/* Next */}
                <motion.button
                  whileTap={{ scale: 0.88 }} onClick={onNext} disabled={!onNext}
                  className="w-14 h-14 rounded-full bg-white/10 flex items-center justify-center disabled:opacity-20"
                >
                  <SkipForward size={22} className="text-white" fill="white" />
                </motion.button>

                {/* Repeat */}
                <motion.button whileTap={{ scale: 0.85 }} onClick={() => setRepeat(r => !r)}
                  className="w-11 h-11 flex items-center justify-center rounded-full">
                  <Repeat size={18} className={repeat ? 'text-[#6EE7B7]' : 'text-white/35'} />
                </motion.button>
              </div>
            </div>

            {/* ── Queue pull-up handle (Spotify-style) ── */}
            {queue.length > 1 && (
              <motion.div
                drag="y"
                dragConstraints={{ top: 0, bottom: 0 }}
                dragElastic={0.5}
                onDragEnd={(_, info) => {
                  if (info.offset.y < -30 || info.velocity.y < -400) setQueueExpanded(true);
                }}
                onClick={() => setQueueExpanded(true)}
                className="flex-shrink-0 flex flex-col items-center gap-1.5 pb-5 pt-1 cursor-pointer select-none touch-none"
              >
                <div className="w-8 h-1 rounded-full bg-white/20" />
                <div className="flex items-center gap-1.5 text-white/40">
                  <ListMusic size={14} />
                  <span className="text-[10px] font-bold tracking-[0.18em] uppercase">Queue</span>
                </div>
              </motion.div>
            )}

          </div>

          {/* ── Full-screen Queue sheet: pulled up over the Now Playing view ── */}
          <AnimatePresence>
            {queueExpanded && (
              <motion.div
                key="queue-sheet"
                initial={{ y: '100%' }}
                animate={{ y: 0 }}
                exit={{ y: '100%' }}
                transition={{ type: 'spring', damping: 32, stiffness: 300 }}
                drag="y"
                dragListener={false}
                dragControls={queueDragControls}
                dragConstraints={{ top: 0, bottom: 0 }}
                dragElastic={{ top: 0, bottom: 0.5 }}
                onDragEnd={(_, info) => {
                  if (info.offset.y > 60 || info.velocity.y > 400) setQueueExpanded(false);
                }}
                className="absolute inset-0 z-20 flex flex-col"
                style={{ background: '#0a0a0a' }}
              >
                {/* Only this grip handle starts the drag — the header buttons
                    and queue list below stay normally interactive/scrollable. */}
                <div
                  onPointerDown={e => queueDragControls.start(e)}
                  className="flex justify-center pt-3 pb-1 flex-shrink-0 cursor-grab active:cursor-grabbing touch-none"
                >
                  <div className="w-10 h-1 rounded-full bg-white/25" />
                </div>

                <div className="flex items-center justify-between px-5 pt-2 pb-4 flex-shrink-0">
                  <motion.button whileTap={{ scale: 0.88 }} onClick={() => setQueueExpanded(false)}
                    className="w-10 h-10 rounded-full bg-white/10 flex items-center justify-center">
                    <ChevronDown size={20} className="text-white" />
                  </motion.button>
                  <p className="text-white text-[15px] font-bold">Queue</p>
                  <div className="w-10 h-10" />
                </div>

                <div className="flex-1 overflow-y-auto min-h-0 px-5 pb-6">
                  {/* Now Playing */}
                  <p className="text-white/40 text-[11px] font-bold tracking-[0.14em] uppercase mb-2 px-1">Now Playing</p>
                  <div className="flex items-center gap-3 p-2.5 rounded-[12px] bg-white/5 mb-6">
                    <div className="w-11 h-11 rounded-lg overflow-hidden bg-white/10 flex-shrink-0">
                      {song.image
                        ? <img src={song.image} alt={song.title} className="w-full h-full object-cover" />
                        : <div className="w-full h-full flex items-center justify-center"><Music size={16} className="text-white/20" /></div>
                      }
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-[#6EE7B7] text-[13px] font-semibold truncate leading-tight">{song.title}</p>
                      <p className="text-white/40 text-[11px] truncate mt-0.5">{song.artist}</p>
                    </div>
                    {isPlaying && (
                      <div className="flex items-end gap-[2px] h-3.5 flex-shrink-0">
                        {[0.5, 1, 0.7, 0.9].map((h, k) => (
                          <motion.div key={k} className="w-[2px] rounded-full bg-[#6EE7B7]"
                            animate={{ height: [`${h * 14}px`, '3px', `${h * 14}px`] }}
                            transition={{ duration: 0.6 + k * 0.1, repeat: Infinity, ease: 'easeInOut', delay: k * 0.12 }} />
                        ))}
                      </div>
                    )}
                  </div>

                  {/* Next Up */}
                  {queue.slice(queueIndex + 1).length > 0 && (
                    <>
                      <p className="text-white/40 text-[11px] font-bold tracking-[0.14em] uppercase mb-2 px-1">Next Up</p>
                      <div className="space-y-0.5">
                        {queue.slice(queueIndex + 1).map((item, i) => (
                          <div
                            key={item.videoId + i}
                            className="flex items-center gap-3 p-2.5 rounded-[12px] hover:bg-white/5 transition-colors"
                          >
                            <div className="w-11 h-11 rounded-lg overflow-hidden bg-white/10 flex-shrink-0">
                              {item.image
                                ? <img src={item.image} alt={item.title} className="w-full h-full object-cover" />
                                : <div className="w-full h-full flex items-center justify-center"><Music size={16} className="text-white/20" /></div>
                              }
                            </div>
                            <div className="flex-1 min-w-0">
                              <p className="text-white text-[13px] font-semibold truncate leading-tight">{item.title}</p>
                              <p className="text-white/40 text-[11px] truncate mt-0.5">{item.artist}</p>
                            </div>
                          </div>
                        ))}
                      </div>
                    </>
                  )}
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>

      ) : (
        /* ── MINI BAR ──────────────────────────────────────────── */
        <motion.div
          key="mini"
          initial={{ y: 80, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          exit={{ y: 80, opacity: 0 }}
          transition={{ type: 'spring', damping: 28, stiffness: 300 }}
          className="fixed bottom-[100px] md:bottom-4 left-3 md:left-[76px] xl:left-[224px] right-3 z-40"
        >
          {/* Thin progress line */}
          <div className="h-[2px] rounded-full bg-white/15 mb-1 mx-1 overflow-hidden">
            <div className="h-full bg-white/70 rounded-full" style={{ width: `${progress * 100}%` }} />
          </div>

          <div
            onClick={onToggleExpand}
            className="flex items-center gap-3 px-3 py-2.5 rounded-[20px] cursor-pointer shadow-2xl shadow-black/30"
            style={{ background: 'linear-gradient(135deg, #1a4d2e 0%, #163A2D 100%)' }}
          >
            <div className="w-11 h-11 rounded-xl overflow-hidden bg-white/10 flex-shrink-0">
              {song.image
                ? <img src={song.image} alt={song.title} className="w-full h-full object-cover" />
                : <div className="w-full h-full flex items-center justify-center"><Music size={18} className="text-white/50" /></div>
              }
            </div>

            <div className="flex-1 min-w-0">
              <p className="text-white text-[13px] font-semibold truncate leading-tight">{song.title}</p>
              <p className="text-white/55 text-[11px] truncate mt-0.5">{song.artist}</p>
            </div>

            <div className="flex items-center gap-1.5 flex-shrink-0" onClick={e => e.stopPropagation()}>
              <motion.button whileTap={{ scale: 0.88 }} onClick={onTogglePlay}
                className="w-9 h-9 rounded-full bg-white/20 flex items-center justify-center">
                {isLoading
                  ? <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                  : isPlaying
                    ? <Pause size={16} className="text-white" fill="white" />
                    : <Play size={16} className="text-white ml-0.5" fill="white" />
                }
              </motion.button>
              <motion.button whileTap={{ scale: 0.88 }} onClick={onClose}
                className="w-9 h-9 rounded-full bg-white/20 flex items-center justify-center">
                <X size={15} className="text-white" />
              </motion.button>
            </div>
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
