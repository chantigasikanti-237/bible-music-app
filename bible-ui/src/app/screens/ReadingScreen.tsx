import { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate, useLocation } from 'react-router';
import { Volume2, VolumeX, SlidersHorizontal, Minus, Plus, ChevronLeft, ChevronRight, Copy, Share2, Bookmark, BookmarkCheck, NotebookPen, X, Check } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { PageContainer, AppBar } from '../components/BibleSystem';
import { getBibleVersionId, setBibleVersionId, getToken } from '../lib/api';
import { getChapterOffline, getAudioBlobUrlOffline, saveChapterOffline } from '../lib/offlineStore';
import { addBookmarkOffline, listBookmarkedVerseNumbersOffline } from '../lib/offlineBookmarks';
import { syncBookmarks } from '../lib/bookmarkSync';

interface Verse {
  number: number;
  text: string;
}

interface ChapterData {
  bookName: string;
  chapterNumber: number;
  verses: Verse[];
  audio: { url: string | null; provider: string | null };
}

const VERSION_LABELS: Record<number, { label: string; lang: string }> = {
  111:  { label: 'English (KJV)',       lang: 'en' },
  1895: { label: 'Telugu IRV',          lang: 'te' },
  1980: { label: 'Hindi IRV',           lang: 'hi' },
  1899: { label: 'Tamil IRV',           lang: 'ta' },
  1912: { label: 'Malayalam IRV',       lang: 'ml' },
  1898: { label: 'Kannada IRV',         lang: 'kn' },
  1692: { label: 'Kannada CL',          lang: 'kn' },
  1910: { label: 'Marathi IRV',         lang: 'mr' },
  1884: { label: 'Punjabi IRV',         lang: 'pa' },
  1979: { label: 'Assamese IRV',        lang: 'as' },
  155:  { label: 'Bengali',             lang: 'bn' },
  1681: { label: 'Bengali OV',          lang: 'bn' },
  1690: { label: 'Bengali CL',          lang: 'bn' },
  1883: { label: 'Bengali IRV',         lang: 'bn' },
  1711: { label: 'Nepali Saral',        lang: 'ne' },
  722:  { label: 'Sindhi CL',           lang: 'sd' },
  1866: { label: 'Konkani NT',          lang: 'kok' },
};

