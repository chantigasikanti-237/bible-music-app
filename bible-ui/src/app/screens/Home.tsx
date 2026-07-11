import { useState, useEffect, useMemo, useRef } from 'react';
import { useNavigate } from 'react-router';
import { BookOpen, Headphones, Bookmark, Clock, Flame, BookMarked, Play, ChevronRight, Star, Search, X, Music2 } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { getBibleVersionId, getToken, apiFetch } from '../lib/api';
import { BIBLE_VERSIONS } from './BibleLibrary';
import { parseReference } from '../lib/bibleReference';
import { listDownloadedSongs } from '../lib/offlineMusicStore';

/* ── Constants ─────────────────────────────────────────────────── */

const LAST_PLAYED_KEY = 'music_last_played_v1';
const RECENT_CHAPTERS_KEY = 'recent_chapters_v1';
const MUSIC_FAVS_KEY = 'music_favorites_v2';
const STREAK = 7; // milestone: 7, 30, 100 days trigger confetti
const GLOBAL_SEARCH_DEBOUNCE_MS = 350;
const MAX_RESULTS_PER_GROUP = 4;

const QUOTES = [
  { text: 'I can do all things through Christ who strengthens me.', author: 'Philippians 4:13' },
  { text: 'The Lord is my shepherd; I shall not want.', author: 'Psalm 23:1' },
  { text: 'Be strong and courageous. Do not be afraid.', author: 'Joshua 1:9' },
  { text: 'For I know the plans I have for you, declares the Lord.', author: 'Jeremiah 29:11' },
  { text: 'Trust in the Lord with all your heart and lean not on your own understanding.', author: 'Proverbs 3:5' },
  { text: 'The joy of the Lord is your strength.', author: 'Nehemiah 8:10' },
];

/* ── Time-based config ────────────────────────────────────────── */

const getTimeConfig = () => {
  const h = new Date().getHours();
  if (h >= 5 && h < 12) return {
    greeting: 'Good morning',
    subtitle: 'A peaceful start to your day in the Word.',
    gradient: 'linear-gradient(160deg, #fef9ee 0%, #fde68a 40%, #a7f3d0 100%)',
    accentColor: '#163A2D',
    isDark: false,
  };
  if (h >= 12 && h < 18) return {
    greeting: 'Good afternoon',
    subtitle: 'A perfect moment to rest in Scripture.',
    gradient: 'linear-gradient(160deg, #ecfdf5 0%, #6ee7b7 45%, #059669 100%)',
    accentColor: '#163A2D',
    isDark: false,
  };
  if (h >= 18 && h < 22) return {
    greeting: 'Good evening',
    subtitle: 'Wind down with God\'s Word tonight.',
    gradient: 'linear-gradient(160deg, #163A2D 0%, #0a1f14 55%, #1b4332 100%)',
    accentColor: '#6EE7B7',
    isDark: true,
  };
  return {
    greeting: 'Good night',
    subtitle: 'Let the Word guide your rest.',
    gradient: 'linear-gradient(160deg, #0a1f14 0%, #030d08 60%, #051a10 100%)',
    accentColor: '#6EE7B7',
    isDark: true,
  };
};

/* ── Sub-components ───────────────────────────────────────────── */

const Confetti = ({ onDone }: { onDone: () => void }) => {
  const COLORS = ['#FFD700', '#FF6B6B', '#4ECDC4', '#95D5B2', '#A78BFA', '#F9A8D4'];
  const particles = useMemo(() =>
    Array.from({ length: 48 }, (_, i) => ({
      id: i,
      x: Math.random() * 100,
      color: COLORS[i % COLORS.length],
      delay: Math.random() * 0.9,
      dur: 1.6 + Math.random() * 1.2,
      size: 6 + Math.random() * 8,
      shape: i % 3 === 0 ? '50%' : i % 3 === 1 ? '2px' : '0',
    })), []);

  useEffect(() => {
    const t = setTimeout(onDone, 4000);
    return () => clearTimeout(t);
  }, [onDone]);

  return (
    <div className="fixed inset-0 pointer-events-none z-[300] overflow-hidden">
      {particles.map(p => (
        <motion.div
          key={p.id}
          initial={{ x: `${p.x}vw`, y: -30, opacity: 1, rotate: 0 }}
          animate={{ y: '115vh', opacity: [1, 1, 0.4, 0], rotate: 720 }}
          transition={{ duration: p.dur, delay: p.delay, ease: 'easeIn' }}
          style={{
            position: 'absolute',
            width: p.size, height: p.size,
            background: p.color,
            borderRadius: p.shape,
          }}
        />
      ))}
    </div>
  );
};

