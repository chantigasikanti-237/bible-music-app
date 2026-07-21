import { useState, useEffect, useRef, useCallback, useSyncExternalStore } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { Search, Play, Pause, Heart, Download, TrendingUp, X, Music, Globe, Check, CloudDownload, ListMusic, Plus, Trash2, ChevronLeft, Clock, Mic } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { MiniPlayer, type PlayerSong } from '../components/MiniPlayer';
import { getSongAudioBlobUrlOffline, isSongDownloaded, removeSongOffline, listDownloadedSongs } from '../lib/offlineMusicStore';
import { subscribe, getSnapshot, getActiveDownloads, startSongDownload, cancelSongDownload, getLastLimitMessage } from '../lib/musicDownloadManager';
import { apiFetch } from '../lib/api';
import { getMusicLanguageKey, setMusicLanguageKey, isUniversalLanguageEnabled, applyUniversalLanguage, musicKeyToCode, getMusicFollowsUniversal } from '../lib/languagePreference';
import { useVoiceSearch, isVoiceSearchSupported } from '../lib/useVoiceSearch';
import { BIBLE_VERSIONS } from './BibleLibrary';
import {
  getPlaylists, createPlaylist, deletePlaylist, addSongToPlaylist, removeSongFromPlaylist, getPlaylist,
  type Playlist,
} from '../lib/musicPlaylistStore';

const LANGUAGES = [
  { key: 'English',   label: 'English',    sublabel: 'Worship & Praise',   flag: '🇬🇧' },
  { key: 'Telugu',    label: 'తెలుగు',      sublabel: 'Telugu Christian',    flag: '🇮🇳' },
  { key: 'Hindi',     label: 'हिंदी',       sublabel: 'Hindi Christian',     flag: '🇮🇳' },
  { key: 'Tamil',     label: 'தமிழ்',       sublabel: 'Tamil Christian',     flag: '🇮🇳' },
  { key: 'Malayalam', label: 'മലയാളം',     sublabel: 'Malayalam Christian', flag: '🇮🇳' },
  { key: 'Kannada',   label: 'ಕನ್ನಡ',       sublabel: 'Kannada Christian',   flag: '🇮🇳' },
];

const FAVS_KEY = 'music_favorites_v2';
const LAST_PLAYED_KEY = 'music_last_played_v1';

// Extra Trending shelves (Spotify-style horizontal rows), sourced from the
// backend's category endpoint. Keys must match audioService.js's CATEGORIES map.
const SHELVES = [
  { key: 'hymns', title: 'Hymns Mix' },
  { key: 'longmix', title: 'Non-Stop Worship' },
] as const;

interface Song {
  videoId: string;
  title: string;
  artist: string;
  image: string;
  language: string;
  isLongMix: boolean;
}

const getFavs = (): Song[] => {
  try { return JSON.parse(localStorage.getItem(FAVS_KEY) || '[]'); } catch { return []; }
};
const saveFavs = (songs: Song[]) => localStorage.setItem(FAVS_KEY, JSON.stringify(songs));

const toPlayerSong = (s: Song): PlayerSong => ({
  videoId: s.videoId, title: s.title, artist: s.artist, image: s.image,
});

const mapApi = (raw: { id: string; title: string; thumbnail: string; channelTitle: string; isLongMix?: boolean }, lang: string): Song => ({
  videoId: raw.id,
  title: raw.title,
  artist: raw.channelTitle,
  image: raw.thumbnail,
  language: lang,
  isLongMix: raw.isLongMix ?? false,
});

