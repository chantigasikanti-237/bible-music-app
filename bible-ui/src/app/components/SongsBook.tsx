import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router';
import { motion, AnimatePresence } from 'motion/react';
import { ChevronLeft, Globe, Search, Heart, MoreVertical, Share2, Download } from 'lucide-react';
import { apiFetch, getToken } from '../lib/api';
import { getHymnsLanguage, setHymnsLanguage, isUniversalLanguageEnabled, applyUniversalLanguage, type LanguageCode } from '../lib/languagePreference';
import { BIBLE_VERSIONS } from '../screens/BibleLibrary';

interface OpenHymnRequest {
  songId: string;
  title: string;
  languageCode: string;
}

interface SongsBookProps {
  isOpen: boolean;
  onClose: () => void;
  standalone?: boolean;
  openHymn?: OpenHymnRequest | null;
}

const LANGUAGES = [
  { id: 'en', label: 'English',              short: 'EN' },
  { id: 'te', label: 'Telugu (తెలుగు)',       short: 'TE' },
  { id: 'hi', label: 'Hindi (हिंदी)',         short: 'HI' },
  { id: 'ta', label: 'Tamil (தமிழ்)',         short: 'TA' },
  { id: 'ml', label: 'Malayalam (മലയാളം)',    short: 'ML' },
  { id: 'kn', label: 'Kannada (ಕನ್ನಡ)',       short: 'KN' },
  { id: 'mr', label: 'Marathi (मराठी)',       short: 'MR' },
];

interface LyricsSection {
  label: string | null;
  text: string;
}

interface Song {
  _id: string;
  songId: string;
  title: string;
  slug: string;
  artist: string | null;
  lyricsSections: LyricsSection[];
  languageCode: string;
}

