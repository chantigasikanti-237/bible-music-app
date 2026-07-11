import { useNavigate, useParams } from 'react-router';
import { ChevronLeft, Play, Heart, MoreVertical } from 'lucide-react';
import { motion } from 'motion/react';
import { useState } from 'react';
import { PageContainer } from '../components/BibleSystem';

const playlistSongs = [
  { id: 1, title: 'Amazing Grace', artist: 'John Newton', duration: '4:32' },
  { id: 2, title: 'How Great Is Our God', artist: 'Chris Tomlin', duration: '4:45' },
  { id: 3, title: 'Blessed Assurance', artist: 'Fanny Crosby', duration: '3:58' },
  { id: 4, title: 'Oceans (Where Feet May Fail)', artist: 'Hillsong United', duration: '8:59' },
  { id: 5, title: 'Great Are You Lord', artist: 'All Sons & Daughters', duration: '6:28' },
  { id: 6, title: 'It Is Well', artist: 'Kristene DiMarco', duration: '5:12' },
];

export function PlaylistDetail() {
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  const [favorites, setFavorites] = useState<number[]>([2]);

  const toggleFavorite = (songId: number) => {
    setFavorites(prev =>
      prev.includes(songId) ? prev.filter(fav => fav !== songId) : [...prev, songId]
    );
  };

  return (
    <PageContainer className="p-0 pb-24">
      {/* Header with Cover */}
      <div className="relative">
        <div className="bg-gradient-to-b from-primary via-primary/90 to-background pt-12 pb-32 px-4">
          <button
            onClick={() => navigate('/songs')}
            className="mb-6 flex items-center gap-2 text-primary-foreground/90 active:scale-95 transition-transform"
          >
            <ChevronLeft size={24} />
          </button>

          {/* Playlist Cover */}
          <div className="w-48 h-48 mx-auto mb-6 rounded-[24px] bg-white/10 backdrop-blur-xl flex items-center justify-center shadow-2xl border border-white/20">
            <span className="text-white font-serif font-bold text-7xl">
              W
            </span>
          </div>

          {/* Playlist Info */}
          <h1 className="text-primary-foreground text-center mb-2 font-serif font-bold text-3xl tracking-tight">
            Worship Favorites
          </h1>
          <p className="text-primary-foreground/80 text-center font-sans text-sm">
            {playlistSongs.length} songs • 32 minutes
          </p>
        </div>

        {/* Play Button Overlay */}
        <div className="absolute bottom-0 left-0 right-0 px-4 translate-y-1/2">
          <motion.button
            whileTap={{ scale: 0.97 }}
            className="w-full bg-accent text-accent-foreground py-4 rounded-2xl font-bold shadow-xl shadow-accent/30 flex items-center justify-center gap-3 font-sans text-base"
          >
            <Play size={20} fill="currentColor" />
            Play All
          </motion.button>
        </div>
      </div>

      {/* Songs List */}
      <div className="px-4 pt-16">
        <div className="space-y-3">
          {playlistSongs.map((song, index) => (
            <motion.div
              key={song.id}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.05 }}
              className="bg-card rounded-2xl p-4 flex items-center gap-4 shadow-sm border border-border"
            >
              {/* Track Number */}
              <div className="w-8 text-center flex-shrink-0">
                <span className="text-muted-foreground font-semibold font-sans text-sm">
                  {index + 1}
                </span>
              </div>

              {/* Song Info */}
              <div className="flex-1 min-w-0">
                <h3 className="text-foreground font-semibold mb-1 truncate font-sans text-sm">
                  {song.title}
                </h3>
                <p className="text-muted-foreground truncate font-sans text-xs">
                  {song.artist}
                </p>
              </div>

              {/* Duration and Actions */}
              <div className="flex items-center gap-2">
                <span className="text-muted-foreground font-sans text-xs mr-2">
                  {song.duration}
                </span>

                <motion.button
                  whileTap={{ scale: 0.9 }}
                  onClick={() => toggleFavorite(song.id)}
                  className="w-10 h-10 rounded-full bg-muted flex items-center justify-center"
                >
                  <Heart
                    size={18}
                    className={favorites.includes(song.id) ? 'text-accent fill-accent' : 'text-muted-foreground'}
                  />
                </motion.button>

                <motion.button
                  whileTap={{ scale: 0.9 }}
                  className="w-10 h-10 rounded-full bg-muted flex items-center justify-center"
                >
                  <MoreVertical size={18} className="text-muted-foreground" />
                </motion.button>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
    </PageContainer>
  );
}
