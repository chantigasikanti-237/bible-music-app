import { useState, useEffect, useSyncExternalStore } from 'react';
import { useNavigate } from 'react-router';
import { Search, ChevronRight, Globe, Check, X, CloudDownload } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { Heading1, Text, Chip } from '../components/BibleSystem';
import { getBibleVersionId, setBibleVersionId } from '../lib/api';
import { getVersionCompletionInfo } from '../lib/offlineStore';
import { subscribe, getSnapshot, startVersionDownload, cancelVersionDownload } from '../lib/downloadManager';
import { isUniversalLanguageEnabled, applyUniversalLanguage, type LanguageCode } from '../lib/languagePreference';
import { parseReference } from '../lib/bibleReference';

interface BibleBook {
  id: string;
  title: string;
  titleRomanized?: string;
  englishTitle?: string;
  canon: string;
  chapterCount: number;
  availableChapterCount: number;
}

export const BIBLE_VERSIONS = [
  { id: 111,  lang: 'en', label: 'English',                sublabel: 'King James Version (KJV)',   flag: '🇬🇧' },
  { id: 1895, lang: 'te', label: 'Telugu (తెలుగు)',        sublabel: 'Telugu IRV 2019',            flag: '🇮🇳' },
  { id: 1980, lang: 'hi', label: 'Hindi (हिंदी)',          sublabel: 'Hindi IRV 2019',             flag: '🇮🇳' },
  { id: 1899, lang: 'ta', label: 'Tamil (தமிழ்)',          sublabel: 'Tamil IRV 2019',             flag: '🇮🇳' },
  { id: 1912, lang: 'ml', label: 'Malayalam (മലയാളം)',     sublabel: 'Malayalam IRV 2025',         flag: '🇮🇳' },
  { id: 1898, lang: 'kn', label: 'Kannada (ಕನ್ನಡ)',        sublabel: 'Kannada IRV 2019',           flag: '🇮🇳' },
  { id: 1692, lang: 'kn', label: 'Kannada CL (ಕನ್ನಡ)',    sublabel: 'Kannada CL BSI',             flag: '🇮🇳' },
  { id: 1910, lang: 'mr', label: 'Marathi (मराठी)',        sublabel: 'Marathi IRV',                flag: '🇮🇳' },
  { id: 1884, lang: 'pa', label: 'Punjabi (ਪੰਜਾਬੀ)',       sublabel: 'Punjabi IRV',                flag: '🇮🇳' },
  { id: 1979, lang: 'as', label: 'Assamese (অসমীয়া)',     sublabel: 'Assamese IRV 2019',          flag: '🇮🇳' },
  { id: 155,  lang: 'bn', label: 'Bengali (বাংলা)',        sublabel: 'Pobitro Baibel',             flag: '🇧🇩' },
  { id: 1681, lang: 'bn', label: 'Bengali OV (বাংলা)',     sublabel: 'Bengali OV BSI',             flag: '🇧🇩' },
  { id: 1690, lang: 'bn', label: 'Bengali CL (বাংলা)',     sublabel: 'Bengali CL BSI',             flag: '🇧🇩' },
  { id: 1883, lang: 'bn', label: 'Bengali IRV (বাংলা)',    sublabel: 'Bengali IRV',                flag: '🇧🇩' },
  { id: 1711, lang: 'ne', label: 'Nepali (नेपाली)',        sublabel: 'Nepali Saral',               flag: '🇳🇵' },
  { id: 722,  lang: 'sd', label: 'Sindhi (سنڌي)',          sublabel: 'Sindhi Common Language NT',  flag: '🇵🇰' },
  { id: 1866, lang: 'kok',label: 'Konkani (कोंकणी)',       sublabel: 'Konkani/Goan NT BSI',        flag: '🇮🇳' },
];

const canonLabel = (canon: string) => {
  if (canon === 'OT') return 'Old Testament';
  if (canon === 'NT') return 'New Testament';
  return canon;
};