export function SongsBook({ isOpen, onClose, standalone = false, openHymn = null }: SongsBookProps) {
  const navigate = useNavigate();
  const [lang, setLang] = useState(getHymnsLanguage);
  const [universalOn] = useState(isUniversalLanguageEnabled);
  const [showLangMenu, setShowLangMenu] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [songs, setSongs] = useState<Song[]>([]);
  const [searchResults, setSearchResults] = useState<Song[] | null>(null);
  const [searchNumberOffset, setSearchNumberOffset] = useState<number>(0);
  const [loading, setLoading] = useState(false);
  const [searching, setSearching] = useState(false);
  const [selectedSong, setSelectedSong] = useState<Song | null>(null);
  // Maps a hymn's songId -> its bookmark _id on the backend, so a favorite
  // survives reloads and shows up in Profile > Favourite Hymns.
  const [favoriteMap, setFavoriteMap] = useState<Record<string, string>>({});
  const [showDotsMenu, setShowDotsMenu] = useState(false);
  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const cache = useRef<Record<string, Song[]>>({});

  // Initial 100 songs load — uses cache so switching back is instant
  useEffect(() => {
    if (!isOpen) return;
    setSearchResults(null);
    setSearchQuery('');
    setSearchNumberOffset(0);
    setSearching(false);
    setSelectedSong(null);
    if (cache.current[lang]) {
      setSongs(cache.current[lang]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setSongs([]);
    fetch(`/api/v1/songs?language=${lang}&limit=100`)
      .then(r => r.json())
      .then((data: { success: boolean; data: Song[] }) => {
        if (data.success && Array.isArray(data.data)) {
          cache.current[lang] = data.data;
          setSongs(data.data);
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [lang, isOpen]);

  // Debounced backend search — lang NOT a dep (lang change resets searchQuery which re-triggers this)
  useEffect(() => {
    if (searchTimer.current) clearTimeout(searchTimer.current);
    const q = searchQuery.trim();
    if (!q) {
      setSearchResults(null);
      setSearchNumberOffset(0);
      setSearching(false); // clear spinner when search is cleared
      return;
    }
    setSearching(true);
    searchTimer.current = setTimeout(() => {
      const isNumber = /^\d+$/.test(q);
      const num = parseInt(q, 10);
      const url = isNumber && num > 0
        ? `/api/v1/songs?language=${lang}&page=${num}&limit=1`
        : `/api/v1/songs?language=${lang}&search=${encodeURIComponent(q)}&limit=50`;

      fetch(url)
        .then(r => r.json())
        .then((data: { success: boolean; data: Song[] }) => {
          if (data.success && Array.isArray(data.data)) {
            setSearchResults(data.data);
            setSearchNumberOffset(isNumber && num > 0 ? num - 1 : 0);
          }
        })
        .catch(() => {})
        .finally(() => setSearching(false));
    }, 350);
  }, [searchQuery]); // eslint-disable-line react-hooks/exhaustive-deps

  const displayedSongs = searchQuery.trim() ? (searchResults ?? []) : songs;

  // Load existing hymn bookmarks once so the heart icon reflects prior favorites.
  useEffect(() => {
    if (!isOpen || !getToken()) return;
    apiFetch<{ success: boolean; data: any[] }>('/api/v1/users/me/bookmarks?targetType=song')
      .then(res => {
        if (res.success && Array.isArray(res.data)) {
          const map: Record<string, string> = {};
          res.data.forEach((b: any) => {
            if (b.songRef?.songId) map[b.songRef.songId] = b._id;
          });
          setFavoriteMap(map);
        }
      })
      .catch(() => {});
  }, [isOpen]);

  // Deep-link from Profile > Favourite Hymns: jump straight to that hymn's
  // reading view instead of just landing on the list.
  useEffect(() => {
    if (!isOpen || !openHymn) return;
    const targetLang = openHymn.languageCode || 'en';
    setLang(targetLang);
    fetch(`/api/v1/songs?language=${targetLang}&search=${encodeURIComponent(openHymn.title)}&limit=20`)
      .then(r => r.json())
      .then((data: { success: boolean; data: Song[] }) => {
        if (data.success && Array.isArray(data.data)) {
          const match = data.data.find(s => s.songId === openHymn.songId) || data.data[0];
          if (match) setSelectedSong(match);
        }
      })
      .catch(() => {});
  }, [isOpen, openHymn?.songId]); // eslint-disable-line react-hooks/exhaustive-deps

  const toggleFavorite = async (song: Song) => {
    if (!getToken()) { navigate('/login'); return; }

    const existingBookmarkId = favoriteMap[song.songId];
    if (existingBookmarkId) {
      setFavoriteMap(prev => {
        const next = { ...prev };
        delete next[song.songId];
        return next;
      });
      try {
        await apiFetch(`/api/v1/users/me/bookmarks/${existingBookmarkId}`, { method: 'DELETE' });
      } catch {
        setFavoriteMap(prev => ({ ...prev, [song.songId]: existingBookmarkId }));
      }
      return;
    }

    try {
      const res = await apiFetch<{ success: boolean; data: { _id: string } }>('/api/v1/users/me/bookmarks', {
        method: 'POST',
        body: JSON.stringify({
          targetType: 'song',
          songId: song.songId,
          slug: song.slug,
          title: song.title,
          languageCode: song.languageCode,
        }),
      });
      if (res.success) {
        setFavoriteMap(prev => ({ ...prev, [song.songId]: res.data._id }));
      }
    } catch {
      // ignore — heart stays unfavorited
    }
  };

  const lyricsText = (song: Song) =>
    song.lyricsSections.map(s => (s.label ? `[${s.label}]\n${s.text}` : s.text)).join('\n\n');

  const handleShare = (song: Song) => {
    const text = `${song.title}${song.artist ? `\n— ${song.artist}` : ''}\n\n${lyricsText(song)}`;
    if (navigator.share) {
      navigator.share({ title: song.title, text }).catch(() => {});
    } else {
      navigator.clipboard.writeText(text).catch(() => {});
    }
    setShowDotsMenu(false);
  };

  const handleDownload = (song: Song) => {
    const text = `${song.title}${song.artist ? `\n— ${song.artist}` : ''}\n\n${lyricsText(song)}`;
    const blob = new Blob([text], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${song.slug || song.title.replace(/\s+/g, '_')}.txt`;
    a.click();
    URL.revokeObjectURL(url);
    setShowDotsMenu(false);
  };

  const innerContent = (
    <>
          {/* ── SONG LIST ── */}
          <AnimatePresence>
            {!selectedSong && (
              <motion.div
                key="list"
                initial={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: '-100%' }}
                transition={{ duration: 0.22 }}
                className="flex flex-col h-full"
              >
                {/* Header */}
                <div className="pt-safe pb-4 px-4 bg-[#F6F1E7]/90 backdrop-blur-2xl border-b border-[var(--primary)]/5 flex items-center justify-between z-20 sticky top-0">
                  <button onClick={onClose} className="p-2 -ml-2 rounded-full hover:bg-black/5 active:bg-black/10 transition-colors">
                    <ChevronLeft size={28} className="text-[var(--primary)]" />
                  </button>
                  <h2 className="font-serif text-xl font-medium text-[var(--primary)]">Hymns</h2>

                  {/* Language selector — hidden while Universal Language is on */}
                  {!universalOn && (
                  <div className="relative">
                    <button
                      onClick={() => setShowLangMenu(!showLangMenu)}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-[#5B8DEF]/10 text-[#5B8DEF] font-medium text-sm transition-colors hover:bg-[#5B8DEF]/20"
                    >
                      <Globe size={16} />
                      {LANGUAGES.find(l => l.id === lang)?.short}
                    </button>
                    <AnimatePresence>
                      {showLangMenu && (
                        <>
                          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                            className="fixed inset-0 z-40" onClick={() => setShowLangMenu(false)} />
                          <motion.div
                            initial={{ opacity: 0, y: 10, scale: 0.95 }}
                            animate={{ opacity: 1, y: 0, scale: 1 }}
                            exit={{ opacity: 0, y: 10, scale: 0.95 }}
                            className="absolute right-0 top-full mt-2 w-44 bg-white rounded-2xl shadow-xl border border-black/5 overflow-hidden z-50 p-1"
                          >
                            {LANGUAGES.map(l => (
                              <button key={l.id} onClick={() => {
                                setLang(l.id);
                                setHymnsLanguage(l.id as LanguageCode);
                                if (isUniversalLanguageEnabled()) {
                                  const versionId = BIBLE_VERSIONS.find(v => v.lang === l.id)?.id ?? BIBLE_VERSIONS[0].id;
                                  applyUniversalLanguage(l.id as LanguageCode, versionId);
                                }
                                setShowLangMenu(false);
                              }}
                                className={`w-full text-left px-4 py-2.5 text-sm rounded-xl transition-all ${lang === l.id ? 'bg-[#5B8DEF]/10 text-[#5B8DEF] font-semibold' : 'text-gray-600 hover:bg-gray-50'}`}>
                                {l.label}
                              </button>
                            ))}
                          </motion.div>
                        </>
                      )}
                    </AnimatePresence>
                  </div>
                  )}
                </div>

                {/* Body */}
                <div className="flex-1 overflow-y-auto scrollbar-hide px-4 pt-6 pb-24 space-y-3 bg-[#F6F1E7]">
                  {/* Search */}
                  <div className="relative mb-6">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400" size={20} />
                    <input
                      type="text"
                      placeholder="Search songs..."
                      value={searchQuery}
                      onChange={e => setSearchQuery(e.target.value)}
                      className="w-full bg-white border border-[var(--primary)]/10 shadow-sm rounded-2xl py-3.5 pl-12 pr-4 text-[#2c2c2c] placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-[#5B8DEF]/30 transition-shadow"
                    />
                  </div>

                  {(loading || searching) && (
                    <div className="flex items-center justify-center py-12">
                      <div className="w-8 h-8 border-2 border-[#5B8DEF] border-t-transparent rounded-full animate-spin" />
                    </div>
                  )}

                  {!loading && !searching && displayedSongs.length === 0 && (
                    <p className="text-center text-gray-400 text-sm py-8">
                      {searchQuery.trim() ? `No results for "${searchQuery}"` : 'No songs found'}
                    </p>
                  )}

                  {!loading && !searching && displayedSongs.map((song, i) => (
                    <motion.button
                      key={song._id + i}
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      transition={{ delay: i * 0.03 }}
                      whileTap={{ scale: 0.99 }}
                      onClick={() => setSelectedSong(song)}
                      className="w-full bg-white rounded-[20px] p-4 flex items-center gap-4 shadow-sm border border-[var(--primary)]/5 text-left"
                    >
                      <div className="w-12 h-12 rounded-full bg-[var(--primary)]/5 flex items-center justify-center text-[var(--primary)] font-serif font-bold text-lg shrink-0">
                        {String(searchNumberOffset + i + 1).padStart(2, '0')}
                      </div>
                      <div className="flex-1 min-w-0">
                        <h3 className="text-[#2c2c2c] font-semibold text-base truncate tracking-tight">{song.title}</h3>
                        {song.artist && <p className="text-gray-500 text-xs mt-0.5">{song.artist}</p>}
                      </div>
                      <ChevronLeft size={18} className="text-gray-400 rotate-180 shrink-0" />
                    </motion.button>
                  ))}
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* ── SONG DETAIL ── */}
          <AnimatePresence>
            {selectedSong && (
              <motion.div
                key="detail"
                initial={{ x: '100%' }}
                animate={{ x: 0 }}
                exit={{ x: '100%' }}
                transition={{ type: 'spring', damping: 30, stiffness: 260 }}
                className="absolute inset-0 bg-[#F6F1E7] flex flex-col"
              >
                {/* Detail header */}
                <div className="pt-safe pb-4 px-4 bg-[#F6F1E7]/90 backdrop-blur-2xl border-b border-[var(--primary)]/5 flex items-center justify-between z-20 sticky top-0">
                  <button onClick={() => { setSelectedSong(null); setShowDotsMenu(false); }}
                    className="p-2 -ml-2 rounded-full hover:bg-black/5 transition-colors">
                    <ChevronLeft size={28} className="text-[var(--primary)]" />
                  </button>

                  <span className="font-serif text-lg font-medium text-[var(--primary)] truncate max-w-[50%] text-center">
                    {selectedSong.title}
                  </span>

                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => toggleFavorite(selectedSong)}
                      className="w-10 h-10 rounded-full flex items-center justify-center hover:bg-black/5 transition-colors"
                    >
                      <Heart
                        size={20}
                        className={favoriteMap[selectedSong.songId] ? 'text-rose-500 fill-rose-500' : 'text-gray-400'}
                      />
                    </button>

                    <div className="relative">
                      <button
                        onClick={() => setShowDotsMenu(v => !v)}
                        className="w-10 h-10 rounded-full flex items-center justify-center hover:bg-black/5 transition-colors"
                      >
                        <MoreVertical size={20} className="text-gray-500" />
                      </button>

                      <AnimatePresence>
                        {showDotsMenu && (
                          <>
                            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
                              className="fixed inset-0 z-40" onClick={() => setShowDotsMenu(false)} />
                            <motion.div
                              initial={{ opacity: 0, y: 8, scale: 0.95 }}
                              animate={{ opacity: 1, y: 0, scale: 1 }}
                              exit={{ opacity: 0, y: 8, scale: 0.95 }}
                              className="absolute right-0 top-full mt-2 w-40 bg-white rounded-2xl shadow-xl border border-black/5 overflow-hidden z-50 p-1"
                            >
                              <button
                                onClick={() => handleShare(selectedSong)}
                                className="w-full flex items-center gap-3 px-4 py-3 text-sm text-gray-700 rounded-xl hover:bg-gray-50 transition-colors"
                              >
                                <Share2 size={16} className="text-[#5B8DEF]" />
                                Share
                              </button>
                              <button
                                onClick={() => handleDownload(selectedSong)}
                                className="w-full flex items-center gap-3 px-4 py-3 text-sm text-gray-700 rounded-xl hover:bg-gray-50 transition-colors"
                              >
                                <Download size={16} className="text-[var(--primary)]" />
                                Download
                              </button>
                            </motion.div>
                          </>
                        )}
                      </AnimatePresence>
                    </div>
                  </div>
                </div>

                {/* Lyrics body */}
                <div className="flex-1 overflow-y-auto scrollbar-hide px-6 py-8 pb-24">
                  {selectedSong.artist && (
                    <p className="text-gray-500 text-sm mb-6 font-medium">— {selectedSong.artist}</p>
                  )}
                  {selectedSong.lyricsSections.length > 0 ? (
                    <div className="space-y-6">
                      {selectedSong.lyricsSections.map((section, i) => (
                        <div key={i}>
                          {section.label && (
                            <p className="text-[#5B8DEF] text-xs font-semibold uppercase tracking-widest mb-2">
                              {section.label}
                            </p>
                          )}
                          <p className="text-[#2c2c2c] text-base leading-8 whitespace-pre-line font-serif">
                            {section.text}
                          </p>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p className="text-gray-400 text-sm text-center py-8">No lyrics available</p>
                  )}
                </div>
              </motion.div>
            )}
          </AnimatePresence>
    </>
  );

  if (standalone) {
    return (
      <div className="h-full flex flex-col bg-[#F6F1E7] overflow-hidden relative">
        {innerContent}
      </div>
    );
  }

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ x: '100%' }}
          animate={{ x: 0 }}
          exit={{ x: '100%' }}
          transition={{ type: 'spring', damping: 30, stiffness: 250, mass: 0.8 }}
          drag="x"
          dragConstraints={{ left: 0, right: 0 }}
          dragElastic={0.05}
          onDragEnd={(_e, { offset, velocity }) => {
            if ((offset.x > 80 || velocity.x > 500) && !selectedSong) onClose();
          }}
          className="fixed inset-0 z-[100] bg-[#F6F1E7] flex flex-col shadow-[-10px_0_40px_rgba(0,0,0,0.1)]"
          style={{ touchAction: 'pan-y' }}
        >
          {innerContent}
        </motion.div>
      )}
    </AnimatePresence>
  );
}