export function Songs() {
  const location = useLocation();
  const navigate = useNavigate();

  /* ── Language / Tab / Search ─────────────────────────────── */
  const [lang, setLang] = useState<string>(getMusicLanguageKey);
  const [activeTab, setActiveTab] = useState<'trending' | 'assets'>('trending');
  const [showLangPicker, setShowLangPicker] = useState(false);
  const [trending, setTrending] = useState<Song[]>([]);
  const [trendingLoading, setTrendingLoading] = useState(true);
  const [shelves, setShelves] = useState<Record<string, Song[]>>({});
  const [shelvesLoading, setShelvesLoading] = useState<Record<string, boolean>>({});
  const [favorites, setFavorites] = useState<Song[]>(getFavs);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<Song[]>([]);
  const [searching, setSearching] = useState(false);
  const trendingCache = useRef<Record<string, Song[]>>({});
  const shelfCache = useRef<Record<string, Song[]>>({});
  const searchTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const currentLang = LANGUAGES.find(l => l.key === lang) || LANGUAGES[0];
  const [universalOn] = useState(isUniversalLanguageEnabled);
  const [musicFollowsUniversal] = useState(getMusicFollowsUniversal);
  const { isListening, start: startVoiceSearch } = useVoiceSearch(setSearchQuery, musicKeyToCode(lang));

  /* ── Assets: Favourites / Downloads / Playlists ──────────── */
  const [assetsView, setAssetsView] = useState<'favorites' | 'downloads' | 'playlists'>('favorites');
  const [downloads, setDownloads] = useState<Song[]>([]);
  const [playlists, setPlaylists] = useState<Playlist[]>(getPlaylists);
  const [openPlaylist, setOpenPlaylist] = useState<Playlist | null>(null);
  const [showCreatePlaylist, setShowCreatePlaylist] = useState(false);
  const [newPlaylistName, setNewPlaylistName] = useState('');
  const [addToPlaylistSong, setAddToPlaylistSong] = useState<Song | null>(null);

  useEffect(() => {
    if (activeTab === 'assets' && assetsView === 'downloads') {
      listDownloadedSongs().then(setDownloads);
    }
  }, [activeTab, assetsView]);

  // Songs currently downloading/queued — merged into the Downloads grid below
  // so a download shows up there the moment it starts, not just once it's
  // finished and saved to IndexedDB.
  const activeDownloads = useSyncExternalStore(subscribe, getActiveDownloads);
  const activeDownloadIds = useRef<Set<string>>(new Set());
  useEffect(() => {
    const currentIds = new Set(activeDownloads.map(d => d.song.videoId));
    const justFinished = [...activeDownloadIds.current].some(id => !currentIds.has(id));
    activeDownloadIds.current = currentIds;
    // A download that was active a moment ago and isn't anymore either
    // finished or failed/was cancelled — either way, the completed list on
    // IndexedDB may have changed, so refresh it if that's what's on screen.
    if (justFinished && activeTab === 'assets' && assetsView === 'downloads') {
      listDownloadedSongs().then(setDownloads);
    }
  }, [activeDownloads, activeTab, assetsView]);

  const downloadedIds = new Set(downloads.map(s => s.videoId));
  const mergedDownloads = [
    ...activeDownloads.filter(d => !downloadedIds.has(d.song.videoId)).map(d => d.song),
    ...downloads,
  ];

  const refreshPlaylists = () => setPlaylists(getPlaylists());

  const handleCreatePlaylist = () => {
    const name = newPlaylistName.trim();
    if (!name) return;
    const playlist = createPlaylist(name);
    // If we got here from "Add to Playlist" on a song, add it straight away
    // instead of making the user create-then-add as two separate steps.
    if (addToPlaylistSong) {
      addSongToPlaylist(playlist.id, {
        videoId: addToPlaylistSong.videoId,
        title: addToPlaylistSong.title,
        artist: addToPlaylistSong.artist,
        image: addToPlaylistSong.image,
        language: addToPlaylistSong.language,
      });
    }
    refreshPlaylists();
    setNewPlaylistName('');
    setShowCreatePlaylist(false);
    setAddToPlaylistSong(null);
    setOpenPlaylist(getPlaylist(playlist.id));
  };

  const handleDeletePlaylist = (id: string) => {
    deletePlaylist(id);
    refreshPlaylists();
    setOpenPlaylist(prev => (prev?.id === id ? null : prev));
  };

  const handleAddToPlaylist = (playlistId: string) => {
    if (!addToPlaylistSong) return;
    addSongToPlaylist(playlistId, {
      videoId: addToPlaylistSong.videoId,
      title: addToPlaylistSong.title,
      artist: addToPlaylistSong.artist,
      image: addToPlaylistSong.image,
      language: addToPlaylistSong.language,
    });
    refreshPlaylists();
    setAddToPlaylistSong(null);
  };

  const handleRemoveFromOpenPlaylist = (videoId: string) => {
    if (!openPlaylist) return;
    removeSongFromPlaylist(openPlaylist.id, videoId);
    refreshPlaylists();
    setOpenPlaylist(getPlaylist(openPlaylist.id));
  };

  /* ── Audio / Player state ────────────────────────────────── */
  const [playerSong, setPlayerSong] = useState<Song | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [loadingId, setLoadingId] = useState<string | null>(null);
  const [currentTime, setCurrentTime] = useState(0);
  const [audioDuration, setAudioDuration] = useState(0);
  const [playerExpanded, setPlayerExpanded] = useState(false);
  const [queue, setQueue] = useState<Song[]>([]);
  const [queueIndex, setQueueIndex] = useState(0);

  // Tell BottomNav to hide when player goes full-screen
  useEffect(() => {
    window.dispatchEvent(new CustomEvent('player-expanded', { detail: playerExpanded }));
  }, [playerExpanded]);

  // Tell BottomNav whether a song is actively playing (for soundwave animation)
  useEffect(() => {
    window.dispatchEvent(new CustomEvent('player-playing', { detail: isPlaying }));
  }, [isPlaying]);

  const audioRef = useRef<HTMLAudioElement | null>(null);
  // Stable ref so onended always has the latest playNext without stale closure
  const playNextRef = useRef<() => void>(() => {});

  /* ── Load "Trending Now" shelf ────────────────────────────── */
  useEffect(() => {
    if (trendingCache.current[lang]) {
      setTrending(trendingCache.current[lang]);
      setTrendingLoading(false);
      return;
    }
    setTrendingLoading(true);
    setTrending([]);
    fetch(`/api/audio/songs/${lang}`)
      .then(r => r.json())
      .then((data: { id: string; title: string; thumbnail: string; channelTitle: string }[]) => {
        if (Array.isArray(data)) {
          const songs = data.map(s => mapApi(s, lang));
          trendingCache.current[lang] = songs;
          setTrending(songs);
        }
      })
      .catch(() => {})
      .finally(() => setTrendingLoading(false));
  }, [lang]);

  /* ── Load the Hymns Mix / Non-Stop Worship shelves ────────── */
  useEffect(() => {
    for (const shelf of SHELVES) {
      const cacheKey = `${shelf.key}:${lang}`;
      if (shelfCache.current[cacheKey]) {
        setShelves(prev => ({ ...prev, [shelf.key]: shelfCache.current[cacheKey] }));
        continue;
      }
      setShelvesLoading(prev => ({ ...prev, [shelf.key]: true }));
      fetch(`/api/audio/category/${shelf.key}/${lang}`)
        .then(r => r.json())
        .then((data: { id: string; title: string; thumbnail: string; channelTitle: string }[]) => {
          if (Array.isArray(data)) {
            const songs = data.map(s => mapApi(s, lang));
            shelfCache.current[cacheKey] = songs;
            setShelves(prev => ({ ...prev, [shelf.key]: songs }));
          }
        })
        .catch(() => {})
        .finally(() => setShelvesLoading(prev => ({ ...prev, [shelf.key]: false })));
    }
  }, [lang]);

  /* ── Debounced search ────────────────────────────────────── */
  useEffect(() => {
    if (searchTimer.current) clearTimeout(searchTimer.current);
    const q = searchQuery.trim();
    if (!q) { setSearchResults([]); setSearching(false); return; }
    setSearching(true);
    searchTimer.current = setTimeout(() => {
      fetch(`/api/audio/search?q=${encodeURIComponent(q)}&language=${lang}`)
        .then(r => r.json())
        .then((data: { id: string; title: string; thumbnail: string; channelTitle: string }[]) => {
          if (Array.isArray(data)) setSearchResults(data.map(s => mapApi(s, lang)));
        })
        .catch(() => setSearchResults([]))
        .finally(() => setSearching(false));
    }, 400);
  }, [searchQuery, lang]);

  /* ── Favorites ───────────────────────────────────────────── */
  const isFav = useCallback((videoId: string) => favorites.some(f => f.videoId === videoId), [favorites]);
  const toggleFav = useCallback((song: Song) => {
    setFavorites(prev => {
      const next = prev.some(f => f.videoId === song.videoId)
        ? prev.filter(f => f.videoId !== song.videoId)
        : [song, ...prev];
      saveFavs(next);
      return next;
    });
  }, []);
  const toggleFavById = useCallback((videoId: string) => {
    const song = trending.find(s => s.videoId === videoId)
      || favorites.find(s => s.videoId === videoId)
      || searchResults.find(s => s.videoId === videoId)
      || playerSong as Song | undefined;
    if (song) toggleFav(song);
  }, [trending, favorites, searchResults, playerSong, toggleFav]);

  /* ── Core audio helpers ──────────────────────────────────── */
  const _loadAndPlay = useCallback(async (song: Song) => {
    // Persist so Home screen can show the last played song
    try { localStorage.setItem(LAST_PLAYED_KEY, JSON.stringify(song)); } catch {}
    setLoadingId(song.videoId);
    setCurrentTime(0);
    setAudioDuration(0);
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
      audioRef.current?.pause();
      const audio = new Audio(url);
      audio.ontimeupdate = () => setCurrentTime(audio.currentTime);
      audio.ondurationchange = () => setAudioDuration(isFinite(audio.duration) ? audio.duration : 0);
      audio.onended = () => { setIsPlaying(false); playNextRef.current(); };
      audio.onerror = () => { setIsPlaying(false); setLoadingId(null); };
      audioRef.current = audio;
      await audio.play();
      setIsPlaying(true);
    } catch (err) {
      // Was a bare catch with nothing surfaced anywhere - "stuck on play
      // button" had no way to tell whether the URL fetch failed, the audio
      // element failed to load, or .play() itself was rejected (e.g.
      // Android WebView's autoplay-gesture policy).
      console.error('[Songs] _loadAndPlay failed for', song.videoId, err);
      setIsPlaying(false);
    } finally {
      setLoadingId(null);
    }
  }, []);

  /* ── Public player actions ───────────────────────────────── */
  const startSong = useCallback((song: Song, list: Song[] = []) => {
    // Same song already loaded → just expand / resume
    if (playerSong?.videoId === song.videoId) {
      setPlayerExpanded(true);
      if (audioRef.current && !isPlaying) {
        audioRef.current.play().then(() => setIsPlaying(true)).catch(err => {
          console.error('[Songs] resume play() failed for', song.videoId, err);
        });
      }
      return;
    }
    setPlayerSong(song);
    setPlayerExpanded(true);
    const q = list.length > 0 ? list : [song];
    setQueue(q);
    const idx = q.findIndex(s => s.videoId === song.videoId);
    setQueueIndex(idx >= 0 ? idx : 0);
    _loadAndPlay(song);
  }, [playerSong, isPlaying, _loadAndPlay]);

  const togglePlay = useCallback(() => {
    if (!audioRef.current) return;
    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
    } else {
      audioRef.current.play().then(() => setIsPlaying(true)).catch(err => {
        console.error('[Songs] togglePlay play() failed', err);
      });
    }
  }, [isPlaying]);

  const playNext = useCallback(() => {
    if (queue.length < 2) return;
    const nextIdx = (queueIndex + 1) % queue.length;
    setQueueIndex(nextIdx);
    const song = queue[nextIdx];
    setPlayerSong(song);
    _loadAndPlay(song);
  }, [queue, queueIndex, _loadAndPlay]);

  const playPrev = useCallback(() => {
    if (queue.length === 0) return;
    // Within first 3s → go to prev; otherwise restart
    if (audioRef.current && audioRef.current.currentTime > 3) {
      audioRef.current.currentTime = 0;
      return;
    }
    const prevIdx = (queueIndex - 1 + queue.length) % queue.length;
    setQueueIndex(prevIdx);
    const song = queue[prevIdx];
    setPlayerSong(song);
    _loadAndPlay(song);
  }, [queue, queueIndex, _loadAndPlay]);

  const seekTo = useCallback((frac: number) => {
    if (!audioRef.current || !audioDuration) return;
    audioRef.current.currentTime = frac * audioDuration;
    setCurrentTime(frac * audioDuration);
  }, [audioDuration]);

  const stopPlayer = useCallback(() => {
    audioRef.current?.pause();
    audioRef.current = null;
    setPlayerSong(null);
    setIsPlaying(false);
    setCurrentTime(0);
    setAudioDuration(0);
    setPlayerExpanded(false);
    setQueue([]);
    setQueueIndex(0);
  }, []);

  // Keep ref current so onended callback is never stale
  useEffect(() => { playNextRef.current = playNext; }, [playNext]);

  // Jump straight into a specific song when navigated here from Home's
  // global search (a downloaded song or a music favorite result).
  useEffect(() => {
    const state = location.state as { openSong?: Song } | null;
    if (!state?.openSong?.videoId) return;
    setPlayerSong(state.openSong);
    setPlayerExpanded(true);
    _loadAndPlay(state.openSong);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Auto-play last song when navigated here from Home's mini-player
  useEffect(() => {
    const state = location.state as { autoplay?: boolean } | null;
    if (!state?.autoplay) return;
    try {
      const raw = localStorage.getItem(LAST_PLAYED_KEY);
      if (!raw) return;
      const song = JSON.parse(raw) as Song;
      if (song?.videoId) {
        setPlayerSong(song);
        setPlayerExpanded(true);
        _loadAndPlay(song);
      }
    } catch {}
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const isSearching = searchQuery.trim().length > 0;
  const related = searchResults.slice(0, 5);
  const isCardActive = (videoId: string) => playerSong?.videoId === videoId;
  const isCardPlaying = (videoId: string) => isPlaying && playerSong?.videoId === videoId;
  const isCardLoading = (videoId: string) => loadingId === videoId;

  // Spotify-style horizontal shelf: a title row, then a horizontally
  // scrolling strip of cards instead of a fixed grid.
  const renderShelf = (title: string, songs: Song[], loading: boolean) => (
    <div className="mb-6">
      <h2 className="text-foreground font-sans text-base font-bold mb-3">{title}</h2>
      {loading ? (
        <div className="flex gap-3 overflow-x-hidden">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="flex-shrink-0 w-36 aspect-square rounded-2xl bg-muted animate-pulse" />
          ))}
        </div>
      ) : songs.length === 0 ? (
        <p className="text-muted-foreground text-center py-6 font-sans text-sm">No songs available</p>
      ) : (
        <div className="flex gap-3 overflow-x-auto scrollbar-hide pb-1 -mx-1 px-1">
          {songs.map((song, i) => (
            <motion.div
              key={song.videoId}
              initial={{ opacity: 0, x: 10 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.02 }}
              className="flex-shrink-0 w-36"
            >
              <SongCard
                song={song}
                isPlaying={isCardPlaying(song.videoId)}
                isLoading={isCardLoading(song.videoId)}
                isActive={isCardActive(song.videoId)}
                isFav={isFav(song.videoId)}
                onPlay={() => startSong(song, songs)}
                onFav={() => toggleFav(song)}
                onAddToPlaylist={() => setAddToPlaylistSong(song)}
              />
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );

  // Same songs as the "Trending" shelf, but as a full vertical grid beneath
  // the shelves so there's a way to browse past the first horizontal screenful.
  const renderGrid = (title: string, songs: Song[], loading: boolean) => (
    <div className="mb-6">
      <h2 className="text-foreground font-sans text-base font-bold mb-3">{title}</h2>
      {loading ? (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
          {[...Array(6)].map((_, i) => <div key={i} className="rounded-2xl bg-muted animate-pulse aspect-[4/5]" />)}
        </div>
      ) : songs.length === 0 ? (
        <p className="text-muted-foreground text-center py-6 font-sans text-sm">No songs available</p>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
          {songs.map((song, i) => (
            <motion.div key={song.videoId} initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} transition={{ delay: i * 0.02 }}>
              <SongCard
                song={song}
                isPlaying={isCardPlaying(song.videoId)}
                isLoading={isCardLoading(song.videoId)}
                isActive={isCardActive(song.videoId)}
                isFav={isFav(song.videoId)}
                onPlay={() => startSong(song, songs)}
                onFav={() => toggleFav(song)}
                onAddToPlaylist={() => setAddToPlaylistSong(song)}
              />
            </motion.div>
          ))}
        </div>
      )}
    </div>
  );

  return (
    <div className="min-h-full bg-background pb-44">

      {/* Header */}
      <div className="bg-gradient-to-b from-card to-background px-4 pt-12 pb-5 border-b border-border">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-foreground font-bold font-sans text-2xl mb-1">Worship Music</h1>
            <p className="text-muted-foreground font-sans text-sm">Uplift your spirit with sacred music</p>
          </div>
          {!(universalOn && musicFollowsUniversal) && (
            <motion.button
              whileTap={{ scale: 0.9 }}
              onClick={() => setShowLangPicker(true)}
              className="flex items-center gap-1.5 bg-primary/10 hover:bg-primary/20 transition-colors rounded-2xl px-3 py-2 mt-1"
            >
              <Globe size={18} className="text-primary" />
              <span className="text-primary font-sans text-xs font-semibold">{currentLang.key}</span>
            </motion.button>
          )}
        </div>
      </div>

      {/* Search bar */}
      <div className="px-4 py-4">
        <div className="relative">
          <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            type="text"
            placeholder="Search songs, artists..."
            value={searchQuery}
            onChange={e => setSearchQuery(e.target.value)}
            onFocus={() => window.dispatchEvent(new CustomEvent('search-expanded', { detail: true }))}
            onBlur={() => window.dispatchEvent(new CustomEvent('search-expanded', { detail: false }))}
            className={`w-full bg-card rounded-2xl pl-11 py-3 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 font-sans text-sm ${
              isVoiceSearchSupported() ? (searchQuery ? 'pr-20' : 'pr-11') : 'pr-10'
            }`}
          />
          <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-2">
            {isVoiceSearchSupported() && (
              <motion.button
                whileTap={{ scale: 0.9 }}
                onClick={startVoiceSearch}
                title="Search by voice"
                className="flex-shrink-0"
              >
                {isListening
                  ? <motion.div animate={{ scale: [1, 1.15, 1] }} transition={{ duration: 0.8, repeat: Infinity }}>
                      <Mic size={16} className="text-destructive" />
                    </motion.div>
                  : <Mic size={16} className="text-muted-foreground" />
                }
              </motion.button>
            )}
            {searchQuery && (
              <button onClick={() => setSearchQuery('')} className="flex-shrink-0">
                <X size={16} className="text-muted-foreground" />
              </button>
            )}
          </div>
        </div>
      </div>

      {/* ── SEARCH MODE ── */}
      {isSearching && (
        <div className="px-4 space-y-5">
          {searching && (
            <div className="flex items-center justify-center py-8">
              <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
            </div>
          )}

          {!searching && searchResults.length > 0 && (
            <>
              <div>
                <p className="text-muted-foreground font-sans text-xs font-semibold uppercase tracking-wider mb-3">Related</p>
                <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-hide -mx-4 px-4">
                  {related.map(song => (
                    <motion.div
                      key={song.videoId}
                      whileTap={{ scale: 0.96 }}
                      onClick={() => startSong(song, searchResults)}
                      className="flex-shrink-0 w-28 cursor-pointer"
                    >
                      <div className="w-28 h-28 rounded-2xl overflow-hidden bg-muted mb-2 relative">
                        {song.image
                          ? <img src={song.image} alt={song.title} className="w-full h-full object-cover" />
                          : <div className="w-full h-full flex items-center justify-center"><Music size={22} className="text-muted-foreground" /></div>
                        }
                        <div className="absolute bottom-1.5 right-1.5 w-7 h-7 rounded-full bg-white/90 flex items-center justify-center shadow">
                          {isCardLoading(song.videoId)
                            ? <div className="w-3.5 h-3.5 border-2 border-[var(--primary)] border-t-transparent rounded-full animate-spin" />
                            : isCardPlaying(song.videoId)
                              ? <Pause size={12} className="text-[var(--primary)]" fill="var(--primary)" />
                              : <Play size={12} className="text-[var(--primary)] ml-0.5" fill="var(--primary)" />
                          }
                        </div>
                      </div>
                      <p className="text-foreground font-sans text-xs font-semibold line-clamp-2 leading-tight">{song.title}</p>
                    </motion.div>
                  ))}
                </div>
              </div>

              <div>
                <p className="text-muted-foreground font-sans text-xs font-semibold uppercase tracking-wider mb-3">Results</p>
                <div className="space-y-2">
                  {searchResults.map(song => (
                    <SongRow
                      key={song.videoId}
                      song={song}
                      isPlaying={isCardPlaying(song.videoId)}
                      isLoading={isCardLoading(song.videoId)}
                      isActive={isCardActive(song.videoId)}
                      isFav={isFav(song.videoId)}
                      onPlay={() => startSong(song, searchResults)}
                      onFav={() => toggleFav(song)}
                    />
                  ))}
                </div>
              </div>
            </>
          )}

          {!searching && searchResults.length === 0 && (
            <p className="text-muted-foreground text-center py-8 font-sans text-sm">No results found</p>
          )}
        </div>
      )}

      {/* ── BROWSE MODE ── */}
      {!isSearching && (
        <div className="px-4">
          {/* Capsule tab switcher */}
          <div className="flex bg-muted rounded-full p-1 mb-5">
            {(['trending', 'assets'] as const).map(tab => {
              const isActive = activeTab === tab;
              return (
                <motion.button
                  key={tab}
                  onClick={() => setActiveTab(tab)}
                  className="relative flex-1 flex items-center justify-center gap-2 py-2.5 rounded-full font-sans text-sm font-semibold transition-colors"
                >
                  {isActive && (
                    <motion.div
                      layoutId="tabPill"
                      className="absolute inset-0 bg-[var(--primary)] rounded-full shadow-md"
                      transition={{ type: 'spring', stiffness: 400, damping: 30 }}
                    />
                  )}
                  <span className={`relative z-10 flex items-center gap-1.5 ${isActive ? 'text-primary-foreground' : 'text-muted-foreground'}`}>
                    {tab === 'trending' ? <TrendingUp size={14} /> : <Download size={14} />}
                    {tab === 'trending' ? 'Trending' : 'Assets'}
                    {tab === 'assets' && favorites.length > 0 && (
                      <span className={`text-[10px] px-1.5 py-0.5 rounded-full font-bold ${isActive ? 'bg-primary-foreground/20 text-primary-foreground' : 'bg-primary/20 text-primary'}`}>
                        {favorites.length}
                      </span>
                    )}
                  </span>
                </motion.button>
              );
            })}
          </div>

          <AnimatePresence mode="wait">
            {/* TRENDING */}
            {activeTab === 'trending' && (
              <motion.div key="trending" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }} transition={{ duration: 0.18 }}>
                {renderShelf('Trending', trending, trendingLoading)}
                {SHELVES.map(shelf => renderShelf(shelf.title, shelves[shelf.key] || [], shelvesLoading[shelf.key] ?? true))}
                {renderGrid('All Trending Songs', trending, trendingLoading)}
              </motion.div>
            )}

            {/* ASSETS */}
            {activeTab === 'assets' && (
              <motion.div key="assets" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }} transition={{ duration: 0.18 }}>
                {openPlaylist ? (
                  /* ── Open playlist's songs ── */
                  <div>
                    <div className="flex items-center gap-2 mb-4">
                      <motion.button whileTap={{ scale: 0.9 }} onClick={() => setOpenPlaylist(null)}
                        className="w-9 h-9 rounded-full bg-muted flex items-center justify-center flex-shrink-0">
                        <ChevronLeft size={18} className="text-foreground" />
                      </motion.button>
                      <div className="min-w-0 flex-1">
                        <p className="text-foreground font-sans text-sm font-semibold truncate">{openPlaylist.name}</p>
                        <p className="text-muted-foreground font-sans text-xs">
                          {openPlaylist.songs.length} {openPlaylist.songs.length === 1 ? 'song' : 'songs'}
                        </p>
                      </div>
                      <motion.button whileTap={{ scale: 0.9 }} onClick={() => handleDeletePlaylist(openPlaylist.id)}
                        className="w-9 h-9 rounded-full bg-destructive/10 flex items-center justify-center flex-shrink-0" title="Delete playlist">
                        <Trash2 size={16} className="text-destructive" />
                      </motion.button>
                    </div>

                    {openPlaylist.songs.length === 0 ? (
                      <div className="flex flex-col items-center gap-3 py-16">
                        <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center">
                          <ListMusic size={28} className="text-muted-foreground" />
                        </div>
                        <p className="text-foreground font-sans text-sm font-semibold">No songs yet</p>
                        <p className="text-muted-foreground font-sans text-xs text-center px-6">Tap the + on any song to add it here</p>
                      </div>
                    ) : (
                      <div className="space-y-3">
                        {openPlaylist.songs.map((song) => (
                          <SongRow
                            key={song.videoId}
                            song={song}
                            isPlaying={isCardPlaying(song.videoId)}
                            isLoading={isCardLoading(song.videoId)}
                            isActive={isCardActive(song.videoId)}
                            isFav={isFav(song.videoId)}
                            onPlay={() => startSong(song, openPlaylist.songs)}
                            onFav={() => toggleFav(song)}
                            showLang
                            onRemove={() => handleRemoveFromOpenPlaylist(song.videoId)}
                          />
                        ))}
                      </div>
                    )}
                  </div>
                ) : (
                  <>
                    {/* Favourites / Downloads / Playlists sub-tabs */}
                    <div className="flex gap-2 mb-4">
                      {([
                        { key: 'favorites', label: 'Favourites', icon: Heart },
                        { key: 'playlists', label: 'Playlists', icon: ListMusic },
                        { key: 'downloads', label: 'Downloads', icon: CloudDownload },
                      ] as const).map(({ key, label, icon: Icon }) => (
                        <button
                          key={key}
                          onClick={() => setAssetsView(key)}
                          className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full font-sans text-xs font-semibold transition-colors ${
                            assetsView === key ? 'bg-[var(--primary)] text-primary-foreground' : 'bg-muted text-muted-foreground'
                          }`}
                        >
                          <Icon size={12} /> {label}
                        </button>
                      ))}
                    </div>

                    {assetsView === 'favorites' && (
                      favorites.length === 0 ? (
                        <div className="flex flex-col items-center gap-3 py-16">
                          <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center">
                            <Heart size={28} className="text-muted-foreground" />
                          </div>
                          <p className="text-foreground font-sans text-sm font-semibold">No saved songs yet</p>
                          <p className="text-muted-foreground font-sans text-xs text-center px-6">Tap the ♥ on any trending song to save it here</p>
                          <motion.button whileTap={{ scale: 0.96 }} onClick={() => setActiveTab('trending')}
                            className="mt-2 px-5 py-2.5 bg-[var(--primary)] text-primary-foreground rounded-full font-sans text-sm font-semibold">
                            Browse Music
                          </motion.button>
                        </div>
                      ) : (
                        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
                          {favorites.map((song, i) => (
                            <motion.div key={song.videoId} initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} transition={{ delay: i * 0.03 }}>
                              <SongCard
                                song={song}
                                isPlaying={isCardPlaying(song.videoId)}
                                isLoading={isCardLoading(song.videoId)}
                                isActive={isCardActive(song.videoId)}
                                isFav={true}
                                onPlay={() => startSong(song, favorites)}
                                onFav={() => toggleFav(song)}
                                showLang
                                showDownload
                                onAddToPlaylist={() => setAddToPlaylistSong(song)}
                              />
                            </motion.div>
                          ))}
                        </div>
                      )
                    )}

                    {assetsView === 'downloads' && (
                      mergedDownloads.length === 0 ? (
                        <div className="flex flex-col items-center gap-3 py-16">
                          <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center">
                            <CloudDownload size={28} className="text-muted-foreground" />
                          </div>
                          <p className="text-foreground font-sans text-sm font-semibold">No downloads yet</p>
                          <p className="text-muted-foreground font-sans text-xs text-center px-6">Tap the download icon on any song to save it for offline listening</p>
                        </div>
                      ) : (
                        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
                          {mergedDownloads.map((song, i) => (
                            <motion.div key={song.videoId} initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} transition={{ delay: i * 0.03 }}>
                              <SongCard
                                song={song}
                                isPlaying={isCardPlaying(song.videoId)}
                                isLoading={isCardLoading(song.videoId)}
                                isActive={isCardActive(song.videoId)}
                                isFav={isFav(song.videoId)}
                                onPlay={() => startSong(song, mergedDownloads)}
                                onFav={() => toggleFav(song)}
                                showLang
                                showDownload
                                onAddToPlaylist={() => setAddToPlaylistSong(song)}
                              />
                            </motion.div>
                          ))}
                        </div>
                      )
                    )}

                    {assetsView === 'playlists' && (
                      <div>
                        <motion.button whileTap={{ scale: 0.97 }} onClick={() => setShowCreatePlaylist(true)}
                          className="w-full flex items-center justify-center gap-2.5 py-3.5 mb-4 rounded-2xl text-white font-sans text-sm font-bold shadow-lg shadow-[var(--primary)]/30 transition-transform"
                          style={{ background: 'linear-gradient(135deg, #2c2c2c 0%, #1a1a1a 100%)' }}>
                          <div className="w-6 h-6 rounded-full bg-white/15 flex items-center justify-center">
                            <Plus size={14} />
                          </div>
                          New Playlist
                        </motion.button>

                        {playlists.length === 0 ? (
                          <div className="flex flex-col items-center gap-3 py-12">
                            <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center">
                              <ListMusic size={28} className="text-muted-foreground" />
                            </div>
                            <p className="text-foreground font-sans text-sm font-semibold">No playlists yet</p>
                            <p className="text-muted-foreground font-sans text-xs text-center px-6">Create one, then tap the + on any song to add it</p>
                          </div>
                        ) : (
                          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
                            {playlists.map((pl, i) => (
                              <motion.button
                                key={pl.id}
                                initial={{ opacity: 0, scale: 0.95 }} animate={{ opacity: 1, scale: 1 }} transition={{ delay: i * 0.03 }}
                                whileTap={{ scale: 0.97 }}
                                onClick={() => setOpenPlaylist(pl)}
                                className="bg-card rounded-2xl border border-border shadow-sm overflow-hidden text-left"
                              >
                                <div className="w-full aspect-video bg-muted flex items-center justify-center">
                                  {pl.songs[0]?.image
                                    ? <img src={pl.songs[0].image} alt={pl.name} className="w-full h-full object-cover" />
                                    : <ListMusic size={24} className="text-muted-foreground" />
                                  }
                                </div>
                                <div className="p-2">
                                  <p className="text-foreground font-sans text-xs font-semibold line-clamp-1">{pl.name}</p>
                                  <p className="text-muted-foreground font-sans text-[10px]">
                                    {pl.songs.length} {pl.songs.length === 1 ? 'song' : 'songs'}
                                  </p>
                                </div>
                              </motion.button>
                            ))}
                          </div>
                        )}
                      </div>
                    )}
                  </>
                )}
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      )}

      {/* Language Picker Bottom Sheet */}
      <AnimatePresence>
        {showLangPicker && (
          <>
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setShowLangPicker(false)} className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40" />
            <motion.div
              initial={{ y: '100%' }} animate={{ y: 0 }} exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="fixed bottom-0 left-0 right-0 bg-card rounded-t-[28px] z-50 shadow-2xl"
            >
              <div className="flex items-center justify-between px-5 pt-5 pb-2">
                <div>
                  <h2 className="text-foreground font-semibold font-sans text-base">Music Language</h2>
                  <p className="text-muted-foreground font-sans text-xs mt-0.5">Choose your listening language</p>
                </div>
                <motion.button whileTap={{ scale: 0.9 }} onClick={() => setShowLangPicker(false)}
                  className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
                  <X size={16} className="text-muted-foreground" />
                </motion.button>
              </div>
              <div className="w-12 h-1 bg-muted rounded-full mx-auto mb-4" />
              <div className="px-4 pb-8 space-y-2 overflow-y-auto max-h-[60vh]">
                {LANGUAGES.map(l => {
                  const selected = l.key === lang;
                  return (
                    <motion.button key={l.key} whileTap={{ scale: 0.98 }}
                      onClick={() => {
                        setLang(l.key);
                        setMusicLanguageKey(l.key);
                        // Only cascade if Music hasn't opted out of Universal Language —
                        // this button is reachable in that opted-out state too, and there
                        // it should behave as a fully independent picker.
                        if (isUniversalLanguageEnabled() && musicFollowsUniversal) {
                          const code = musicKeyToCode(l.key);
                          const versionId = BIBLE_VERSIONS.find(v => v.lang === code)?.id ?? BIBLE_VERSIONS[0].id;
                          applyUniversalLanguage(code, versionId);
                        }
                        setShowLangPicker(false);
                        setSearchQuery('');
                      }}
                      className={`w-full flex items-center gap-4 p-4 rounded-2xl transition-all ${selected ? 'bg-primary/10 border border-primary/30' : 'bg-muted/40 border border-transparent hover:bg-muted'}`}
                    >
                      <div className="flex-1 text-left">
                        <p className={`font-semibold font-sans text-sm ${selected ? 'text-primary' : 'text-foreground'}`}>{l.label}</p>
                        <p className="text-muted-foreground font-sans text-xs">{l.sublabel}</p>
                      </div>
                      {selected && <Check size={18} className="text-primary flex-shrink-0" />}
                    </motion.button>
                  );
                })}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Add to Playlist Bottom Sheet */}
      <AnimatePresence>
        {addToPlaylistSong && (
          <>
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setAddToPlaylistSong(null)} className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40" />
            <motion.div
              initial={{ y: '100%' }} animate={{ y: 0 }} exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="fixed bottom-0 left-0 right-0 bg-card rounded-t-[28px] z-50 shadow-2xl"
            >
              <div className="flex items-center justify-between px-5 pt-5 pb-2">
                <div className="min-w-0">
                  <h2 className="text-foreground font-semibold font-sans text-base">Add to Playlist</h2>
                  <p className="text-muted-foreground font-sans text-xs mt-0.5 truncate">{addToPlaylistSong.title}</p>
                </div>
                <motion.button whileTap={{ scale: 0.9 }} onClick={() => setAddToPlaylistSong(null)}
                  className="w-8 h-8 rounded-full bg-muted flex items-center justify-center flex-shrink-0">
                  <X size={16} className="text-muted-foreground" />
                </motion.button>
              </div>
              <div className="w-12 h-1 bg-muted rounded-full mx-auto mb-4" />
              <div className="px-4 pb-8 space-y-2 max-h-[50vh] overflow-y-auto">
                <motion.button whileTap={{ scale: 0.98 }}
                  onClick={() => { setShowCreatePlaylist(true); }}
                  className="w-full flex items-center gap-3 p-4 rounded-2xl bg-muted/40 border border-transparent hover:bg-muted transition-all"
                >
                  <Plus size={18} className="text-primary" />
                  <span className="font-semibold font-sans text-sm text-foreground">New Playlist</span>
                </motion.button>
                {playlists.map(pl => {
                  const already = pl.songs.some(s => s.videoId === addToPlaylistSong.videoId);
                  return (
                    <motion.button key={pl.id} whileTap={{ scale: already ? 1 : 0.98 }}
                      onClick={() => !already && handleAddToPlaylist(pl.id)}
                      disabled={already}
                      className={`w-full flex items-center gap-3 p-4 rounded-2xl transition-all ${already ? 'bg-primary/5' : 'bg-muted/40 border border-transparent hover:bg-muted'}`}
                    >
                      <ListMusic size={18} className="text-muted-foreground flex-shrink-0" />
                      <div className="flex-1 text-left min-w-0">
                        <p className="font-semibold font-sans text-sm text-foreground truncate">{pl.name}</p>
                        <p className="text-muted-foreground font-sans text-xs">{pl.songs.length} songs</p>
                      </div>
                      {already && <Check size={16} className="text-primary flex-shrink-0" />}
                    </motion.button>
                  );
                })}
                {playlists.length === 0 && (
                  <p className="text-muted-foreground font-sans text-xs text-center py-4">No playlists yet — create one above.</p>
                )}
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Create Playlist Bottom Sheet */}
      <AnimatePresence>
        {showCreatePlaylist && (
          <>
            <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
              onClick={() => setShowCreatePlaylist(false)} className="fixed inset-0 bg-black/50 backdrop-blur-sm z-[60]" />
            <motion.div
              initial={{ y: '100%' }} animate={{ y: 0 }} exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="fixed bottom-0 left-0 right-0 bg-card rounded-t-[28px] z-[70] shadow-2xl p-6"
            >
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-foreground font-semibold font-sans text-base">New Playlist</h2>
                <motion.button whileTap={{ scale: 0.9 }} onClick={() => setShowCreatePlaylist(false)}
                  className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
                  <X size={16} className="text-muted-foreground" />
                </motion.button>
              </div>
              <input
                autoFocus
                value={newPlaylistName}
                onChange={e => setNewPlaylistName(e.target.value)}
                onKeyDown={e => { if (e.key === 'Enter') handleCreatePlaylist(); }}
                placeholder="Playlist name"
                className="w-full bg-muted/40 border border-border rounded-xl px-4 py-3 text-sm font-sans text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/20 mb-4"
              />
              <motion.button whileTap={{ scale: 0.98 }} onClick={handleCreatePlaylist} disabled={!newPlaylistName.trim()}
                className="w-full bg-primary text-primary-foreground rounded-2xl py-4 font-sans font-semibold text-base shadow-md shadow-primary/20 disabled:opacity-50"
              >
                Create
              </motion.button>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Music Player */}
      <AnimatePresence>
        {playerSong && (
          <MiniPlayer
            song={toPlayerSong(playerSong)}
            isPlaying={isPlaying}
            isLoading={loadingId === playerSong.videoId}
            currentTime={currentTime}
            duration={audioDuration}
            expanded={playerExpanded}
            isFav={isFav(playerSong.videoId)}
            queue={queue.map(toPlayerSong)}
            queueIndex={queueIndex}
            onToggleExpand={() => setPlayerExpanded(e => !e)}
            onTogglePlay={togglePlay}
            onClose={stopPlayer}
            onNext={queue.length > 1 ? playNext : undefined}
            onPrev={queue.length > 1 ? playPrev : undefined}
            onSeek={seekTo}
            onToggleFav={() => toggleFavById(playerSong.videoId)}
            onAddToPlaylist={() => setAddToPlaylistSong(playerSong)}
            onDownload={async () => {
              // Was firing a raw browser file download straight from the
              // stream endpoint — bypassed auth, quota, IndexedDB storage,
              // and the chunked-download retry logic, so it never showed up
              // in Assets ▸ Downloads and wasn't resilient to Cloudflare's
              // proxy timeout on a real deploy. Route through the same
              // manager every other download button in the app uses.
              const outcome = await startSongDownload(playerSong);
              if (outcome === 'not_authenticated') {
                if (window.confirm('Sign in to download songs for offline listening. Go to the sign-in screen now?')) {
                  navigate('/login');
                }
              } else if (outcome === 'limit_reached') {
                window.alert(getLastLimitMessage());
              }
            }}
          />
        )}
      </AnimatePresence>
    </div>
  );
}

/* ── SongDownloadButton — per-item offline download, Netflix-style ──── */
function SongDownloadButton({ song }: { song: Song }) {
  const navigate = useNavigate();
  const snapshot = useSyncExternalStore(subscribe, () => getSnapshot(song.videoId));
  const [downloaded, setDownloaded] = useState(false);
  const isDownloading = snapshot.status === 'downloading';
  const isQueued = snapshot.status === 'queued';

  useEffect(() => {
    if (isDownloading || isQueued) return;
    isSongDownloaded(song.videoId).then(setDownloaded);
  }, [isDownloading, isQueued, song.videoId]);

  if (isQueued) {
    // Only 3 downloads run at once (see musicDownloadManager.ts) — this one
    // is waiting for a slot rather than stuck or ignored.
    return (
      <motion.button
        whileTap={{ scale: 0.85 }}
        onClick={e => { e.stopPropagation(); cancelSongDownload(song.videoId); }}
        className="flex-shrink-0 mt-0.5"
        title="Queued — waiting for a download slot. Tap to cancel."
      >
        <Clock size={13} className="text-muted-foreground" />
      </motion.button>
    );
  }

  if (isDownloading) {
    // YouTube's CDN throttles audio delivery to ~30 KB/s regardless of our
    // server or client (verified directly against the CDN) — a multi-minute
    // download is normal, not stuck. A bare spinner with the % hidden in a
    // tooltip looked frozen and made people give up before it finished, so
    // the percentage is now visible on the button itself.
    const pct = snapshot.progress.total > 0
      ? Math.round((snapshot.progress.loaded / snapshot.progress.total) * 100)
      : null;
    return (
      <motion.button
        whileTap={{ scale: 0.85 }}
        onClick={e => { e.stopPropagation(); cancelSongDownload(song.videoId); }}
        className="flex-shrink-0 mt-0.5 flex items-center gap-1"
        title="Downloading — this can take a few minutes on slower connections. Tap to cancel."
      >
        <div className="relative w-3.5 h-3.5 flex-shrink-0">
          <div className="absolute inset-0 border-2 border-muted-foreground/30 border-t-primary rounded-full animate-spin" />
        </div>
        {pct != null && (
          <span className="text-primary font-sans text-[9px] font-bold tabular-nums">{pct}%</span>
        )}
      </motion.button>
    );
  }

  if (downloaded) {
    return (
      <motion.button
        whileTap={{ scale: 0.85 }}
        onClick={e => {
          e.stopPropagation();
          removeSongOffline(song.videoId).then(() => setDownloaded(false));
          // Frees the account-level quota slot too — best-effort, doesn't
          // block the local removal if the request fails.
          apiFetch(`/api/v1/users/me/music-downloads/${song.videoId}`, { method: 'DELETE' }).catch(() => {});
        }}
        className="flex-shrink-0 mt-0.5"
        title="Downloaded — tap to remove"
      >
        <Check size={13} className="text-primary" />
      </motion.button>
    );
  }

  return (
    <motion.button
      whileTap={{ scale: 0.85 }}
      onClick={async e => {
        e.stopPropagation();
        const outcome = await startSongDownload(song);
        if (outcome === 'not_authenticated') {
          if (window.confirm('Sign in to download songs for offline listening. Go to the sign-in screen now?')) {
            navigate('/login');
          }
        } else if (outcome === 'limit_reached') {
          window.alert(getLastLimitMessage());
        }
      }}
      className="flex-shrink-0 mt-0.5"
      title="Download for offline"
    >
      <CloudDownload size={13} className="text-muted-foreground" />
    </motion.button>
  );
}

/* ── SongCard ──────────────────────────────────────────────── */
function SongCard({
  song, isPlaying, isLoading, isActive, isFav, onPlay, onFav, showLang = false, showDownload = false, onAddToPlaylist,
}: {
  song: Song; isPlaying: boolean; isLoading: boolean; isActive: boolean;
  isFav: boolean; onPlay: () => void; onFav: () => void; showLang?: boolean; showDownload?: boolean;
  onAddToPlaylist?: () => void;
}) {
  return (
    <motion.div
      whileTap={{ scale: 0.97 }}
      onClick={onPlay}
      className={`bg-card rounded-2xl border overflow-hidden shadow-sm cursor-pointer transition-colors ${isActive ? 'border-primary/40 shadow-primary/10 shadow-md' : 'border-border'}`}
    >
      <div className="w-full aspect-video relative bg-muted">
        {song.image
          ? <img src={song.image} alt={song.title} className="w-full h-full object-cover" />
          : <div className="w-full h-full flex items-center justify-center"><Music size={20} className="text-muted-foreground" /></div>
        }
        <div className="absolute bottom-1.5 right-1.5 w-8 h-8 rounded-full bg-[var(--primary)]/90 flex items-center justify-center shadow-md">
          {isLoading
            ? <div className="w-3.5 h-3.5 border-2 border-primary-foreground border-t-transparent rounded-full animate-spin" />
            : isPlaying
              ? <Pause size={13} className="text-primary-foreground" fill="currentColor" />
              : <Play size={13} className="text-primary-foreground ml-0.5" fill="currentColor" />
          }
        </div>
      </div>
      <div className="p-2 flex items-start justify-between gap-1">
        <div className="min-w-0 flex-1">
          <p className="text-foreground font-sans text-xs font-semibold line-clamp-1 leading-snug">{song.title}</p>
          <p className="text-muted-foreground font-sans text-[10px] line-clamp-1">{showLang ? song.language : song.artist}</p>
        </div>
        <div className="flex items-center gap-2 flex-shrink-0">
          {showDownload && <SongDownloadButton song={song} />}
          {onAddToPlaylist && (
            <motion.button
              whileTap={{ scale: 0.85 }}
              onClick={e => { e.stopPropagation(); onAddToPlaylist(); }}
              className="mt-0.5"
              title="Add to playlist"
            >
              <Plus size={13} className="text-muted-foreground" />
            </motion.button>
          )}
          <motion.button
            whileTap={{ scale: 0.85 }}
            onClick={e => { e.stopPropagation(); onFav(); }}
            className="mt-0.5"
          >
            <Heart size={13} className={isFav ? 'text-red-400 fill-red-400' : 'text-muted-foreground'} />
          </motion.button>
        </div>
      </div>
    </motion.div>
  );
}

/* ── SongRow ───────────────────────────────────────────────── */
function SongRow({
  song, isPlaying, isLoading, isActive, isFav, onPlay, onFav, showLang = false, onRemove,
}: {
  song: Song; isPlaying: boolean; isLoading: boolean; isActive: boolean;
  isFav: boolean; onPlay: () => void; onFav: () => void; showLang?: boolean;
  onRemove?: () => void;
}) {
  return (
    <motion.div
      whileTap={{ scale: 0.98 }}
      onClick={onPlay}
      className={`bg-card rounded-2xl p-3 flex items-center gap-3 border shadow-sm cursor-pointer transition-colors ${isActive ? 'border-primary/40' : 'border-border'}`}
    >
      <div className="w-12 h-12 rounded-xl overflow-hidden bg-muted flex-shrink-0">
        {song.image
          ? <img src={song.image} alt={song.title} className="w-full h-full object-cover" />
          : <div className="w-full h-full flex items-center justify-center"><Music size={18} className="text-muted-foreground" /></div>
        }
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-foreground font-sans text-sm font-semibold truncate">{song.title}</p>
        <p className="text-muted-foreground font-sans text-xs truncate">{song.artist}{showLang ? ` · ${song.language}` : ''}</p>
      </div>
      <div className="flex items-center gap-1.5" onClick={e => e.stopPropagation()}>
        {onRemove && (
          <motion.button whileTap={{ scale: 0.88 }} onClick={onRemove}
            className="w-9 h-9 rounded-full bg-destructive/10 flex items-center justify-center" title="Remove from playlist">
            <Trash2 size={15} className="text-destructive" />
          </motion.button>
        )}
        <motion.button whileTap={{ scale: 0.88 }} onClick={onFav}
          className="w-9 h-9 rounded-full bg-muted flex items-center justify-center">
          <Heart size={16} className={isFav ? 'text-red-400 fill-red-400' : 'text-muted-foreground'} />
        </motion.button>
        <motion.button whileTap={{ scale: 0.88 }} onClick={onPlay}
          className="w-9 h-9 rounded-full bg-[var(--primary)] flex items-center justify-center shadow-md">
          {isLoading
            ? <div className="w-3.5 h-3.5 border-2 border-primary-foreground border-t-transparent rounded-full animate-spin" />
            : isPlaying
              ? <Pause size={14} className="text-primary-foreground" fill="currentColor" />
              : <Play size={14} className="text-primary-foreground ml-0.5" fill="currentColor" />
          }
        </motion.button>
      </div>
    </motion.div>
  );
}
