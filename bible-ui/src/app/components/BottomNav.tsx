import { useState, useEffect, useSyncExternalStore } from 'react';
import { useNavigate, useLocation } from 'react-router';
import { motion, AnimatePresence } from 'motion/react';
import { Music2 } from 'lucide-react';
import { apiFetch, getToken } from '../lib/api';
import { subscribe as subscribeProfile, getProfileSnapshot, setProfile as setSharedProfile, type UserProfileSnapshot } from '../lib/userProfileStore';
import { subscribe as subscribePlayer, getSnapshot as getPlayerSnapshot } from '../lib/playerStore';

/* ── Icons ─────────────────────────────────────────────────── */

const HomeIcon = ({ size = 24, className = '', strokeWidth = 1.6 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" className={className}>
    <path d="M3 9.5L12 3l9 6.5V20a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V9.5z" />
    <path d="M9 21V12h6v9" />
  </svg>
);

// Closed book — inactive Bible state
const ClosedBookIcon = ({ size = 24, className = '', strokeWidth = 1.6 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" className={className}>
    <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
    <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
    <path d="M9 7h6" />
    <path d="M9 11h8" />
  </svg>
);

// Open book — active Bible state
const OpenBookIcon = ({ size = 24, className = '', strokeWidth = 1.6 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" className={className}>
    <path d="M2 6C2 6 6 4 12 6c6-2 10 0 10 0v14s-4-2-10 0C6 18 2 20 2 20V6z" />
    <line x1="12" y1="6" x2="12" y2="20" />
    <path d="M7 9h3" />
    <path d="M7 12h3" />
    <path d="M14 9h3" />
    <path d="M14 12h3" />
  </svg>
);

// Animated bible: flip closed→open on active
const AnimatedBibleIcon = ({ size = 24, className = '', strokeWidth = 1.6, isActive = false }) => (
  <div style={{ perspective: '300px', width: size, height: size }}>
    <AnimatePresence mode="wait" initial={false}>
      {isActive ? (
        <motion.span key="open"
          initial={{ rotateY: -90, opacity: 0 }}
          animate={{ rotateY: 0, opacity: 1 }}
          exit={{ rotateY: 90, opacity: 0 }}
          transition={{ duration: 0.22, ease: 'easeOut' }}
          style={{ display: 'block', transformOrigin: 'center' }}>
          <OpenBookIcon size={size} className={className} strokeWidth={strokeWidth} />
        </motion.span>
      ) : (
        <motion.span key="closed"
          initial={{ rotateY: 90, opacity: 0 }}
          animate={{ rotateY: 0, opacity: 1 }}
          exit={{ rotateY: -90, opacity: 0 }}
          transition={{ duration: 0.22, ease: 'easeOut' }}
          style={{ display: 'block', transformOrigin: 'center' }}>
          <ClosedBookIcon size={size} className={className} strokeWidth={strokeWidth} />
        </motion.span>
      )}
    </AnimatePresence>
  </div>
);

// Music note — inactive state
const MusicIcon = ({ size = 24, className = '', strokeWidth = 1.6 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" className={className}>
    <ellipse cx="7" cy="17" rx="3" ry="2.2" transform="rotate(-15 7 17)" />
    <ellipse cx="17" cy="14" rx="3" ry="2.2" transform="rotate(-15 17 14)" />
    <path d="M9.5 16.8V4.5" />
    <path d="M19.5 13.8V2.5" />
    <path d="M9.5 4.5 Q14.5 6.5 19.5 2.5" />
    <path d="M9.5 8.5 Q14.5 10.5 19.5 6.5" />
  </svg>
);

// Soundwave equalizer bars.
// paused=true → bars freeze at mid-height; paused=false → bars animate.
const SoundwaveIcon = ({ size = 24, className = '', paused = false }) => {
  const barW = Math.max(2, Math.round(size * 0.14));
  const max = size - 4;
  const bars = [
    { h: [max * 0.15, max * 0.95, max * 0.20, max * 0.75, max * 0.15], mid: max * 0.45, dur: 0.75 },
    { h: [max * 0.80, max * 0.15, max * 1.00, max * 0.30, max * 0.80], mid: max * 0.55, dur: 0.62 },
    { h: [max * 0.25, max * 0.90, max * 0.20, max * 1.00, max * 0.25], mid: max * 0.50, dur: 0.85 },
    { h: [max * 1.00, max * 0.20, max * 0.70, max * 0.10, max * 1.00], mid: max * 0.40, dur: 0.70 },
  ];
  return (
    <div
      className={`flex items-end justify-center gap-[2px] ${className}`}
      style={{ width: size, height: size, paddingBottom: 2, overflow: 'hidden' }}
    >
      {bars.map(({ h, mid, dur }, i) => (
        <motion.div
          key={i}
          className="rounded-full bg-current flex-shrink-0"
          style={{ width: barW }}
          animate={{ height: paused ? mid : h }}
          transition={paused ? { duration: 0.3, ease: 'easeOut' } : {
            duration: dur,
            repeat: Infinity,
            repeatType: 'loop',
            delay: i * 0.14,
            ease: 'easeInOut',
          }}
        />
      ))}
    </div>
  );
};

// Animated music icon:
//   playing  → animated soundwave bars
//   active but paused → static music note (active colour)
//   inactive → static music note (muted colour)
const AnimatedMusicIcon = ({ size = 24, className = '', strokeWidth = 1.6, isActive = false, isPlaying = false }) => (
  <div style={{ perspective: '300px', width: size, height: size }}>
    <AnimatePresence mode="wait" initial={false}>
      {isActive && isPlaying ? (
        <motion.span key="wave"
          initial={{ rotateY: -90, opacity: 0 }}
          animate={{ rotateY: 0, opacity: 1 }}
          exit={{ rotateY: 90, opacity: 0 }}
          transition={{ duration: 0.22, ease: 'easeOut' }}
          style={{ display: 'block', transformOrigin: 'center' }}>
          <SoundwaveIcon size={size} className={className} paused={false} />
        </motion.span>
      ) : (
        <motion.span key="note"
          initial={{ rotateY: 90, opacity: 0 }}
          animate={{ rotateY: 0, opacity: 1 }}
          exit={{ rotateY: -90, opacity: 0 }}
          transition={{ duration: 0.22, ease: 'easeOut' }}
          style={{ display: 'block', transformOrigin: 'center' }}>
          <MusicIcon size={size} className={className} strokeWidth={strokeWidth} />
        </motion.span>
      )}
    </AnimatePresence>
  </div>
);


const ProfileIcon = ({ size = 24, className = '', strokeWidth = 1.6 }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
    strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round" className={className}>
    <circle cx="12" cy="8" r="4" />
    <path d="M4 20c0-4 3.6-7 8-7s8 3 8 7" />
  </svg>
);

/* ── Nav config ─────────────────────────────────────────────── */

interface NavItem {
  id: string;
  label: string;
  Icon: React.FC<{ size?: number; className?: string; strokeWidth?: number }>;
  path: string;
  mobileHidden?: boolean;
}

const navItems: NavItem[] = [
  { id: 'home',    label: 'Home',    Icon: HomeIcon,    path: '/'       },
  { id: 'bible',   label: 'Bible',   Icon: OpenBookIcon, path: '/bible'  },
  { id: 'hymns',   label: 'Hymns',   Icon: Music2,      path: '/hymns',  mobileHidden: true },
  { id: 'songs',   label: 'Music',   Icon: MusicIcon,   path: '/songs'  },
  { id: 'profile', label: 'Profile', Icon: ProfileIcon, path: '/profile'},
];

const mobileNavItems = navItems.filter(i => !i.mobileHidden);

/* ── Component ──────────────────────────────────────────────── */

export function BottomNav() {
  const navigate  = useNavigate();
  const location  = useLocation();
  const [activeTab, setActiveTab] = useState('home');
  const [searchExpanded, setSearchExpanded] = useState(false);
  const profile = useSyncExternalStore(subscribeProfile, getProfileSnapshot);
  const playerSnap = useSyncExternalStore(subscribePlayer, getPlayerSnapshot);
  const playerOpen = playerSnap.expanded;
  const songPlaying = playerSnap.isPlaying;

  // Populates the sidebar/pill nav avatar as soon as the app loads with a
  // valid session, rather than waiting for the user to first visit Profile
  // or Personal Information (those screens also write to this same store,
  // so a photo/name change there reflects here immediately without a
  // remount — this nav persists across navigation, they don't).
  useEffect(() => {
    if (!getToken()) return;
    apiFetch<{ success: boolean; data: UserProfileSnapshot }>('/api/v1/users/me')
      .then(res => {
        if (res.success && res.data) setSharedProfile(res.data);
      })
      .catch(() => {});
  }, []);

  useEffect(() => {
    const matched = navItems.find(item =>
      item.path === '/' ? location.pathname === '/' : location.pathname.startsWith(item.path)
    );
    if (matched) setActiveTab(matched.id);
  }, [location.pathname]);

  useEffect(() => {
    const handler = (e: Event) => setSearchExpanded((e as CustomEvent<boolean>).detail);
    window.addEventListener('search-expanded', handler);
    return () => window.removeEventListener('search-expanded', handler);
  }, []);

  // The pill nav only makes sense on a tab's root screen — any deeper route
  // (Bible chapter/reading, Profile sub-pages, playlist detail, etc.) is a
  // "sub screen" and should hide it, same as the expanded music player does.
  const topLevelPaths = ['/', '/bible', '/hymns', '/songs', '/profile'];
  const isSubScreen = !topLevelPaths.includes(location.pathname);

  return (
    <>
      {/* ── Mobile bottom pill nav (hidden on md+) ───────────────── */}
      {!isSubScreen && (
        <motion.div
          className="md:hidden fixed bottom-6 left-4 right-4 z-50 pointer-events-none"
          animate={{ y: playerOpen || searchExpanded ? 120 : 0, opacity: playerOpen || searchExpanded ? 0 : 1 }}
          transition={{ type: 'spring', damping: 28, stiffness: 280 }}
          style={{ pointerEvents: playerOpen || searchExpanded ? 'none' : undefined }}
        >
          <nav className="max-w-md mx-auto bg-[#F6F1E7] dark:bg-card border border-[var(--primary)]/10 shadow-[0_8px_32px_rgba(44,44,44,0.12)] dark:shadow-[0_8px_32px_rgba(0,0,0,0.4)] backdrop-blur-xl rounded-[2rem] px-2 py-2 pointer-events-auto flex items-center justify-around">
            {mobileNavItems.map((item) => {
              const isActive = activeTab === item.id;
              return (
                <button
                  key={item.id}
                  onClick={() => { setActiveTab(item.id); navigate(item.path); }}
                  className="relative flex flex-col items-center justify-center outline-none w-[58px] h-[56px]"
                  style={{ WebkitTapHighlightColor: 'transparent' }}
                >
                  {isActive ? (
                    <motion.div layoutId="activeChip"
                      className="w-12 h-10 rounded-xl bg-[var(--primary)] flex items-center justify-center shadow-md shadow-[var(--primary)]/30"
                      initial={false} transition={{ type: 'spring', stiffness: 450, damping: 32 }}>
                      {item.id === 'bible' ? (
                        <AnimatedBibleIcon size={20} className="text-primary-foreground" strokeWidth={1.8} isActive />
                      ) : item.id === 'songs' ? (
                        <AnimatedMusicIcon size={20} className="text-primary-foreground" strokeWidth={1.8} isActive isPlaying={songPlaying} />
                      ) : item.id === 'profile' && profile?.photo ? (
                        <img src={profile.photo} alt="Profile" className="w-6 h-6 rounded-full object-cover" />
                      ) : (
                        <item.Icon size={20} className="text-primary-foreground" strokeWidth={1.8} />
                      )}
                    </motion.div>
                  ) : (
                    <div className="w-12 h-10 flex items-center justify-center">
                      {item.id === 'bible' ? (
                        <AnimatedBibleIcon size={22} className="text-[var(--muted-foreground)]" strokeWidth={1.6} isActive={false} />
                      ) : item.id === 'songs' ? (
                        <AnimatedMusicIcon size={22} className="text-[var(--muted-foreground)]" strokeWidth={1.6} isActive={false} />
                      ) : item.id === 'profile' && profile?.photo ? (
                        <img src={profile.photo} alt="Profile" className="w-[22px] h-[22px] rounded-full object-cover" />
                      ) : (
                        <item.Icon size={22} className="text-[var(--muted-foreground)]" strokeWidth={1.6} />
                      )}
                    </div>
                  )}
                  <AnimatePresence mode="popLayout">
                    {isActive && (
                      <motion.span
                        initial={{ opacity: 0, y: 3 }} animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0, y: 3 }} transition={{ duration: 0.18 }}
                        className="text-[10px] font-semibold text-[var(--primary)] mt-0.5 leading-none"
                      >{item.label}</motion.span>
                    )}
                  </AnimatePresence>
                </button>
              );
            })}
          </nav>
        </motion.div>
      )}

      {/* ── Desktop / Tablet sidebar (hidden on mobile) ──────────── */}
      <div className="hidden md:flex fixed left-0 top-0 bottom-0 w-[72px] xl:w-[220px] z-50 flex-col bg-[#F6F1E7] dark:bg-card border-r border-[var(--primary)]/10 shadow-[2px_0_20px_rgba(44,44,44,0.07)] dark:shadow-[2px_0_20px_rgba(0,0,0,0.4)]">

        {/* Nav items — start from top, no branding */}
        <nav className="flex-1 px-2 pt-6 pb-4 space-y-1 overflow-y-auto">
          {navItems.map((item) => {
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => { setActiveTab(item.id); navigate(item.path); }}
                className={`w-full flex items-center gap-3 px-3 py-3.5 rounded-2xl transition-all outline-none ${
                  isActive
                    ? 'bg-[var(--primary)] text-primary-foreground shadow-md shadow-[var(--primary)]/20'
                    : 'text-[var(--primary)]/55 hover:bg-[var(--primary)]/8 hover:text-[var(--primary)]'
                }`}
                style={{ WebkitTapHighlightColor: 'transparent' }}
              >
                <div className="flex-shrink-0 flex items-center justify-center w-6 h-6">
                  {item.id === 'bible' ? (
                    <AnimatedBibleIcon size={22} className="text-current" strokeWidth={isActive ? 1.8 : 1.6} isActive={isActive} />
                  ) : item.id === 'songs' ? (
                    <AnimatedMusicIcon size={22} className="text-current" strokeWidth={isActive ? 1.8 : 1.6} isActive={isActive} isPlaying={songPlaying} />
                  ) : item.id === 'profile' && profile?.photo ? (
                    <img src={profile.photo} alt="Profile" className="w-6 h-6 rounded-full object-cover" />
                  ) : (
                    <item.Icon size={22} className="text-current" strokeWidth={isActive ? 1.8 : 1.6} />
                  )}
                </div>
                <span className="hidden xl:block font-sans font-semibold text-sm whitespace-nowrap">{item.label}</span>
              </button>
            );
          })}
        </nav>

        {/* Now-playing indicator at bottom of sidebar */}
        <AnimatePresence>
          {songPlaying && (
            <motion.div
              initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: 8 }}
              className="px-2 pb-4 flex-shrink-0"
            >
              <div className="flex items-center gap-2 px-3 py-2.5 rounded-2xl bg-[var(--primary)]/8">
                <SoundwaveIcon size={18} className="text-[var(--primary)] flex-shrink-0" paused={false} />
                <span className="hidden xl:block text-[var(--primary)] font-sans text-xs font-semibold truncate">Now Playing</span>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </>
  );
}
