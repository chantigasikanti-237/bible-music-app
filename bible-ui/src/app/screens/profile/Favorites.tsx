import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { Heart, Trash2, Music2 } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { PageContainer, AppBar } from '../../components/BibleSystem';
import { apiFetch, getToken } from '../../lib/api';

interface HymnBookmark {
  _id: string;
  title: string;
  languageCode: string;
  songId: string;
  createdAt: string;
}

export function Favorites() {
  const navigate = useNavigate();
  const [favorites, setFavorites] = useState<HymnBookmark[]>([]);
  const [loading, setLoading] = useState(true);
  const [deleting, setDeleting] = useState<string | null>(null);

  useEffect(() => {
    if (!getToken()) { navigate('/login'); return; }
    apiFetch<{ success: boolean; data: any[] }>('/api/v1/users/me/bookmarks?targetType=song')
      .then(res => {
        if (res.success && Array.isArray(res.data)) {
          setFavorites(res.data.map((b: any) => ({
            _id: b._id,
            title: b.songRef?.title || 'Unknown',
            languageCode: b.songRef?.languageCode || '',
            songId: b.songRef?.songId || '',
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
      setFavorites(prev => prev.filter(f => f._id !== id));
    } catch {
      // ignore
    } finally {
      setDeleting(null);
    }
  };

  return (
    <PageContainer className="pt-0 pb-24">
      <AppBar title="Favourite Hymns" onBack={() => navigate('/profile')} />

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="pt-6">
          {favorites.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-20 gap-4">
              <div className="w-20 h-20 rounded-full bg-accent/10 flex items-center justify-center">
                <Heart size={36} className="text-accent/40" />
              </div>
              <div className="text-center">
                <p className="text-foreground font-semibold font-sans text-base mb-1">No favourites yet</p>
                <p className="text-muted-foreground font-sans text-sm">Tap the heart icon on any hymn to save it</p>
              </div>
              <motion.button
                whileTap={{ scale: 0.97 }}
                onClick={() => navigate('/hymns')}
                className="mt-2 bg-primary text-primary-foreground rounded-2xl px-6 py-3 font-sans font-semibold text-sm shadow-md shadow-primary/20"
              >
                Browse Hymns
              </motion.button>
            </div>
          ) : (
            <div className="space-y-3">
              <p className="text-muted-foreground font-sans text-sm px-1 mb-4">
                {favorites.length} saved {favorites.length === 1 ? 'hymn' : 'hymns'}
              </p>
              <AnimatePresence>
                {favorites.map((fav, index) => (
                  <motion.div
                    key={fav._id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, x: -40 }}
                    transition={{ delay: index * 0.04 }}
                    className="bg-card rounded-[20px] border border-border shadow-sm overflow-hidden"
                  >
                    <div
                      role="button"
                      tabIndex={0}
                      onClick={() => navigate('/hymns', {
                        state: {
                          openHymn: {
                            songId: fav.songId,
                            title: fav.title,
                            languageCode: fav.languageCode || 'en',
                          },
                        },
                      })}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' || e.key === ' ') {
                          e.preventDefault();
                          navigate('/hymns', {
                            state: {
                              openHymn: {
                                songId: fav.songId,
                                title: fav.title,
                                languageCode: fav.languageCode || 'en',
                              },
                            },
                          });
                        }
                      }}
                      className="w-full p-4 flex items-center gap-4 text-left cursor-pointer"
                    >
                      <div className="w-12 h-12 rounded-xl bg-accent/10 flex items-center justify-center flex-shrink-0">
                        <Music2 size={20} className="text-accent" />
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-foreground font-semibold font-sans text-sm truncate">{fav.title}</p>
                        <p className="text-muted-foreground font-sans text-xs capitalize">{fav.languageCode || 'English'}</p>
                      </div>
                      <motion.button
                        whileTap={{ scale: 0.9 }}
                        onClick={(e) => { e.stopPropagation(); handleDelete(fav._id); }}
                        disabled={deleting === fav._id}
                        className="w-9 h-9 rounded-full bg-destructive/10 flex items-center justify-center text-destructive disabled:opacity-40"
                      >
                        {deleting === fav._id ? (
                          <span className="w-3 h-3 border border-destructive border-t-transparent rounded-full animate-spin" />
                        ) : (
                          <Trash2 size={15} />
                        )}
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