export function BibleLibrary() {
  const navigate = useNavigate();
  const [versionId, setVersionId] = useState<number>(getBibleVersionId);
  const [showLangPicker, setShowLangPicker] = useState(false);
  const [books, setBooks] = useState<BibleBook[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedTestament, setSelectedTestament] = useState<'All' | 'Old Testament' | 'New Testament'>('All');

  useEffect(() => {
    setLoading(true);
    const lang = BIBLE_VERSIONS.find(v => v.id === versionId)?.lang || 'en';
    fetch(`/api/v1/bibles/${versionId}/books?lang=${lang}`)
      .then(r => r.json())
      .then((data: { success: boolean; data: BibleBook[] }) => {
        if (data.success && Array.isArray(data.data)) setBooks(data.data);
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [versionId]);

  const selectVersion = (id: number) => {
    setBibleVersionId(id);
    setVersionId(id);
    setShowLangPicker(false);

    if (isUniversalLanguageEnabled()) {
      const picked = BIBLE_VERSIONS.find(v => v.id === id);
      if (picked) applyUniversalLanguage(picked.lang as LanguageCode, id);
    }
  };

  const currentVersion = BIBLE_VERSIONS.find(v => v.id === versionId) || BIBLE_VERSIONS[0];
  const [universalOn] = useState(isUniversalLanguageEnabled);

  // Reflects the shared download manager so progress/completion stays correct
  // even if a download was started from the Profile > Downloads screen.
  const [isCurrentDownloaded, setIsCurrentDownloaded] = useState(false);
  const downloadSnapshot = useSyncExternalStore(subscribe, () => getSnapshot(versionId));
  const isDownloadingCurrent = downloadSnapshot.status === 'downloading';

  useEffect(() => {
    if (isDownloadingCurrent) return;
    getVersionCompletionInfo(versionId).then((info) => setIsCurrentDownloaded(info != null));
  }, [versionId, isDownloadingCurrent]);

  const handleDownloadClick = () => {
    if (isDownloadingCurrent) {
      cancelVersionDownload(versionId);
      return;
    }
    if (isCurrentDownloaded) return;
    if (!window.confirm(`Download the whole ${currentVersion.label} Bible (text + audio) for offline use? This can take a while.`)) {
      return;
    }
    startVersionDownload(versionId, currentVersion.lang);
  };

  const filteredBooks = books.filter(book => {
    const testament = canonLabel(book.canon);
    const q = searchQuery.toLowerCase();
    const matchesSearch =
      book.title.toLowerCase().includes(q) ||
      book.titleRomanized?.toLowerCase().includes(q) ||
      book.englishTitle?.toLowerCase().includes(q);
    const matchesTestament = selectedTestament === 'All' || testament === selectedTestament;
    return matchesSearch && matchesTestament;
  });

  // "genesis 7:16" / "ephesians 22" — jump straight to that chapter (and
  // verse, if given) instead of just filtering the book list by name.
  const parsedReference = parseReference(searchQuery, books);

  return (
    <div className="min-h-full bg-background pb-24">
      {/* Header */}
      <div className="bg-gradient-to-b from-card to-background px-4 pt-12 pb-6 shadow-sm border-b border-border relative">
        <div className="flex items-start justify-between">
          <div>
            <Heading1 className="mb-2">Bible Library</Heading1>
            <Text>Select a book to begin reading</Text>
          </div>

          {/* Top-right language controls */}
          <div className="mt-1 flex items-center gap-2">
            {/* Download current Bible version for offline use — fades once downloaded */}
            <motion.button
              whileTap={{ scale: isCurrentDownloaded ? 1 : 0.9 }}
              onClick={handleDownloadClick}
              className={`flex items-center justify-center rounded-2xl px-2.5 py-2 border transition-colors ${
                isCurrentDownloaded
                  ? 'bg-muted/40 border-transparent opacity-40 cursor-default'
                  : 'bg-muted hover:bg-muted/80 border-border'
              }`}
            >
              <motion.div
                animate={isDownloadingCurrent ? { opacity: [1, 0.35, 1] } : { opacity: 1 }}
                transition={isDownloadingCurrent ? { repeat: Infinity, duration: 1.1 } : undefined}
              >
                <CloudDownload size={18} className="text-muted-foreground" />
              </motion.div>
            </motion.button>

            {/* Globe / Language picker button — hidden while Universal Language is on */}
            {!universalOn && (
              <motion.button
                whileTap={{ scale: 0.9 }}
                onClick={() => setShowLangPicker(true)}
                className="flex items-center gap-1.5 bg-primary/10 hover:bg-primary/20 transition-colors rounded-2xl px-3 py-2"
              >
                <Globe size={18} className="text-primary" />
                <span className="text-primary font-sans text-xs font-semibold">{currentVersion.label.split(' ')[0]}</span>
              </motion.button>
            )}
          </div>
        </div>
      </div>

      {/* Search Bar */}
      <div className="px-4 py-4">
        <div className="relative">
          <Search size={20} className="absolute left-4 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            type="text"
            placeholder="Search books..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            onFocus={() => window.dispatchEvent(new CustomEvent('search-expanded', { detail: true }))}
            onBlur={() => window.dispatchEvent(new CustomEvent('search-expanded', { detail: false }))}
            className="w-full bg-card rounded-2xl pl-12 pr-4 py-3.5 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 shadow-sm transition-all font-sans text-base"
          />
        </div>
      </div>

      {/* Filter Chips */}
      <div className="flex gap-3 px-4 mb-4 overflow-x-auto pb-2 scrollbar-hide">
        {(['All', 'Old Testament', 'New Testament'] as const).map((filter) => (
          <Chip
            key={filter}
            active={selectedTestament === filter}
            onClick={() => setSelectedTestament(filter)}
            className="whitespace-nowrap"
          >
            {filter}
          </Chip>
        ))}
      </div>

      {/* Loading */}
      {loading && (
        <div className="flex items-center justify-center py-12">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      )}

      {/* Books List */}
      {!loading && (
        <div className="px-4 space-y-3">
          {parsedReference && (
            <motion.button
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              whileTap={{ scale: 0.98 }}
              onClick={() => navigate(`/bible/${parsedReference.book.id}/${parsedReference.chapter}`, {
                state: parsedReference.verse ? { verseNumber: parsedReference.verse } : undefined,
              })}
              className="w-full bg-primary/8 rounded-2xl p-4 flex items-center justify-between border border-primary/20 hover:bg-primary/12 transition-all"
            >
              <div className="text-left">
                <h3 className="text-primary font-bold mb-0.5 font-sans text-base">
                  {parsedReference.book.title} {parsedReference.chapter}
                  {parsedReference.verse ? `:${parsedReference.verse}` : ''}
                </h3>
                <p className="text-muted-foreground font-sans text-sm">Go to chapter</p>
              </div>
              <ChevronRight size={20} className="text-primary" />
            </motion.button>
          )}
          {filteredBooks.map((book, index) => (
            <motion.button
              key={book.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={() => navigate(`/bible/${book.id}`)}
              className="w-full bg-card rounded-2xl p-4 flex items-center justify-between shadow-sm border border-border hover:bg-muted/30 transition-all group"
            >
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center group-hover:bg-primary/20 transition-all">
                  <span className="text-primary font-bold font-serif text-lg">
                    {book.title.charAt(0)}
                  </span>
                </div>
                <div className="text-left">
                  <h3 className="text-foreground font-semibold mb-0.5 font-sans text-base">
                    {book.title}
                  </h3>
                  <p className="text-muted-foreground font-sans text-sm">
                    {book.chapterCount} chapters • {canonLabel(book.canon)}
                  </p>
                </div>
              </div>
              <ChevronRight size={20} className="text-muted-foreground group-hover:text-primary transition-colors" />
            </motion.button>
          ))}
        </div>
      )}

      {/* Language Picker Bottom Sheet */}
      <AnimatePresence>
        {showLangPicker && (
          <>
            {/* Backdrop */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setShowLangPicker(false)}
              className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40"
            />

            {/* Sheet */}
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="fixed bottom-0 left-0 right-0 bg-card rounded-t-[28px] z-50 shadow-2xl"
            >
              {/* Handle */}
              <div className="flex items-center justify-between px-5 pt-5 pb-2">
                <div>
                  <h2 className="text-foreground font-semibold font-sans text-base">Bible Language</h2>
                  <p className="text-muted-foreground font-sans text-xs mt-0.5">Choose your reading language</p>
                </div>
                <motion.button
                  whileTap={{ scale: 0.9 }}
                  onClick={() => setShowLangPicker(false)}
                  className="w-8 h-8 rounded-full bg-muted flex items-center justify-center"
                >
                  <X size={16} className="text-muted-foreground" />
                </motion.button>
              </div>

              <div className="w-12 h-1 bg-muted rounded-full mx-auto mb-4" />

              <div className="px-4 pb-8 space-y-2 overflow-y-auto max-h-[60vh]">
                {BIBLE_VERSIONS.map((version) => {
                  const selected = version.id === versionId;
                  return (
                    <motion.button
                      key={version.id}
                      whileTap={{ scale: 0.98 }}
                      onClick={() => selectVersion(version.id)}
                      className={`w-full flex items-center gap-4 p-4 rounded-2xl transition-all ${
                        selected ? 'bg-primary/10 border border-primary/30' : 'bg-muted/40 border border-transparent hover:bg-muted'
                      }`}
                    >
                      <div className="flex-1 text-left">
                        <p className={`font-semibold font-sans text-sm ${selected ? 'text-primary' : 'text-foreground'}`}>
                          {version.label}
                        </p>
                        <p className="text-muted-foreground font-sans text-xs">{version.sublabel}</p>
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
    </div>
  );
}