export function ReadingScreen() {
  const { book, chapter } = useParams<{ book: string; chapter: string }>();
  const navigate = useNavigate();
  const location = useLocation();
  const [verses, setVerses] = useState<Verse[]>([]);
  const [bookName, setBookName] = useState(book || '');
  const [chapterCount, setChapterCount] = useState(0);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [showNoAudioNotice, setShowNoAudioNotice] = useState(false);
  const [loading, setLoading] = useState(true);
  const [highlightedVerse, setHighlightedVerse] = useState<number | null>(null);
  const [fontSize, setFontSize] = useState(18);
  const [showPanel, setShowPanel] = useState(false);
  const [isPlaying, setIsPlaying] = useState(false);
  const [verseMenu, setVerseMenu] = useState<{ verse: Verse; y: number } | null>(null);
  const [savedVerses, setSavedVerses] = useState<Record<number, 'idle' | 'saving' | 'saved' | 'error'>>({});
  const [noteVerse, setNoteVerse] = useState<number | null>(null);
  const [noteText, setNoteText] = useState('');
  const [noteSaving, setNoteSaving] = useState(false);
  const [showVersePicker, setShowVersePicker] = useState(false);
  const [showBookList, setShowBookList] = useState(false);
  const [bookList, setBookList] = useState<{ id: string; title: string }[]>([]);
  const [immersive, setImmersive] = useState(false);
  const [unavailable, setUnavailable] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const versionId = getBibleVersionId();
  const versionInfo = VERSION_LABELS[versionId] ?? { label: 'English (KJV)', lang: 'en' };
  const isEnglish = versionId === 111;
  const prevVersionId = Number(localStorage.getItem('prev_bible_version_id') || '0');
  const prevVersionInfo = VERSION_LABELS[prevVersionId];
  const chapterNum = Number(chapter);

  const increaseFontSize = () => setFontSize(s => Math.min(s + 2, 28));
  const decreaseFontSize = () => setFontSize(s => Math.max(s - 2, 14));

  const switchToEnglish = () => {
    localStorage.setItem('prev_bible_version_id', String(versionId));
    setBibleVersionId(111);
    setShowPanel(false);
    window.location.reload();
  };

  const switchBack = () => {
    setBibleVersionId(prevVersionId);
    localStorage.removeItem('prev_bible_version_id');
    setShowPanel(false);
    window.location.reload();
  };

  const goToPrev = () => { if (chapterNum > 1) navigate(`/bible/${book}/${chapterNum - 1}`); };
  const goToNext = () => { if (chapterNum < chapterCount || chapterCount === 0) navigate(`/bible/${book}/${chapterNum + 1}`); };

  // Reset book list cache when version/language changes
  useEffect(() => { setBookList([]); }, [versionId]);

  // Pre-load which verses in this chapter are already bookmarked, so the
  // Save button correctly shows "Saved" instead of resetting to "Save" every
  // time you reopen a verse you'd already saved earlier. Replaces the whole
  // map (not merges) so a previous chapter's saved verse numbers don't leak
  // into this one, since verse numbers repeat across chapters.
  useEffect(() => {
    if (!book || !getToken()) { setSavedVerses({}); return; }
    listBookmarkedVerseNumbersOffline(versionId, book, chapterNum).then((verseNumbers) => {
      const matches: Record<number, 'saved'> = {};
      verseNumbers.forEach((n) => { matches[n] = 'saved'; });
      setSavedVerses(matches);
    });
  }, [book, chapterNum, versionId]);

  // Jumping here from a parsed reference like "genesis 7:16" passes the
  // target verse via nav state — scroll to it and highlight it once the
  // chapter has actually loaded. Guarded so it only fires once per landing,
  // not on every unrelated re-render while this chapter stays open.
  const jumpedToVerseRef = useRef<number | null>(null);
  useEffect(() => {
    const targetVerse = (location.state as { verseNumber?: number } | null)?.verseNumber;
    if (!targetVerse || loading || verses.length === 0) return;
    if (jumpedToVerseRef.current === targetVerse) return;
    jumpedToVerseRef.current = targetVerse;

    const timer = setTimeout(() => {
      setHighlightedVerse(targetVerse);
      document.getElementById(`verse-${targetVerse}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }, 80);
    return () => clearTimeout(timer);
  }, [location.state, loading, verses]);

  // Fetch chapter count + localized book name once per book/version
  useEffect(() => {
    if (!book) return;
    fetch(`/api/v1/bibles/${versionId}/books/${book}/chapters`)
      .then(r => r.json())
      .then((data: { success: boolean; data: unknown[] }) => {
        if (data.success && Array.isArray(data.data)) setChapterCount(data.data.length);
      })
      .catch(() => {});

    fetch(`/api/v1/bibles/${versionId}/books?lang=${versionInfo.lang}`)
      .then(r => r.json())
      .then((data: { success: boolean; data: { id: string; title: string }[] }) => {
        if (data.success && Array.isArray(data.data)) {
          const found = data.data.find(b => b.id.toUpperCase() === book.toUpperCase());
          if (found?.title) setBookName(found.title);
        }
      })
      .catch(() => {});
  }, [book, versionId]);

  // Fetch chapter content — offline cache first, network fallback.
  useEffect(() => {
    if (!book || !chapter) return;
    setLoading(true);
    setHighlightedVerse(null);
    setVerseMenu(null);
    setIsPlaying(false);
    setUnavailable(false);
    audioRef.current?.pause();
    audioRef.current = null;

    let cancelled = false;
    const chapterNum = Number(chapter);

    const resolveAudio = async () => {
      const offlineAudioUrl = await getAudioBlobUrlOffline(versionId, book, chapterNum);
      if (!cancelled) setAudioUrl(offlineAudioUrl);
      return offlineAudioUrl;
    };

    (async () => {
      const cached = await getChapterOffline(versionId, book, chapterNum);
      if (cached) {
        if (cancelled) return;
        setVerses(cached.verses);
        setBookName(cached.bookName);
        const offlineAudioUrl = await resolveAudio();
        if (!cancelled && !offlineAudioUrl) {
          // No cached audio — still try the network for it, but text is already shown.
          fetch(`/api/v1/bibles/${versionId}/books/${book}/chapters/${chapterNum}`)
            .then(r => r.json())
            .then((data: { success: boolean; data: ChapterData }) => {
              if (!cancelled && data.success && data.data) setAudioUrl(data.data.audio?.url || null);
            })
            .catch(() => {});
        }
        setLoading(false);
        return;
      }

      try {
        const res = await fetch(`/api/v1/bibles/${versionId}/books/${book}/chapters/${chapterNum}`);
        const data: { success: boolean; data: ChapterData } = await res.json();
        if (cancelled) return;
        if (data.success && data.data) {
          setVerses(data.data.verses || []);
          if (data.data.bookName) setBookName(data.data.bookName);
          setAudioUrl(data.data.audio?.url || null);
          // Mirror the native app: any chapter read once is cached for offline
          // reading later, independent of the explicit whole-Bible download.
          saveChapterOffline({
            versionId,
            bookId: book,
            chapterNumber: chapterNum,
            bookName: data.data.bookName || book,
            verses: data.data.verses || [],
          }).catch(() => {});
        } else {
          // Backend reports success:false when this chapter doesn't exist in
          // this translation at all (e.g. an Old Testament chapter in a
          // New-Testament-only version) — distinct from a transient error.
          setUnavailable(true);
        }
      } catch {
        // Network/parse error — leave verses empty, generic retry message covers this.
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();

    return () => {
      cancelled = true;
      audioRef.current?.pause();
      audioRef.current = null;
    };
  }, [book, chapter, versionId]);

  const toggleAudio = () => {
    if (!audioUrl) {
      setShowNoAudioNotice(true);
      setTimeout(() => setShowNoAudioNotice(false), 2500);
      return;
    }
    if (!audioRef.current) {
      audioRef.current = new Audio(audioUrl);
      audioRef.current.onended = () => setIsPlaying(false);
      audioRef.current.onerror = () => setIsPlaying(false);
    }
    if (isPlaying) {
      audioRef.current.pause();
      setIsPlaying(false);
    } else {
      audioRef.current.play().then(() => setIsPlaying(true)).catch(() => setIsPlaying(false));
    }
  };

  const openVerseMenu = (verse: Verse, clientY: number) => {
    const maxY = window.innerHeight - 130;
    setVerseMenu({ verse, y: Math.min(clientY - 20, maxY) });
  };
  const startLongPress = (verse: Verse, clientY: number) => {
    if (longPressTimer.current) clearTimeout(longPressTimer.current);
    longPressTimer.current = setTimeout(() => openVerseMenu(verse, clientY), 500);
  };
  const cancelLongPress = () => {
    if (longPressTimer.current) clearTimeout(longPressTimer.current);
  };

  // Saved to IndexedDB first, so this always succeeds instantly whether or
  // not there's a network - syncBookmarks() pushes it to the account
  // whenever one is actually available, in the background.
  const saveVerse = async (verse: Verse, note?: string) => {
    if (!getToken()) {
      setSavedVerses(s => ({ ...s, [verse.number]: 'noauth' as never }));
      setTimeout(() => setSavedVerses(s => ({ ...s, [verse.number]: 'idle' })), 3000);
      return;
    }
    if (!book) return;
    const key = verse.number;
    setSavedVerses(s => ({ ...s, [key]: 'saving' }));
    try {
      await addBookmarkOffline({
        versionId,
        bookId: book,
        chapterNumber: Number(chapter),
        verseNumber: verse.number,
        text: verse.text,
        bookName,
        languageCode: versionInfo.lang,
        note,
      });
      setSavedVerses(s => ({ ...s, [key]: 'saved' }));
      syncBookmarks();
    } catch {
      setSavedVerses(s => ({ ...s, [key]: 'error' }));
      setTimeout(() => setSavedVerses(s => ({ ...s, [key]: 'idle' })), 2000);
    }
  };

  const submitNote = async (verse: Verse) => {
    if (!noteText.trim()) return;
    setNoteSaving(true);
    await saveVerse(verse, noteText);
    setNoteSaving(false);
    setNoteVerse(null);
    setNoteText('');
  };

  const copyVerse = (verse: Verse) => {
    const text = `${bookName} ${chapter}:${verse.number} — "${verse.text}"`;
    navigator.clipboard.writeText(text).catch(() => {});
    setVerseMenu(null);
    setHighlightedVerse(null);
  };

  const shareVerse = (verse: Verse) => {
    const text = `${bookName} ${chapter}:${verse.number}\n"${verse.text}"`;
    if (navigator.share) {
      navigator.share({ title: `${bookName} ${chapter}:${verse.number}`, text }).catch(() => {});
    } else {
      navigator.clipboard.writeText(text).catch(() => {});
    }
    setVerseMenu(null);
    setHighlightedVerse(null);
  };

  return (
    <PageContainer className={`pt-0 relative bg-[#fdfcfa] dark:bg-background transition-all duration-300 ${immersive ? 'pb-4' : 'pb-20'}`}>
      {/* AppBar + settings — slide out when immersive */}
      <motion.div
        animate={{ y: immersive ? -120 : 0, opacity: immersive ? 0 : 1 }}
        transition={{ type: 'spring', damping: 30, stiffness: 300 }}
        style={{ pointerEvents: immersive ? 'none' : 'auto' }}
      >
      {/* AppBar */}
      <AppBar
        title={`${bookName} ${chapter}`}
        onBack={() => navigate(-1)}
        rightAction={
          <div className="flex items-center gap-1.5 relative">
            <AnimatePresence>
              {showNoAudioNotice && (
                <motion.div
                  initial={{ opacity: 0, y: -4 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0 }}
                  className="absolute top-11 right-0 z-10 bg-foreground text-background text-xs font-sans font-medium px-3 py-2 rounded-xl shadow-lg whitespace-nowrap"
                >
                  Audio not available for this chapter
                </motion.div>
              )}
            </AnimatePresence>
            <motion.button
              whileTap={{ scale: 0.9 }}
              onClick={toggleAudio}
              className={`w-9 h-9 rounded-xl flex items-center justify-center transition-all ${
                isPlaying
                  ? 'bg-primary text-primary-foreground'
                  : audioUrl
                  ? 'bg-muted text-primary'
                  : 'bg-muted text-muted-foreground opacity-40'
              }`}
            >
              {isPlaying ? <VolumeX size={16} /> : <Volume2 size={16} />}
            </motion.button>

            <motion.button
              whileTap={{ scale: 0.9 }}
              onClick={() => { setShowPanel(p => !p); setImmersive(false); }}
              className={`w-9 h-9 rounded-xl flex items-center justify-center transition-all ${
                showPanel ? 'bg-primary text-primary-foreground' : 'bg-muted text-primary'
              }`}
            >
              <SlidersHorizontal size={16} />
            </motion.button>
          </div>
        }
      />

      {/* Settings panel */}
      <AnimatePresence>
        {showPanel && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            className="overflow-hidden border-b border-border bg-card/95 backdrop-blur-xl"
          >
            <div className="px-4 py-4 space-y-4 max-w-md mx-auto">
              <div className="flex items-center gap-3">
                <span className="text-muted-foreground font-sans text-xs w-16">Text Size</span>
                <motion.button whileTap={{ scale: 0.9 }} onClick={decreaseFontSize}
                  className="w-8 h-8 rounded-full bg-muted flex items-center justify-center text-primary flex-shrink-0">
                  <Minus size={14} />
                </motion.button>
                <div className="flex-1 h-1.5 bg-muted rounded-full relative">
                  <div className="absolute left-0 top-0 h-full bg-primary rounded-full transition-all"
                    style={{ width: `${((fontSize - 14) / 14) * 100}%` }} />
                </div>
                <motion.button whileTap={{ scale: 0.9 }} onClick={increaseFontSize}
                  className="w-8 h-8 rounded-full bg-muted flex items-center justify-center text-primary flex-shrink-0">
                  <Plus size={14} />
                </motion.button>
                <span className="text-foreground font-semibold font-sans text-xs w-9 text-right">{fontSize}px</span>
              </div>

              <div className="h-px bg-border" />

              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2 flex-shrink-0">
                  <span className="text-muted-foreground font-sans text-xs">Language</span>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-foreground font-sans text-xs font-semibold">
                    {versionInfo.label}
                  </span>
                  {!isEnglish && (
                    <motion.button whileTap={{ scale: 0.95 }} onClick={switchToEnglish}
                      className="bg-primary/10 text-primary rounded-lg px-2.5 py-1 font-sans text-xs font-semibold hover:bg-primary/20 transition-colors whitespace-nowrap">
                      Switch to EN
                    </motion.button>
                  )}
                  {isEnglish && prevVersionInfo && (
                    <motion.button whileTap={{ scale: 0.95 }} onClick={switchBack}
                      className="bg-muted text-foreground rounded-lg px-2.5 py-1 font-sans text-xs font-semibold hover:bg-muted/80 transition-colors whitespace-nowrap">
                      Switch back
                    </motion.button>
                  )}
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      </motion.div>

      {/* Loading */}
      {loading && (
        <div className="flex items-center justify-center py-16">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      )}

      {/* Bible Text */}
      {!loading && (
        <div
          className="py-8 px-4 max-w-2xl mx-auto"
          onClick={() => {
            if (!verseMenu && !showPanel) setImmersive(i => !i);
          }}
        >
          {verses.length === 0 && unavailable && (
            <div className="text-center py-12 px-6">
              <p className="text-foreground font-serif text-base mb-2">Not available in this translation</p>
              <p className="text-muted-foreground font-sans text-sm">
                {bookName} {chapter} isn't included in {versionInfo.label}. Some Bible versions only cover certain
                books — for example, the New Testament only.
              </p>
            </div>
          )}

          {verses.length === 0 && !unavailable && (
            <p className="text-muted-foreground text-center py-8 font-sans text-sm">
              Chapter content is being loaded. Please try again later.
            </p>
          )}

          {verses.length > 0 && (
            <p
              className="text-foreground font-serif"
              style={{ fontSize: `${fontSize}px`, lineHeight: '1.9' }}
            >
              {verses.map((item) => {
                const isSelected = highlightedVerse === item.number;
                return (
                  <span
                    id={`verse-${item.number}`}
                    key={item.number}
                    className={`transition-colors select-none cursor-pointer rounded ${
                      isSelected ? 'bg-[var(--primary)]/10' : ''
                    }`}
                    style={{
                      fontWeight: isSelected ? 500 : 400,
                      boxDecorationBreak: 'clone',
                      WebkitBoxDecorationBreak: 'clone',
                      padding: isSelected ? '0.15em 0.05em' : undefined,
                    }}
                    onClick={e => {
                      e.stopPropagation();
                      cancelLongPress();
                      if (immersive) { setImmersive(false); return; }
                      setHighlightedVerse(item.number);
                      openVerseMenu(item, e.clientY);
                    }}
                    onMouseDown={e => startLongPress(item, e.clientY)}
                    onMouseUp={cancelLongPress}
                    onMouseLeave={cancelLongPress}
                    onTouchStart={e => startLongPress(item, e.touches[0].clientY)}
                    onTouchEnd={cancelLongPress}
                    onTouchMove={cancelLongPress}
                  >
                    <sup className={`font-bold font-sans text-xs mr-1 ${isSelected ? 'text-[var(--primary)]' : 'text-[var(--primary)]/50'}`}>
                      {item.number}
                    </sup>
                    {item.text}{' '}
                  </span>
                );
              })}
            </p>
          )}

        </div>
      )}

      {/* Fixed bottom chapter nav bar — slides out when immersive */}
      <motion.div
        animate={{ y: immersive ? 100 : 0, opacity: immersive ? 0 : 1 }}
        transition={{ type: 'spring', damping: 30, stiffness: 300 }}
        style={{ pointerEvents: immersive ? 'none' : 'auto' }}
        className="fixed bottom-0 left-0 right-0 bg-[#fdfcfa] dark:bg-card border-t border-border z-30 flex items-center px-3 py-2 gap-2"
      >
        {/* Prev */}
        <motion.button
          whileTap={{ scale: 0.92 }}
          onClick={goToPrev}
          disabled={chapterNum <= 1}
          className={`w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0 transition-all ${
            chapterNum > 1
              ? 'bg-[var(--primary)] text-primary-foreground shadow-md shadow-[var(--primary)]/30'
              : 'bg-muted text-muted-foreground opacity-40 cursor-not-allowed'
          }`}
        >
          <ChevronLeft size={22} />
        </motion.button>

        {/* Center — tap to open verse list */}
        <motion.button
          whileTap={{ scale: 0.97 }}
          onClick={() => setShowVersePicker(true)}
          className="flex-1 flex flex-col items-center justify-center py-1 rounded-2xl hover:bg-muted/50 transition-colors"
        >
          <span className="text-foreground font-bold font-sans text-base leading-tight">{bookName}</span>
          <span className="text-muted-foreground font-sans text-xs mt-0.5">
            {chapterNum}{chapterCount > 0 ? ` / ${chapterCount}` : ''}{verses.length > 0 ? ` · ${verses.length} verses` : ''}
          </span>
        </motion.button>

        {/* Next */}
        <motion.button
          whileTap={{ scale: 0.92 }}
          onClick={goToNext}
          disabled={chapterCount > 0 && chapterNum >= chapterCount}
          className={`w-12 h-12 rounded-2xl flex items-center justify-center flex-shrink-0 transition-all ${
            chapterCount === 0 || chapterNum < chapterCount
              ? 'bg-[var(--primary)] text-primary-foreground shadow-md shadow-[var(--primary)]/30'
              : 'bg-muted text-muted-foreground opacity-40 cursor-not-allowed'
          }`}
        >
          <ChevronRight size={22} />
        </motion.button>
      </motion.div>

      {/* Verse Picker Bottom Sheet */}
      <AnimatePresence>
        {showVersePicker && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => { setShowVersePicker(false); setShowBookList(false); }}
              className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40"
            />
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="fixed bottom-0 left-0 right-0 bg-card rounded-t-[28px] z-50 shadow-2xl"
            >
              <div className="w-12 h-1 bg-muted rounded-full mx-auto mt-3 mb-1" />

              {/* Header */}
              <div className="px-5 pt-2 pb-3 flex items-center justify-between border-b border-border">
                <div>
                  <motion.button
                    whileTap={{ scale: 0.97 }}
                    onClick={() => {
                      if (showBookList) {
                        setShowBookList(false);
                      } else {
                        setShowBookList(true);
                        if (bookList.length === 0) {
                          fetch(`/api/v1/bibles/${versionId}/books?lang=${versionInfo.lang}`)
                            .then(r => r.json())
                            .then(d => { if (d.success) setBookList(d.data.map((b: { id: string; title: string }) => ({ id: b.id, title: b.title }))); })
                            .catch(() => {});
                        }
                      }
                    }}
                    className="flex items-center gap-1 group"
                  >
                    {showBookList && <ChevronLeft size={16} className="text-muted-foreground" />}
                    <span className="text-foreground font-bold font-sans text-lg group-hover:text-primary transition-colors">{bookName}</span>
                    {!showBookList && <ChevronRight size={16} className="text-muted-foreground group-hover:text-primary transition-colors" />}
                  </motion.button>
                  <p className="text-muted-foreground font-sans text-xs mt-0.5">
                    {showBookList ? 'Tap a book to switch' : `Chapter ${chapterNum} · ${verses.length} verses`}
                  </p>
                </div>
                {!showBookList && <span className="text-muted-foreground font-sans text-xs">{chapterNum} / {chapterCount}</span>}
              </div>

              {/* Books list */}
              {showBookList && (
                <div className="overflow-y-auto max-h-[55vh] py-2">
                  {bookList.map(b => (
                    <motion.button
                      key={b.id}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => { setShowVersePicker(false); setShowBookList(false); navigate(`/bible/${b.id}`); }}
                      className={`w-full text-left px-5 py-3 font-sans text-base transition-colors ${
                        b.id === book
                          ? 'text-[var(--primary)] font-bold bg-[var(--primary)]/8'
                          : 'text-foreground hover:bg-muted/50'
                      }`}
                    >
                      {b.title}
                    </motion.button>
                  ))}
                </div>
              )}

              {/* Verse number grid */}
              {!showBookList && (
                <div className="overflow-y-auto max-h-[55vh] px-4 py-3">
                  <div className="grid grid-cols-5 gap-2">
                    {verses.map(v => (
                      <motion.button
                        key={v.number}
                        whileTap={{ scale: 0.94 }}
                        onClick={() => {
                          setShowVersePicker(false);
                          setHighlightedVerse(v.number);
                          setTimeout(() => {
                            document.getElementById(`verse-${v.number}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' });
                          }, 300);
                        }}
                        className="aspect-square rounded-xl flex items-center justify-center font-bold font-sans text-sm bg-muted text-foreground hover:bg-[var(--primary)] hover:text-primary-foreground transition-all"
                      >
                        {v.number}
                      </motion.button>
                    ))}
                  </div>
                </div>
              )}
              <div className="h-4" />
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Long-press verse action popup */}
      <AnimatePresence>
        {verseMenu && (
          <>
            <motion.div
              className="fixed inset-0 z-40"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => { setVerseMenu(null); setHighlightedVerse(null); }}
            />
            <motion.div
              className="fixed left-4 right-4 z-50 bg-card rounded-2xl shadow-2xl border border-border overflow-hidden"
              style={{ top: verseMenu.y }}
              initial={{ opacity: 0, scale: 0.92, y: 8 }}
              animate={{ opacity: 1, scale: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.92, y: 8 }}
              transition={{ type: 'spring', damping: 25, stiffness: 350 }}
            >
              <div className="px-4 py-2.5 border-b border-border">
                <p className="text-xs text-muted-foreground font-sans font-medium">
                  {bookName} {chapter}:{verseMenu.verse.number}
                </p>
                <p className="text-foreground font-serif text-sm mt-0.5 line-clamp-2">
                  {verseMenu.verse.text}
                </p>
              </div>
              <div className="flex">
                <motion.button
                  whileTap={{ scale: 0.96 }}
                  onClick={() => copyVerse(verseMenu.verse)}
                  className="flex-1 flex items-center justify-center gap-2 py-3.5 hover:bg-muted transition-colors border-r border-b border-border"
                >
                  <Copy size={16} className="text-primary" />
                  <span className="text-sm font-sans font-semibold text-foreground">Copy</span>
                </motion.button>
                <motion.button
                  whileTap={{ scale: 0.96 }}
                  onClick={() => shareVerse(verseMenu.verse)}
                  className="flex-1 flex items-center justify-center gap-2 py-3.5 hover:bg-muted transition-colors border-b border-border"
                >
                  <Share2 size={16} className="text-primary" />
                  <span className="text-sm font-sans font-semibold text-foreground">Share</span>
                </motion.button>
              </div>
              <div className="flex">
                <motion.button
                  whileTap={{ scale: 0.96 }}
                  onClick={() => {
                    if (savedVerses[verseMenu.verse.number] !== 'saved') saveVerse(verseMenu.verse);
                  }}
                  className="flex-1 flex items-center justify-center gap-2 py-3.5 hover:bg-muted transition-colors border-r border-border"
                >
                  {savedVerses[verseMenu.verse.number] === 'saved' ? (
                    <>
                      <BookmarkCheck size={16} className="text-green-600" />
                      <span className="text-sm font-sans font-semibold text-green-700">Saved</span>
                    </>
                  ) : savedVerses[verseMenu.verse.number] === 'saving' ? (
                    <>
                      <Bookmark size={16} className="text-primary" />
                      <span className="text-sm font-sans font-semibold text-foreground">Saving…</span>
                    </>
                  ) : (savedVerses[verseMenu.verse.number] as string) === 'noauth' ? (
                    <>
                      <Bookmark size={16} className="text-amber-600" />
                      <span className="text-sm font-sans font-semibold text-amber-700">Sign in to save</span>
                    </>
                  ) : (
                    <>
                      <Bookmark size={16} className="text-primary" />
                      <span className="text-sm font-sans font-semibold text-foreground">Save</span>
                    </>
                  )}
                </motion.button>
                <motion.button
                  whileTap={{ scale: 0.96 }}
                  onClick={() => {
                    const num = verseMenu.verse.number;
                    setNoteVerse(noteVerse === num ? null : num);
                    setNoteText('');
                  }}
                  className="flex-1 flex items-center justify-center gap-2 py-3.5 hover:bg-muted transition-colors"
                >
                  <NotebookPen size={16} className="text-primary" />
                  <span className="text-sm font-sans font-semibold text-foreground">Add to Note</span>
                </motion.button>
              </div>

              {/* Note input */}
              {noteVerse === verseMenu.verse.number && (
                <motion.div
                  initial={{ opacity: 0, height: 0 }}
                  animate={{ opacity: 1, height: 'auto' }}
                  className="overflow-hidden border-t border-border px-4 pt-3 pb-4"
                  onClick={e => e.stopPropagation()}
                >
                  <textarea
                    autoFocus
                    value={noteText}
                    onChange={e => setNoteText(e.target.value)}
                    placeholder="Write your note here…"
                    rows={3}
                    className="w-full bg-muted/40 border border-border rounded-xl px-3 py-2 text-sm font-sans text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-[var(--primary)]/30 resize-none"
                  />
                  <div className="flex gap-2 mt-1.5">
                    <button
                      onClick={() => submitNote(verseMenu.verse)}
                      disabled={!noteText.trim() || noteSaving}
                      className="flex items-center gap-1.5 bg-[var(--primary)] text-primary-foreground rounded-xl px-3 py-1.5 text-xs font-semibold font-sans disabled:opacity-50"
                    >
                      <Check size={12} /> {noteSaving ? 'Saving…' : 'Save Note'}
                    </button>
                    <button
                      onClick={() => { setNoteVerse(null); setNoteText(''); }}
                      className="flex items-center gap-1.5 bg-muted text-muted-foreground rounded-xl px-3 py-1.5 text-xs font-semibold font-sans"
                    >
                      <X size={12} /> Cancel
                    </button>
                  </div>
                </motion.div>
              )}
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </PageContainer>
  );
}
