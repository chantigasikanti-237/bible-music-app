import { ChevronRight, User, Globe, Palette, Bell, Bookmark, Heart, Info, LogOut, Moon, Sun, CloudDownload, MailWarning, X } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router';
import { PageContainer, Heading2, Text, SettingsRow } from '../components/BibleSystem';
import { apiFetch, clearToken, getToken } from '../lib/api';
import { reportThemeToNativeShell } from '../lib/nativeTheme';
import { setProfile as setSharedProfile, clearProfile } from '../lib/userProfileStore';

interface UserProfile {
  id: string;
  name: string | null;
  email: string;
  photo: string | null;
  emailVerifiedAt: string | null;
}

const settingsGroups = [
  {
    title: 'Account',
    items: [
      { icon: User, label: 'Personal Information', sublabel: 'Name, email, phone', route: '/profile/personal-information' },
      { icon: Bell, label: 'Notifications', sublabel: 'Push, email, reminders', route: '/profile/notifications' },
    ]
  },
  {
    title: 'Preferences',
    items: [
      { icon: Globe, label: 'Language', sublabel: 'English', route: '/profile/language' },
      { icon: Palette, label: 'Theme', sublabel: 'Light', route: null },
    ]
  },
  {
    title: 'Saved',
    items: [
      { icon: Bookmark, label: 'Bookmarks', sublabel: 'Saved verses', route: '/profile/bookmarks' },
      { icon: Heart, label: 'Favorites', sublabel: 'Saved hymns', route: '/profile/favorites' },
    ]
  },
  {
    title: 'Offline',
    items: [
      { icon: CloudDownload, label: 'Bible', sublabel: 'Bible text & audio for offline use', route: '/profile/downloads' },
    ]
  },
  {
    title: 'About',
    items: [
      { icon: Info, label: 'App Information', sublabel: 'Version 1.0.0', route: null },
    ]
  }
];