const ProgressRing = ({
  percent, color, trackColor = 'rgba(255,255,255,0.12)',
  size = 56, strokeWidth = 5, children,
}: {
  percent: number; color: string; trackColor?: string;
  size?: number; strokeWidth?: number; children?: React.ReactNode;
}) => {
  const r = (size - strokeWidth) / 2;
  const circ = 2 * Math.PI * r;
  return (
    <div className="relative flex-shrink-0" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="absolute inset-0">
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={trackColor} strokeWidth={strokeWidth} />
        <motion.circle
          cx={size / 2} cy={size / 2} r={r}
          fill="none" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round"
          initial={{ strokeDashoffset: circ }}
          animate={{ strokeDashoffset: circ * (1 - percent) }}
          transition={{ duration: 1.4, ease: 'easeOut', delay: 0.4 }}
          style={{ strokeDasharray: circ, transformOrigin: '50% 50%', transform: 'rotate(-90deg)' }}
        />
      </svg>
      <div className="absolute inset-0 flex items-center justify-center">{children}</div>
    </div>
  );
};

const SoundwaveMini = ({ playing }: { playing: boolean }) => {
  const heights = [0.4, 0.9, 0.55, 1.0, 0.6, 0.8, 0.35];
  return (
    <div className="flex items-end gap-[2px] h-5">
      {heights.map((h, i) => (
        <motion.div
          key={i}
          className="w-[2.5px] rounded-full bg-white flex-shrink-0"
          animate={playing
            ? { height: [`${h * 20}px`, `${h * 0.25 * 20}px`, `${h * 20}px`] }
            : { height: `${h * 0.35 * 20}px` }
          }
          transition={playing
            ? { duration: 0.55 + i * 0.08, repeat: Infinity, ease: 'easeInOut', delay: i * 0.06 }
            : { duration: 0.3 }
          }
        />
      ))}
    </div>
  );
};

/* ── Main component ───────────────────────────────────────────── */

interface RecentChapter { book: string; chapter: number; label: string; }
interface SearchBook { id: string; title: string; titleRomanized?: string; englishTitle?: string; canon: string; }

// Global search result shapes — one per source the search box covers.
interface HymnResult { songId: string; title: string; languageCode: string; titleRomanized?: string; }
interface MusicSong { videoId: string; title: string; artist: string; image: string; language: string; isLongMix: boolean; }
interface HymnFavorite { _id: string; songId: string; title: string; languageCode: string; }
interface VerseBookmark {
  _id: string; bookId: string; bookName: string; chapterNumber: number; verseNumber: number;
  versionId: number; text: string; note: string | null;
}

