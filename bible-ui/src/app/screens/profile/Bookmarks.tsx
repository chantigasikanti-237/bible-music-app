import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { Bookmark, Trash2, BookOpen } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { PageContainer, AppBar } from '../../components/BibleSystem';
import { apiFetch, getToken } from '../../lib/api';

interface VerseBookmark {
  _id: string;
  reference: string;
  text: string;
  bookId: string;
  chapterNumber: number;
  verseNumber: number;
  createdAt: string;
}

export function Bookmarks() {
  const navigate = useNavigate();
  const [bookmarks, setBookmarks] = useState<VerseBookmark[]>([]);
  const [loading, setLoading] = useState(true);
  const [deleting, setDeleting] = useState<string | null>(null);

  useEffect(() => {
    if (!getToken()) { navigate('/login'); return; }
    apiFetch<{ success: boolean; data: any[] }>('/api/v1/users/me/bookmarks?targetType=verse')
      .then(res => {
        if (res.success && Array.isArray(res.data)) {
          setBookmarks(res.data.map((b: any) => ({
            _id: b._id,
            reference: b.verseRef?.reference || b.reference || '—',
            text: b.verseRef?.text || b.text || '',
            bookId: b.verseRef?.bookId || '',
            chapterNumber: b.verseRef?.chapterNumber || 0,
            verseNumber: b.verseRef?.verseNumber || 0,
            createdAt: b.createdAt,
          })));
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const handleDelete = async (id: string) => {
    setDeleting(id);
    try {
      await apiFetch(`/api/v1/users/me/bookmarks/${id}`, { method: 'DELETE' });
      setBookmarks(prev => prev.filter(b => b._id !== id));
    } catch {
      // ignore
    } finally {
      setDeleting(null);
    }
  };

  const goToVerse = (bm: VerseBookmark) => {
    if (bm.bookId && bm.chapterNumber) {
      navigate(`/bible/${bm.bookId}/${bm.chapterNumber}`);
    }
  };

  return (
    <PageContainer className="pt-0 pb-24">
      <AppBar title="Bookmarks" onBack={() => navigate('/profile')} />

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="pt-6">
          {bookmarks.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-4">
              <div className="w-20 h-20 rounded-full bg-primary/10 flex items-center justify-center">
                <Bookmark size={36} className="text-primary/40" />
              </div>
              <div className="text-center">
                <p className="text-foreground font-semibold font-sans text-base mb-1">No bookmarks yet</p>
                <p className="text-muted-foreground font-sans text-sm">Tap a verse while reading to bookmark it</p>
              </div>
              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={() => navigate('/bible')}
                className="mt-2 bg-primary text-primary-foreground rounded-2xl px-6 py-3 font-sans font-semibold text-sm shadow-md shadow-primary/20"
              >
                Browse Bible
              </motion.button>
            </div>
          ) : (
            <div className="space-y-3">
              <p className="text-muted-foreground font-sans text-sm px-1 mb-4">
                {bookmarks.length} saved {bookmarks.length === 1 ? 'verse' : 'verses'}
              </p>
              <AnimatePresence>
                {bookmarks.map((bm, index) => (
                  <motion.div
                    key={bm._id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, x: -40 }}
                    transition={{ delay: index * 0.04 }}
                    className="bg-card rounded-[20px] border border-border shadow-sm overflow-hidden"
                  >
                    <motion.button
                      whileTap={{ scale: 0.99 }}
                      onClick={() => goToVerse(bm)}
                      className="w-full p-4 text-left"
                    >
                      <div className="flex items-start gap-3">
                        <div className="w-9 h-9 rounded-xl bg-accent/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                          <BookOpen size={16} className="text-accent" />
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-primary font-semibold font-sans text-sm mb-1">{bm.reference}</p>
                          <p className="text-foreground font-serif text-sm leading-relaxed line-clamp-3">{bm.text}</p>
                        </div>
                      </div>
                    </motion.button>

                    <div className="px-4 pb-3 flex justify-end border-t border-border/50 pt-2">
                      <motion.button
                        whileTap={{ scale: 0.9 }}
                        onClick={() => handleDelete(bm._id)}
                        disabled={deleting === bm._id}
                        className="flex items-center gap-1.5 text-destructive/70 hover:text-destructive font-sans text-xs font-medium transition-colors disabled:opacity-40"
                      >
                        {deleting === bm._id ? (
                          <span className="w-3 h-3 border border-destructive border-t-transparent rounded-full animate-spin" />
                        ) : (
                          <Trash2 size={14} />
                        )}
                        Remove
                      </motion.button>
                    </div>
                  </motion.div>
                ))}
              </AnimatePresence>
            </div>
          )}
        </div>
      )}
    </PageContainer>
  );
}
