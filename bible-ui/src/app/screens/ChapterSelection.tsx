import { useParams, useNavigate } from 'react-router';
import { Check } from 'lucide-react';
import { motion } from 'motion/react';
import { useState, useEffect } from 'react';
import { PageContainer, Heading1, Text, AppBar } from '../components/BibleSystem';
import { getBibleVersionId } from '../lib/api';

interface ChapterMeta {
  chapterNumber: number;
  bookName: string;
  isImported: boolean;
}

const VERSION_LANG: Record<number, string> = {
  111: 'en', 1895: 'te', 1980: 'hi', 1899: 'ta', 1912: 'ml',
  1898: 'kn', 1692: 'kn', 1910: 'mr', 1884: 'pa', 1979: 'as',
  155: 'bn', 1681: 'bn', 1690: 'bn', 1883: 'bn', 1711: 'ne',
  722: 'sd', 1866: 'kok',
};

export function ChapterSelection() {
  const { book } = useParams<{ book: string }>();
  const navigate = useNavigate();
  const [chapters, setChapters] = useState<ChapterMeta[]>([]);
  const [bookName, setBookName] = useState(book || '');
  const [loading, setLoading] = useState(true);
  const [completedChapters] = useState<number[]>([]);

  const versionId = getBibleVersionId();

  useEffect(() => {
    if (!book) return;

    // Fetch chapters
    fetch(`/api/v1/bibles/${versionId}/books/${book}/chapters`)
      .then(r => r.json())
      .then((data: { success: boolean; data: ChapterMeta[] }) => {
        if (data.success && Array.isArray(data.data)) {
          setChapters(data.data);
          if (data.data[0]?.bookName) setBookName(data.data[0].bookName);
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));

    // Fetch localized book name
    const lang = VERSION_LANG[versionId] || 'en';
    fetch(`/api/v1/bibles/${versionId}/books?lang=${lang}`)
      .then(r => r.json())
      .then((data: { success: boolean; data: { id: string; title: string }[] }) => {
        if (data.success && Array.isArray(data.data)) {
          const found = data.data.find(b => b.id.toUpperCase() === book.toUpperCase());
          if (found?.title) setBookName(found.title);
        }
      })
      .catch(() => {});
  }, [book, versionId]);

  return (
    <PageContainer className="pt-0">
      <AppBar onBack={() => navigate('/bible')} />

      <div className="pt-4 pb-6 px-2">
        <Heading1 className="mb-2">{bookName}</Heading1>
        <Text>Select a chapter to read</Text>
      </div>

      {/* Loading state */}
      {loading && (
        <div className="flex items-center justify-center py-12">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      )}

      {/* Chapter Grid */}
      {!loading && (
        <div className="py-2">
          <div className="grid grid-cols-4 gap-3">
            {chapters.map((ch) => {
              const isCompleted = completedChapters.includes(ch.chapterNumber);

              return (
                <motion.button
                  key={ch.chapterNumber}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => navigate(`/bible/${book}/${ch.chapterNumber}`)}
                  className={`relative aspect-square rounded-2xl flex items-center justify-center font-bold text-lg transition-all shadow-sm font-serif ${
                    isCompleted
                      ? 'bg-primary text-primary-foreground shadow-md shadow-primary/20'
                      : 'bg-card text-foreground border border-border hover:border-primary/30'
                  }`}
                >
                  {ch.chapterNumber}
                  {isCompleted && (
                    <motion.div
                      initial={{ scale: 0 }}
                      animate={{ scale: 1 }}
                      className="absolute -top-1 -right-1 w-5 h-5 bg-accent rounded-full flex items-center justify-center"
                    >
                      <Check size={12} className="text-accent-foreground" strokeWidth={3} />
                    </motion.div>
                  )}
                </motion.button>
              );
            })}
          </div>
        </div>
      )}
    </PageContainer>
  );
}