export function Profile() {
  const navigate = useNavigate();
  const [isDarkMode, setIsDarkMode] = useState(() => document.documentElement.classList.contains('dark'));
  const [user, setUser] = useState<UserProfile | null>(null);

  const [showVerifySheet, setShowVerifySheet] = useState(false);
  const [verifyOtp, setVerifyOtp] = useState('');
  const [sendingCode, setSendingCode] = useState(false);
  const [verifyLoading, setVerifyLoading] = useState(false);
  const [verifyError, setVerifyError] = useState('');
  const [verifyInfo, setVerifyInfo] = useState('');

  useEffect(() => {
    if (!getToken()) return;
    apiFetch<{ success: boolean; data: UserProfile }>('/api/v1/users/me')
      .then(res => {
        if (res.success && res.data) {
          setUser(res.data);
          setSharedProfile(res.data);
        }
      })
      .catch(() => {});
  }, []);

  const handleSignOut = () => {
    clearToken();
    clearProfile();
    navigate('/login');
  };

  const openVerifySheet = async () => {
    setVerifyError('');
    setVerifyInfo('');
    setShowVerifySheet(true);
    setSendingCode(true);
    try {
      const res = await apiFetch<{ message: string }>('/api/v1/auth/verify-email/resend', {
        method: 'POST',
        body: JSON.stringify({ email: user?.email }),
      });
      setVerifyInfo(res.message || 'Check your email for a 6-digit code.');
    } catch (err: any) {
      setVerifyError(err.message || 'Something went wrong');
    } finally {
      setSendingCode(false);
    }
  };

  const confirmVerifyEmail = async () => {
    setVerifyError('');
    setVerifyLoading(true);
    try {
      await apiFetch('/api/v1/auth/verify-email/confirm', {
        method: 'POST',
        body: JSON.stringify({ otpCode: verifyOtp }),
      });
      setShowVerifySheet(false);
      setVerifyOtp('');
      setUser(u => u ? { ...u, emailVerifiedAt: new Date().toISOString() } : u);
    } catch (err: any) {
      setVerifyError(err.message || 'Something went wrong');
    } finally {
      setVerifyLoading(false);
    }
  };

  const displayName = user?.name || user?.email?.split('@')[0] || 'Guest';
  const displayEmail = user?.email || '';

  return (
    <PageContainer className="p-0 pb-24">
      {/* Profile Header — no card container; sits directly on the page
          background (bg-background, from PageContainer) so it reads as
          one continuous surface rather than a boxed panel.
          Mobile: stacked and centered (unchanged). md+ (the same
          breakpoint BottomNav/sidebar already switch on): Instagram-style
          row — avatar/name/sign-in on the left, stats on the right. */}
      <div className="px-4 pt-12 pb-8 md:px-8 md:pt-10 md:pb-10">
        <div className="flex flex-col items-center md:flex-row md:items-center md:justify-between md:max-w-3xl md:mx-auto">
          {/* Left: avatar + name + sign-in */}
          <div className="flex flex-col items-center md:flex-row md:items-center md:gap-5">
            {/* Avatar */}
            <div className="w-24 h-24 rounded-full bg-accent/10 border-4 border-accent/30 overflow-hidden flex items-center justify-center mb-4 md:mb-0 shadow-md">
              {user?.photo ? (
                <img src={user.photo} alt={displayName} className="w-full h-full object-cover" />
              ) : (
                <User size={40} className="text-accent" />
              )}
            </div>

            <div className="flex flex-col items-center md:items-start">
              <Heading2 className="text-foreground mb-1">
                {displayName}
              </Heading2>
              {displayEmail ? (
                <Text className="text-muted-foreground">
                  {displayEmail}
                </Text>
              ) : (
                <motion.button
                  whileTap={{ scale: 0.97 }}
                  onClick={() => navigate('/login')}
                  className="text-accent underline font-sans text-sm mt-1"
                >
                  Sign in
                </motion.button>
              )}
            </div>
          </div>

          {/* Right (md+) / below (mobile): Stats */}
          <div className="flex gap-6 mt-6 w-full justify-center md:mt-0 md:w-auto md:justify-end">
            <div className="text-center">
              <div className="text-foreground mb-1 font-serif text-2xl font-bold">—</div>
              <div className="text-muted-foreground font-sans text-xs uppercase tracking-wider">Day Streak</div>
            </div>
            <div className="w-px bg-border" />
            <div className="text-center">
              <div className="text-foreground mb-1 font-serif text-2xl font-bold">—</div>
              <div className="text-muted-foreground font-sans text-xs uppercase tracking-wider">Chapters</div>
            </div>
            <div className="w-px bg-border" />
            <div className="text-center">
              <div className="text-foreground mb-1 font-serif text-2xl font-bold">—</div>
              <div className="text-muted-foreground font-sans text-xs uppercase tracking-wider">Bookmarks</div>
            </div>
          </div>
        </div>
      </div>

      {/* Verify-email banner */}
      {user && !user.emailVerifiedAt && (
        <div className="mx-4 mt-4 bg-accent/10 border border-accent/30 rounded-2xl p-4 flex items-center gap-3">
          <MailWarning size={20} className="text-accent flex-shrink-0" />
          <div className="flex-1 min-w-0">
            <p className="text-foreground font-sans text-sm font-semibold">Verify your email</p>
            <p className="text-muted-foreground font-sans text-xs">Confirm {user.email} to secure your account</p>
          </div>
          <motion.button
            whileTap={{ scale: 0.96 }}
            onClick={openVerifySheet}
            className="flex-shrink-0 bg-accent text-accent-foreground rounded-xl px-3 py-2 font-sans text-xs font-semibold"
          >
            Verify
          </motion.button>
        </div>
      )}

      {/* Verify-email sheet */}
      <AnimatePresence>
        {showVerifySheet && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setShowVerifySheet(false)}
              className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40"
            />
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="fixed bottom-0 left-0 right-0 bg-card rounded-t-[28px] z-50 shadow-2xl p-6"
            >
              <div className="flex items-center justify-between mb-3">
                <h2 className="text-foreground font-semibold font-sans text-base">Verify your email</h2>
                <motion.button whileTap={{ scale: 0.9 }} onClick={() => setShowVerifySheet(false)} className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
                  <X size={16} className="text-muted-foreground" />
                </motion.button>
              </div>

              {verifyInfo && (
                <p className="text-primary font-sans text-sm bg-primary/10 rounded-xl px-4 py-3 mb-4">{verifyInfo}</p>
              )}

              <label className="block text-foreground font-sans text-sm font-medium mb-1.5">6-digit code</label>
              <input
                type="text"
                inputMode="numeric"
                maxLength={6}
                value={verifyOtp}
                onChange={e => setVerifyOtp(e.target.value.replace(/\D/g, ''))}
                placeholder="123456"
                className="w-full bg-muted rounded-xl px-4 py-3 mb-2 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 font-sans text-base tracking-widest"
              />
              <button type="button" onClick={openVerifySheet} disabled={sendingCode} className="text-primary font-sans text-xs font-semibold hover:underline disabled:opacity-60">
                {sendingCode ? 'Sending…' : 'Resend code'}
              </button>

              {verifyError && (
                <p className="text-destructive font-sans text-sm bg-destructive/10 rounded-xl px-4 py-3 mt-4">{verifyError}</p>
              )}

              <motion.button
                whileTap={{ scale: 0.98 }}
                disabled={verifyLoading || verifyOtp.length !== 6}
                onClick={confirmVerifyEmail}
                className="w-full bg-primary text-primary-foreground rounded-2xl py-4 font-sans font-semibold text-base shadow-md shadow-primary/20 disabled:opacity-60 mt-4"
              >
                {verifyLoading ? 'Verifying…' : 'Verify email'}
              </motion.button>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Settings Groups */}
      <div className="px-4 pt-6 space-y-6">
        {settingsGroups.map((group) => (
          <div key={group.title}>
            <h2 className="text-muted-foreground mb-3 px-2 font-sans text-xs font-semibold uppercase tracking-wider">
              {group.title}
            </h2>

            <div className="bg-card rounded-[24px] shadow-sm border border-border overflow-hidden px-4">
              {group.items.map((item, index) => (
                <div key={item.label} className={index !== group.items.length - 1 ? 'border-b border-border' : ''}>
                  <SettingsRow
                    icon={item.icon}
                    label={item.label}
                    sublabel={item.label === 'Theme' ? (isDarkMode ? 'Dark' : 'Light') : item.sublabel}
                    onClick={item.route ? () => navigate(item.route!) : undefined}
                    rightAction={
                      item.label === 'Theme' ? (
                        <motion.button
                          whileTap={{ scale: 0.9 }}
                          onClick={(e: any) => {
                            e.stopPropagation();
                            const next = !isDarkMode;
                            setIsDarkMode(next);
                            document.documentElement.classList.toggle('dark', next);
                            localStorage.setItem('theme', next ? 'dark' : 'light');
                            reportThemeToNativeShell(next);
                          }}
                          className={`w-14 h-8 rounded-full transition-all relative ${
                            isDarkMode ? 'bg-primary' : 'bg-muted'
                          }`}
                        >
                          <motion.div
                            className="w-6 h-6 bg-card rounded-full shadow-sm flex items-center justify-center absolute top-1 left-1"
                            animate={{ x: isDarkMode ? 24 : 0 }}
                            transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                          >
                            {isDarkMode ? (
                              <Moon size={14} className="text-primary" />
                            ) : (
                              <Sun size={14} className="text-accent" />
                            )}
                          </motion.div>
                        </motion.button>
                      ) : (
                        <ChevronRight size={20} className="text-muted-foreground" />
                      )
                    }
                  />
                </div>
              ))}
            </div>
          </div>
        ))}

        {/* Logout Button */}
        <motion.button
          whileTap={{ scale: 0.98 }}
          onClick={handleSignOut}
          className="w-full bg-card rounded-2xl p-4 flex items-center justify-center gap-3 shadow-sm border border-destructive/20 text-destructive font-semibold font-sans text-base mb-6"
        >
          <LogOut size={20} />
          Sign Out
        </motion.button>
      </div>
    </PageContainer>
  );
}
