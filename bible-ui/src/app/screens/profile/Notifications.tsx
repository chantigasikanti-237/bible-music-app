import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { Bell, BookOpen, Music, Clock, Star } from 'lucide-react';
import { motion } from 'motion/react';
import { PageContainer, AppBar } from '../../components/BibleSystem';

const STORAGE_KEY = 'notification_prefs';

const defaultPrefs = {
  dailyVerse: true,
  readingReminder: true,
  newSongs: false,
  weeklyReview: true,
};

interface NotifPref {
  key: keyof typeof defaultPrefs;
  icon: React.ElementType;
  label: string;
  sublabel: string;
}

const items: NotifPref[] = [
  { key: 'dailyVerse', icon: Star, label: 'Daily Verse', sublabel: 'Morning verse of the day' },
  { key: 'readingReminder', icon: Clock, label: 'Reading Reminder', sublabel: 'Remind to read at your set time' },
  { key: 'newSongs', icon: Music, label: 'New Songs', sublabel: 'When new worship songs are added' },
  { key: 'weeklyReview', icon: BookOpen, label: 'Weekly Review', sublabel: 'Your reading progress summary' },
];

export function Notifications() {
  const navigate = useNavigate();
  const [prefs, setPrefs] = useState(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      return stored ? { ...defaultPrefs, ...JSON.parse(stored) } : defaultPrefs;
    } catch { return defaultPrefs; }
  });

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
  }, [prefs]);

  const toggle = (key: keyof typeof defaultPrefs) => {
    setPrefs(prev => ({ ...prev, [key]: !prev[key] }));
  };

  return (
    <PageContainer className="pt-0 pb-24">
      <AppBar title="Notifications" onBack={() => navigate('/profile')} />

      <div className="pt-6 space-y-4">
        <p className="text-muted-foreground font-sans text-sm px-1">
          Choose which notifications you want to receive.
        </p>

        <div className="bg-card rounded-[24px] border border-border shadow-sm overflow-hidden px-4">
          {items.map((item, index) => {
            const Icon = item.icon;
            const enabled = prefs[item.key];
            return (
              <div key={item.key} className={index !== items.length - 1 ? 'border-b border-border' : ''}>
                <div className="flex items-center gap-4 py-4">
                  <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center flex-shrink-0">
                    <Icon size={20} className="text-primary" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-foreground font-semibold font-sans text-sm mb-0.5">{item.label}</h3>
                    <p className="text-muted-foreground font-sans text-xs">{item.sublabel}</p>
                  </div>
                  <motion.button
                    whileTap={{ scale: 0.9 }}
                    onClick={() => toggle(item.key)}
                    className={`w-14 h-8 rounded-full transition-all relative flex-shrink-0 ${enabled ? 'bg-primary' : 'bg-muted'}`}
                  >
                    <motion.div
                      className="w-6 h-6 bg-card rounded-full shadow-sm absolute top-1 left-1"
                      animate={{ x: enabled ? 24 : 0 }}
                      transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                    />
                  </motion.button>
                </div>
              </div>
            );
          })}
        </div>

        <div className="bg-card rounded-[24px] border border-border shadow-sm p-5">
          <div className="flex items-start gap-3">
            <Bell size={18} className="text-accent mt-0.5 flex-shrink-0" />
            <p className="text-muted-foreground font-sans text-sm leading-relaxed">
              Make sure notifications are allowed in your browser or device settings for these to work.
            </p>
          </div>
        </div>
      </div>
    </PageContainer>
  );
}