export function Home() {
  const navigate = useNavigate();
  const [quoteIdx, setQuoteIdx] = useState(0);
  const [songPlaying, setSongPlaying] = useState(false);
  const [recentChapters, setRecentChapters] = useState<RecentChapter[]>([]);
  const [scrollY, setScrollY] = useState(0);
  const heroRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);

  const [showSearch, setShowSearch] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchBooks, setSearchBooks] = useState<SearchBook[]>([]);

  const openSearch = () => {
    setShowSearch(true);
    setTimeout(() => searchInputRef.current?.focus(), 50);
  };
  const closeSearch = () => {
    setShowSearch(false);
    setSearchQuery('');
  };

  // Load the book list once when search opens, then filter client-side as the user types.
  useEffect(() => {
    if (!showSearch || searchBooks.length > 0) return;
    const versionId = getBibleVersionId();
    const lang = BIBLE_VERSIONS.find(v => v.id === versionId)?.lang || 'en';
    fetch(`/api/v1/bibles/${versionId}/books?lang=${lang}`)
      .then(r => r.json())
      .then((data: { success: boolean; data: SearchBook[] }) => {
        if (data.success && Array.isArray(data.data)) setSearchBooks(data.data);
      })
      .catch(() => {});
  }, [showSearch, searchBooks.length]);

  const searchResults = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return [];
    return searchBooks.filter(b =>
      b.title.toLowerCase().includes(q) ||
      b.titleRomanized?.toLowerCase().includes(q) ||
      b.englishTitle?.toLowerCase().includes(q)
    ).slice(0, 8);
  }, [searchQuery, searchBooks]);

  /* ── Global search: Hymns / downloaded songs / favorites / bookmarks ── */
  const [downloadedSongs, setDownloadedSongs] = useState<MusicSong[]>([]);
  const [musicFavorites, setMusicFavorites] = useState<MusicSong[]>([]);
  const [hymnFavorites, setHymnFavorites] = useState<HymnFavorite[]>([]);
  const [verseBookmarks, setVerseBookmarks] = useState<VerseBookmark[]>([]);
  const [hymnResults, setHymnResults] = useState<HymnResult[]>([]);
  const hymnSearchTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Local/account sources — loaded once when search opens (not per
  // keystroke), then filtered client-side as the user types, same pattern
  // as the Bible book list above.
  useEffect(() => {
    if (!showSearch) return;
    listDownloadedSongs().then(songs => setDownloadedSongs(songs));
    try {
      setMusicFavorites(JSON.parse(localStorage.getItem(MUSIC_FAVS_KEY) || '[]'));
    } catch { setMusicFavorites([]); }

    if (!getToken()) return;
    apiFetch<{ success: boolean; data: any[] }>('/api/v1/users/me/bookmarks?targetType=song')
      .then(res => {
        if (!res.success || !Array.isArray(res.data)) return;
        setHymnFavorites(res.data.map((b: any) => ({
          _id: b._id,
          songId: b.songRef?.songId || '',
          title: b.songRef?.title || '',
          languageCode: b.songRef?.languageCode || 'en',
        })));
      })
      .catch(() => {});
    apiFetch<{ success: boolean; data: any[] }>('/api/v1/users/me/bookmarks?targetType=verse')
      .then(res => {
        if (!res.success || !Array.isArray(res.data)) return;
        setVerseBookmarks(
          res.data
            .filter((b: any) => b.verseRef)
            .map((b: any) => ({
              _id: b._id,
              bookId: b.verseRef.bookId,
              bookName: b.verseRef.bookName || b.verseRef.bookId,
              chapterNumber: b.verseRef.chapterNumber,
              verseNumber: b.verseRef.verseNumber,
              versionId: b.verseRef.versionId,
              text: b.verseRef.text || '',
              note: b.note || null,
            }))
        );
      })
      .catch(() => {});
  }, [showSearch]);

  // The hymn catalog is too large (6,000+ entries) to fetch upfront like the
  // book list — debounced live backend search instead, same 350ms pattern
  // the Hymns tab's own search uses.
  useEffect(() => {
    if (hymnSearchTimer.current) clearTimeout(hymnSearchTimer.current);
    const q = searchQuery.trim();
    // A parsed Bible reference (e.g. "genesis 7") takes over the box —
    // don't also fire an unrelated hymn search for it.
    if (!q || parseReference(q, searchBooks)) {
      setHymnResults([]);
      return;
    }
    hymnSearchTimer.current = setTimeout(() => {
      fetch(`/api/v1/songs?search=${encodeURIComponent(q)}&limit=${MAX_RESULTS_PER_GROUP}`)
        .then(r => r.json())
        .then((data: { success: boolean; data: any[] }) => {
          if (data.success && Array.isArray(data.data)) {
            setHymnResults(data.data.map((s: any) => ({
              songId: s.songId, title: s.title, languageCode: s.languageCode, titleRomanized: s.titleRomanized,
            })));
          }
        })
        .catch(() => {});
    }, GLOBAL_SEARCH_DEBOUNCE_MS);
    return () => { if (hymnSearchTimer.current) clearTimeout(hymnSearchTimer.current); };
  }, [searchQuery, searchBooks]);

  const searchQ = searchQuery.trim().toLowerCase();

  const downloadedSongResults = useMemo(() => {
    if (!searchQ) return [];
    return downloadedSongs
      .filter(s => s.title.toLowerCase().includes(searchQ) || s.artist.toLowerCase().includes(searchQ))
      .slice(0, MAX_RESULTS_PER_GROUP);
  }, [searchQ, downloadedSongs]);

  const musicFavoriteResults = useMemo(() => {
    if (!searchQ) return [];
    return musicFavorites
      .filter(s => s.title.toLowerCase().includes(searchQ) || s.artist.toLowerCase().includes(searchQ))
      .slice(0, MAX_RESULTS_PER_GROUP);
  }, [searchQ, musicFavorites]);

  const hymnFavoriteResults = useMemo(() => {
    if (!searchQ) return [];
    return hymnFavorites.filter(f => f.title.toLowerCase().includes(searchQ)).slice(0, MAX_RESULTS_PER_GROUP);
  }, [searchQ, hymnFavorites]);

  const bookmarkResults = useMemo(() => {
    if (!searchQ) return [];
    return verseBookmarks
      .filter(b => b.text.toLowerCase().includes(searchQ) || (b.note ? b.note.toLowerCase().includes(searchQ) : false))
      .slice(0, MAX_RESULTS_PER_GROUP);
  }, [searchQ, verseBookmarks]);

  // "genesis 7:16" / "ephesians 22" — jump straight to that chapter (and
  // verse, if given) instead of just filtering the book list by name.
  const parsedReference = useMemo(
    () => parseReference(searchQuery, searchBooks),
    [searchQuery, searchBooks]
  );

  const hasAnySearchResults = Boolean(
    parsedReference || searchResults.length || hymnResults.length || downloadedSongResults.length ||
    musicFavoriteResults.length || hymnFavoriteResults.length || bookmarkResults.length
  );

  const lastSong = useMemo(() => {
    try { return JSON.parse(localStorage.getItem(LAST_PLAYED_KEY) || 'null'); } catch { return null; }
  }, []);

  const tc = useMemo(getTimeConfig, []);

  const textPrimary = 'text-[#163A2D]';
  const textMuted = 'text-[#163A2D]/55';

  const cardStyle = {
    background: '#ffffff',
    border: '1px solid rgba(22,58,45,0.08)',
    boxShadow: '0 2px 12px rgba(22,58,45,0.06)',
  } as React.CSSProperties;

  // Quote carousel
  useEffect(() => {
    const t = setInterval(() => setQuoteIdx(i => (i + 1) % QUOTES.length), 5000);
    return () => clearInterval(t);
  }, []);

  // Player playing state
  useEffect(() => {
    const h = (e: Event) => setSongPlaying((e as CustomEvent<boolean>).detail);
    window.addEventListener('player-playing', h);
    return () => window.removeEventListener('player-playing', h);
  }, []);

  // Parallax via parent scroll container
  useEffect(() => {
    const el = document.getElementById('main-scroll');
    if (!el) return;
    const h = () => setScrollY(el.scrollTop);
    el.addEventListener('scroll', h, { passive: true });
    return () => el.removeEventListener('scroll', h);
  }, []);

  // Recently visited chapters
  useEffect(() => {
    try {
      const data: RecentChapter[] = JSON.parse(localStorage.getItem(RECENT_CHAPTERS_KEY) || '[]');
      setRecentChapters(data.slice(0, 6));
    } catch {}
  }, []);

  return (
    <motion.div
      style={{ minHeight: '100%' }}
      className="w-full relative"
    >
      {/* ── Content ── */}
      <div className="px-4 pt-10 pb-28 max-w-2xl mx-auto space-y-4">

        {/* Header */}
        <div className="flex items-start justify-between mb-2 gap-3">
          {showSearch ? (
            <motion.div
              initial={{ opacity: 0, y: -6 }}
              animate={{ opacity: 1, y: 0 }}
              className="relative flex-1"
            >
              <Search size={18} className={`absolute left-4 top-1/2 -translate-y-1/2 ${textMuted}`} />
              <input
                ref={searchInputRef}
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Escape') closeSearch(); }}
                placeholder="Search Bible books…"
                className={`w-full bg-white border border-[#163A2D]/10 rounded-2xl pl-11 pr-11 py-3 font-sans text-sm ${textPrimary} placeholder:${textMuted} shadow-sm focus:outline-none focus:ring-2 focus:ring-[#163A2D]/20`}
              />
              <button
                onClick={closeSearch}
                className={`absolute right-3 top-1/2 -translate-y-1/2 w-6 h-6 rounded-full flex items-center justify-center ${textMuted}`}
              >
                <X size={16} />
              </button>

              {searchQuery.trim() && (
                <div className="absolute left-0 right-0 mt-2 bg-white rounded-2xl border border-[#163A2D]/10 shadow-lg overflow-hidden z-20 max-h-[65vh] overflow-y-auto scrollbar-hide">
                  {!hasAnySearchResults && (
                    <p className={`px-4 py-3 text-sm ${textMuted}`}>No results for "{searchQuery}"</p>
                  )}

                  {parsedReference && (
                    <button
                      onClick={() => {
                        closeSearch();
                        navigate(`/bible/${parsedReference.book.id}/${parsedReference.chapter}`, {
                          state: parsedReference.verse ? { verseNumber: parsedReference.verse } : undefined,
                        });
                      }}
                      className="w-full text-left px-4 py-3 font-sans text-sm hover:bg-[#163A2D]/8 transition-colors bg-[#163A2D]/5 border-b border-[#163A2D]/10"
                    >
                      <span className={`font-semibold ${textPrimary}`}>
                        {parsedReference.book.title} {parsedReference.chapter}
                        {parsedReference.verse ? `:${parsedReference.verse}` : ''}
                      </span>
                      <span className={`ml-2 text-xs ${textMuted}`}>Go to chapter</span>
                    </button>
                  )}

                  {searchResults.length > 0 && (
                    <div className="border-b border-[#163A2D]/8">
                      <p className={`px-4 pt-3 pb-1 text-[10px] font-bold uppercase tracking-wider ${textMuted}`}>Bible</p>
                      {searchResults.map((book) => (
                        <button
                          key={book.id}
                          onClick={() => { closeSearch(); navigate(`/bible/${book.id}`); }}
                          className={`w-full text-left px-4 py-2.5 font-sans text-sm hover:bg-[#163A2D]/5 transition-colors ${textPrimary}`}
                        >
                          {book.title}
                          <span className={`ml-2 text-xs ${textMuted}`}>{book.canon === 'OT' ? 'Old Testament' : 'New Testament'}</span>
                        </button>
                      ))}
                    </div>
                  )}

                  {hymnResults.length > 0 && (
                    <div className="border-b border-[#163A2D]/8">
                      <p className={`px-4 pt-3 pb-1 text-[10px] font-bold uppercase tracking-wider ${textMuted}`}>Hymns</p>
                      {hymnResults.map((hymn) => (
                        <button
                          key={hymn.songId}
                          onClick={() => {
                            closeSearch();
                            navigate('/hymns', { state: { openHymn: { songId: hymn.songId, title: hymn.title, languageCode: hymn.languageCode } } });
                          }}
                          className={`w-full text-left px-4 py-2.5 font-sans text-sm hover:bg-[#163A2D]/5 transition-colors truncate ${textPrimary}`}
                        >
                          {hymn.title}
                        </button>
                      ))}
                    </div>
                  )}

                  {downloadedSongResults.length > 0 && (
                    <div className="border-b border-[#163A2D]/8">
                      <p className={`px-4 pt-3 pb-1 text-[10px] font-bold uppercase tracking-wider ${textMuted}`}>Downloaded Songs</p>
                      {downloadedSongResults.map((song) => (
                        <button
                          key={song.videoId}
                          onClick={() => { closeSearch(); navigate('/songs', { state: { openSong: song } }); }}
                          className={`w-full text-left px-4 py-2.5 font-sans text-sm hover:bg-[#163A2D]/5 transition-colors ${textPrimary}`}
                        >
                          <span className="truncate">{song.title}</span>
                          <span className={`ml-2 text-xs ${textMuted}`}>{song.artist}</span>
                        </button>
                      ))}
                    </div>
                  )}

                  {(musicFavoriteResults.length > 0 || hymnFavoriteResults.length > 0) && (
                    <div className="border-b border-[#163A2D]/8">
                      <p className={`px-4 pt-3 pb-1 text-[10px] font-bold uppercase tracking-wider ${textMuted}`}>Favorites</p>
                      {musicFavoriteResults.map((song) => (
                        <button
                          key={song.videoId}
                          onClick={() => { closeSearch(); navigate('/songs', { state: { openSong: song } }); }}
                          className={`w-full text-left px-4 py-2.5 font-sans text-sm hover:bg-[#163A2D]/5 transition-colors ${textPrimary}`}
                        >
                          <span className="truncate">{song.title}</span>
                          <span className={`ml-2 text-xs ${textMuted}`}>{song.artist}</span>
                        </button>
                      ))}
                      {hymnFavoriteResults.map((fav) => (
                        <button
                          key={fav._id}
                          onClick={() => {
                            closeSearch();
                            navigate('/hymns', { state: { openHymn: { songId: fav.songId, title: fav.title, languageCode: fav.languageCode } } });
                          }}
                          className={`w-full text-left px-4 py-2.5 font-sans text-sm hover:bg-[#163A2D]/5 transition-colors truncate ${textPrimary}`}
                        >
                          {fav.title}
                          <span className={`ml-2 text-xs ${textMuted}`}>Hymn</span>
                        </button>
                      ))}
                    </div>
                  )}

                  {bookmarkResults.length > 0 && (
                    <div>
                      <p className={`px-4 pt-3 pb-1 text-[10px] font-bold uppercase tracking-wider ${textMuted}`}>Bookmarks &amp; Notes</p>
                      {bookmarkResults.map((bm) => (
                        <button
                          key={bm._id}
                          onClick={() => {
                            closeSearch();
                            navigate(`/bible/${bm.bookId}/${bm.chapterNumber}`, { state: { verseNumber: bm.verseNumber } });
                          }}
                          className={`w-full text-left px-4 py-2.5 font-sans text-sm hover:bg-[#163A2D]/5 transition-colors ${textPrimary}`}
                        >
                          <span className="font-semibold">{bm.bookName} {bm.chapterNumber}:{bm.verseNumber}</span>
                          <span className={`ml-2 text-xs ${textMuted}`}>{bm.note ? 'Note' : 'Bookmark'}</span>
                          <p className={`text-xs truncate ${textMuted}`}>{bm.note || bm.text}</p>
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </motion.div>
          ) : (
            <div>
              <h1 className={`text-3xl font-bold font-serif ${textPrimary} leading-tight`}>{tc.greeting}</h1>
              <p className={`text-sm mt-1 ${textMuted}`}>{tc.subtitle}</p>
            </div>
          )}

          {!showSearch && (
            <div className="flex items-center gap-2 flex-shrink-0">
              <motion.button
                whileTap={{ scale: 0.88 }}
                onClick={openSearch}
                className="w-11 h-11 rounded-full bg-white border border-[#163A2D]/10 shadow-sm flex items-center justify-center"
              >
                <Search size={19} className="text-[#163A2D]" />
              </motion.button>

              {/* Hymns shortcut — mobile only (sidebar handles it on md+) */}
              <motion.button
                whileTap={{ scale: 0.88 }}
                onClick={() => navigate('/hymns')}
                className="md:hidden flex-shrink-0 w-11 h-11 rounded-full bg-white border border-[#163A2D]/10 shadow-sm flex items-center justify-center"
              >
                <Music2 size={19} className="text-[#163A2D]" strokeWidth={1.7} />
              </motion.button>
            </div>
          )}
        </div>

        {/* ── Quote carousel ── */}
        <div className="rounded-[22px] p-5" style={cardStyle}>
          <div className="flex items-center gap-2 mb-3">
            <Star size={13} className={'text-yellow-600'} fill="currentColor" />
            <span className={`text-[10px] font-bold uppercase tracking-widest ${textMuted}`}>Daily Inspiration</span>
          </div>
          <AnimatePresence mode="wait">
            <motion.div
              key={quoteIdx}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -8 }}
              transition={{ duration: 0.35 }}
            >
              <p className={`font-serif text-[15px] italic leading-relaxed ${textPrimary}`}>
                "{QUOTES[quoteIdx].text}"
              </p>
              <p className={`text-xs mt-2 font-medium ${textMuted}`}>— {QUOTES[quoteIdx].author}</p>
            </motion.div>
          </AnimatePresence>
          <div className="flex gap-1.5 mt-4">
            {QUOTES.map((_, i) => (
              <button
                key={i}
                onClick={() => setQuoteIdx(i)}
                className={`h-[3px] rounded-full transition-all duration-300 bg-[#163A2D] ${i === quoteIdx ? 'w-6 opacity-70' : 'w-2 opacity-20'}`}
              />
            ))}
          </div>
        </div>

        {/* ── Verse of the Day (parallax hero) ── */}
        <div className="rounded-[24px] overflow-hidden relative" ref={heroRef} style={cardStyle}>
          {/* Parallax radial glow */}
          <div
            className="absolute inset-0 pointer-events-none"
            style={{
              transform: `translateY(${scrollY * 0.18}px)`,
              background: 'radial-gradient(ellipse at 75% 25%, rgba(22,58,45,0.14) 0%, transparent 65%)',
            }}
          />
          <div className="relative z-10 p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className={`w-10 h-10 rounded-full flex items-center justify-center ${'bg-[#163A2D]/10'}`}>
                <BookMarked size={20} className={'text-[#163A2D]'} />
              </div>
              <div>
                <h3 className={`font-semibold font-sans text-sm ${textPrimary}`}>Verse of the Day</h3>
                <p className={`font-sans text-xs ${textMuted}`}>John 3:16</p>
              </div>
            </div>
            <p className={`leading-relaxed font-serif text-lg italic mb-5 ${textPrimary}`}>
              "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life."
            </p>
            <motion.button
              whileHover={{ scale: 1.01 }}
              whileTap={{ scale: 0.97 }}
              onClick={() => navigate('/bible/JHN/3')}
              className={`w-full py-3 rounded-2xl font-sans font-semibold text-sm transition-all ${'bg-[#163A2D]/10 text-[#163A2D] hover:bg-[#163A2D]/18'}`}
            >
              Read Chapter
            </motion.button>
          </div>
        </div>

        {/* ── Mini Music Player (3rd card) ── */}
        <motion.div
          className="rounded-[24px] p-4 flex items-center gap-3 cursor-pointer relative overflow-hidden"
          style={{ background: 'linear-gradient(135deg, #163A2D 0%, #1e4d38 50%, #215442 100%)' }}
          whileHover={{ scale: 1.01 }}
          whileTap={{ scale: 0.98 }}
          onClick={() => navigate('/songs')}
        >
          <div className="absolute inset-0 pointer-events-none"
            style={{ background: 'radial-gradient(ellipse at 85% 40%, rgba(110,231,183,0.25) 0%, transparent 55%)' }} />

          <div className="w-14 h-14 rounded-xl overflow-hidden flex-shrink-0 bg-white/10 flex items-center justify-center relative z-10">
            {lastSong?.image
              ? <img src={lastSong.image} alt={lastSong.title} className="w-full h-full object-cover" />
              : <Headphones size={24} className="text-white/55" />
            }
          </div>

          <div className="flex-1 min-w-0 relative z-10">
            <p className="text-white/60 text-[10px] font-bold uppercase tracking-wider mb-0.5">
              {songPlaying ? 'Now Playing' : lastSong ? 'Last Played' : 'Music'}
            </p>
            <p className="text-white font-semibold text-sm truncate">{lastSong?.title ?? 'Tap to browse music'}</p>
            <p className="text-white/55 text-xs truncate mt-0.5">{lastSong?.artist ?? 'Worship Music'}</p>
          </div>

          <div className="flex items-center gap-2.5 flex-shrink-0 relative z-10">
            {songPlaying && <SoundwaveMini playing />}
            <div
              onClick={e => { e.stopPropagation(); navigate('/songs', { state: { autoplay: true } }); }}
              className="w-10 h-10 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center transition-colors"
            >
              <Play size={17} className="text-white ml-0.5" fill="white" />
            </div>
          </div>
        </motion.div>

        {/* ── Daily Plan card ── */}
        <div className="rounded-[22px] p-5" style={cardStyle}>
          <div className="flex items-center justify-between mb-3">
            <div>
              <p className={`text-[10px] font-bold uppercase tracking-widest ${textMuted}`}>Daily Plan</p>
              <h3 className={`font-serif font-semibold text-[15px] mt-0.5 ${textPrimary}`}>30-Day New Testament</h3>
            </div>
            <span className={`px-3 py-1.5 rounded-full text-xs font-bold ${'bg-[#163A2D]/10 text-[#163A2D]'}`}>
              Day {STREAK}
            </span>
          </div>
          <div className={`w-full h-2 rounded-full overflow-hidden ${'bg-[#163A2D]/10'}`}>
            <motion.div
              className="h-full rounded-full"
              style={{ background: '#163A2D' }}
              initial={{ width: 0 }}
              animate={{ width: `${(STREAK / 30) * 100}%` }}
              transition={{ duration: 1.2, ease: 'easeOut', delay: 0.3 }}
            />
          </div>
          <div className="flex justify-between mt-2">
            <p className={`text-xs ${textMuted}`}>{STREAK} of 30 days</p>
            <button
              onClick={() => navigate('/bible/MAT/1')}
              className={`text-xs font-bold flex items-center gap-0.5 ${'text-[#163A2D]'}`}
            >
              Continue <ChevronRight size={12} />
            </button>
          </div>
        </div>

        {/* ── Recently Visited ── */}
        {recentChapters.length > 0 && (
          <div>
            <p className={`text-[10px] font-bold uppercase tracking-widest mb-2.5 px-1 ${textMuted}`}>Recently Visited</p>
            <div className="flex gap-2 overflow-x-auto scrollbar-hide pb-1 -mx-1 px-1">
              {recentChapters.map((ch, i) => (
                <motion.button
                  key={i}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => navigate(`/bible/${ch.book}/${ch.chapter}`)}
                  className={`flex-shrink-0 px-4 py-2.5 rounded-[14px] text-sm font-semibold ${textPrimary}`}
                  style={cardStyle}
                >
                  {ch.label}
                </motion.button>
              ))}
            </div>
          </div>
        )}

        {/* ── Quick Actions ── */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {[
            { Icon: BookOpen, label: 'Read Bible', sub: 'Explore scripture', path: '/bible' },
            { Icon: Clock, label: 'Continue', sub: 'John 3', path: '/bible/JHN/3' },
            { Icon: Headphones, label: 'Music', sub: 'Worship songs', path: '/songs' },
            { Icon: Bookmark, label: 'Bookmarks', sub: 'Saved verses', path: '/profile' },
          ].map(({ Icon, label, sub, path }) => (
            <motion.button
              key={label}
              whileHover={{ scale: 1.03, y: -2 }}
              whileTap={{ scale: 0.96 }}
              onClick={() => navigate(path)}
              className="flex flex-col items-center justify-center p-4 rounded-2xl"
              style={cardStyle}
            >
              <div className={`w-12 h-12 rounded-full flex items-center justify-center mb-3 ${'bg-[#163A2D]/10'}`}>
                <Icon size={22} className={'text-[#163A2D]'} />
              </div>
              <p className={`font-semibold font-sans text-sm mb-0.5 ${textPrimary}`}>{label}</p>
              <p className={`font-sans text-xs ${textMuted}`}>{sub}</p>
            </motion.button>
          ))}
        </div>

        {/* ── Stats row ── */}
        <div className="grid grid-cols-2 gap-3">

          {/* Streak with animated flame */}
          <motion.div
            whileHover={{ scale: 1.02, y: -2 }}
            className="rounded-[24px] p-5 relative overflow-hidden cursor-pointer"
            style={{ background: 'linear-gradient(135deg, #163A2D 0%, #0a1f14 100%)' }}
            onClick={() => showConfetti || setShowConfetti(true)}
          >
            {/* Pulsing bg flame */}
            <motion.div
              className="absolute -bottom-3 -right-3"
              animate={{ scale: [1, 1.1, 1], opacity: [0.18, 0.28, 0.18] }}
              transition={{ duration: 2.2, repeat: Infinity, ease: 'easeInOut' }}
            >
              <Flame size={80} className="text-orange-400" />
            </motion.div>

            <div className="flex items-center gap-2 mb-2 relative z-10">
              <motion.span
                animate={{ scale: [1, 1.18, 1], rotate: [0, -8, 8, 0] }}
                transition={{ duration: 1.6, repeat: Infinity, ease: 'easeInOut' }}
                style={{ display: 'inline-flex' }}
              >
                <Flame size={20} className="text-orange-400" />
              </motion.span>
              <p className="text-white/75 font-sans text-xs uppercase tracking-wider font-bold">Daily Streak</p>
            </div>
            <p className="text-white font-serif text-4xl font-bold relative z-10">{STREAK}</p>
            <p className="text-white/55 font-sans text-xs relative z-10 mt-1">days in a row 🔥</p>
          </motion.div>

          {/* Bible progress rings */}
          <motion.div
            whileHover={{ scale: 1.02, y: -2 }}
            className="rounded-[24px] p-5"
            style={cardStyle}
          >
            <p className={`text-[10px] font-bold uppercase tracking-widest mb-3 ${textMuted}`}>Bible Progress</p>
            <div className="flex flex-col md:flex-row md:items-center gap-2 md:gap-4">
              <div className="flex items-center gap-2">
                <ProgressRing percent={0.08} color="#6EE7B7" size={44} strokeWidth={4}
                  trackColor={'rgba(22,58,45,0.12)'}>
                  <span className={`text-[9px] font-bold ${textPrimary}`}>OT</span>
                </ProgressRing>
                <ProgressRing percent={0.23} color="#93C5FD" size={44} strokeWidth={4}
                  trackColor={'rgba(22,58,45,0.12)'}>
                  <span className={`text-[9px] font-bold ${textPrimary}`}>NT</span>
                </ProgressRing>
              </div>
              <div className="mt-1 md:mt-0">
                <p className={`font-serif text-2xl md:text-3xl font-bold leading-none ${textPrimary}`}>47</p>
                <p className={`text-xs mt-1 ${textMuted}`}>chapters read</p>
              </div>
            </div>
          </motion.div>
        </div>

      </div>

    </motion.div>
  );
}
