import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router';
import { User, Mail, Edit3, Check, Camera, Image as ImageIcon } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { PageContainer, AppBar } from '../../components/BibleSystem';
import { apiFetch, getToken } from '../../lib/api';
import { setProfile as setSharedProfile } from '../../lib/userProfileStore';
import { PhotoCropSheet } from '../../components/PhotoCropSheet';

interface UserProfile {
  id: string;
  name: string | null;
  email: string;
  photo: string | null;
  emailVerifiedAt: string | null;
  preferences: { bibleLanguage: string; songsLanguage: string };
}

// This gates the raw photo picked from camera/library, before cropping —
// not what actually gets uploaded. Modern phone photos commonly run
// 3-15MB, so a low cap here would reject normal photos before the user
// ever reaches the crop screen. The crop step always compresses the final
// output down to a small fixed-size JPEG regardless of source size, so
// the server-side upload limit (5MB, in userController.js) is untouched —
// that's plenty for the actual compressed payload.
const MAX_PHOTO_BYTES = 20 * 1024 * 1024; // 20MB
const ALLOWED_PHOTO_TYPES = ['image/png', 'image/jpeg', 'image/webp'];

export function PersonalInformation() {
  const navigate = useNavigate();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);
  const [user, setUser] = useState<UserProfile | null>(null);
  const [name, setName] = useState('');
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const [croppedDataUrl, setCroppedDataUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');
  const [showSourceSheet, setShowSourceSheet] = useState(false);
  const [cropSourceUrl, setCropSourceUrl] = useState<string | null>(null);

  useEffect(() => {
    if (!getToken()) { navigate('/login'); return; }
    apiFetch<{ success: boolean; data: UserProfile }>('/api/v1/users/me')
      .then(res => {
        if (res.success) {
          setUser(res.data);
          setName(res.data.name || '');
          setPhotoPreview(res.data.photo || null);
          setSharedProfile(res.data);
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const handlePhotoSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ''; // allow re-selecting the same file next time
    if (!file) return;

    if (!ALLOWED_PHOTO_TYPES.includes(file.type)) {
      setError('Only PNG, JPG, and WEBP images are allowed');
      return;
    }
    if (file.size > MAX_PHOTO_BYTES) {
      setError('Image must be smaller than 20MB');
      return;
    }

    setError('');
    setCropSourceUrl(URL.createObjectURL(file));
  };

  const handleCropCancel = () => {
    if (cropSourceUrl) URL.revokeObjectURL(cropSourceUrl);
    setCropSourceUrl(null);
  };

  const handleCropDone = (dataUrl: string) => {
    if (cropSourceUrl) URL.revokeObjectURL(cropSourceUrl);
    setCropSourceUrl(null);
    setPhotoPreview(dataUrl);
    setCroppedDataUrl(dataUrl);
  };

  const handleSave = async () => {
    setSaving(true); setError('');
    try {
      // Both endpoints return the complete updated user (not just the
      // changed field), so the shared store gets a full, authoritative
      // replace each time — no partial-merge state to get out of sync.
      let latestUser: UserProfile | null = null;

      // Upload photo if changed
      if (croppedDataUrl) {
        const blob = await fetch(croppedDataUrl).then(r => r.blob());
        const form = new FormData();
        form.append('photo', blob, 'photo.jpg');
        const token = getToken();
        const photoRes = await fetch('/api/v1/users/me/photo', {
          method: 'POST',
          headers: token ? { Authorization: `Bearer ${token}` } : {},
          body: form,
        }).then(r => r.json()) as { success: boolean; data: UserProfile };
        if (photoRes.success) latestUser = photoRes.data;
      }
      // Save name
      if (name.trim()) {
        const nameRes = await apiFetch<{ success: boolean; data: UserProfile }>('/api/v1/users/me', {
          method: 'PATCH',
          body: JSON.stringify({ name: name.trim() }),
        });
        if (nameRes.success) latestUser = nameRes.data;
      }

      if (latestUser) {
        setUser(latestUser);
        setSharedProfile(latestUser);
      }
      setSaved(true);
      setCroppedDataUrl(null);
      setTimeout(() => setSaved(false), 2000);
    } catch (e: any) {
      setError(e.message || 'Failed to save');
    } finally {
      setSaving(false);
    }
  };

  return (
    <PageContainer className="pt-0 pb-24">
      <AppBar title="Personal Information" onBack={() => navigate('/profile')} />

      {loading ? (
        <div className="flex items-center justify-center py-16">
          <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="pt-8 space-y-6">
          {/* Avatar */}
          <div className="flex flex-col items-center mb-8">
            <div className="relative">
              <motion.button
                whileTap={{ scale: 0.95 }}
                onClick={() => setShowSourceSheet(true)}
                className="w-24 h-24 rounded-full bg-gradient-to-br from-accent/20 to-accent/5 border-4 border-accent/30 overflow-hidden flex items-center justify-center shadow-md relative group cursor-pointer"
              >
                {photoPreview ? (
                  <img src={photoPreview} alt="Profile" className="w-full h-full object-cover" />
                ) : (
                  <User size={40} className="text-accent" />
                )}
                {/* Overlay on hover */}
                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity rounded-full flex items-center justify-center">
                  <Camera size={22} className="text-white" />
                </div>
              </motion.button>

              {/* Camera badge — bg-accent (muted gold) rather than bg-primary:
                  --accent is the same warm gold in both light and dark themes,
                  so this stays a deliberate premium touch instead of flipping
                  to a flat light-grey blob against the dark background. */}
              <motion.button
                whileTap={{ scale: 0.9 }}
                onClick={() => setShowSourceSheet(true)}
                className="absolute -bottom-1 -right-1 w-8 h-8 rounded-full bg-accent text-white flex items-center justify-center shadow-lg border-2 border-background cursor-pointer"
              >
                <Camera size={14} />
              </motion.button>
            </div>

            <input
              ref={fileInputRef}
              type="file"
              accept="image/png, image/jpeg, image/webp"
              className="hidden"
              onChange={handlePhotoSelect}
            />
            <input
              ref={cameraInputRef}
              type="file"
              accept="image/png, image/jpeg, image/webp"
              capture="user"
              className="hidden"
              onChange={handlePhotoSelect}
            />

            <p className="text-muted-foreground font-sans text-sm mt-3">
              {croppedDataUrl ? 'New photo selected — tap Save to apply' : 'Tap photo to change'}
            </p>
          </div>

          {/* Fields */}
          <div className="bg-card rounded-[24px] border border-border shadow-sm p-6 space-y-5">
            <div>
              <label className="block text-muted-foreground font-sans text-xs font-semibold uppercase tracking-wider mb-2">
                Full Name
              </label>
              <div className="relative">
                <input
                  type="text"
                  value={name}
                  onChange={e => setName(e.target.value)}
                  placeholder="Enter your name"
                  className="w-full bg-muted rounded-xl px-4 py-3 pr-10 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 font-sans text-base"
                />
                <Edit3 size={16} className="absolute right-4 top-1/2 -translate-y-1/2 text-muted-foreground" />
              </div>
            </div>

            <div>
              <label className="block text-muted-foreground font-sans text-xs font-semibold uppercase tracking-wider mb-2">
                Email Address
              </label>
              <div className="flex items-center gap-3 bg-muted/50 rounded-xl px-4 py-3 border border-border">
                <Mail size={16} className="text-muted-foreground flex-shrink-0" />
                <span className="text-foreground font-sans text-base flex-1 truncate">{user?.email || '—'}</span>
                <span className="text-muted-foreground font-sans text-xs bg-muted px-2 py-0.5 rounded-full">Verified</span>
              </div>
              <p className="text-muted-foreground font-sans text-xs mt-1.5 px-1">Email cannot be changed</p>
            </div>
          </div>

          {error && (
            <p className="text-destructive bg-destructive/10 rounded-xl px-4 py-3 font-sans text-sm">{error}</p>
          )}

          <motion.button
            whileTap={{ scale: 0.98 }}
            onClick={handleSave}
            disabled={saving || (!name.trim() && !croppedDataUrl)}
            className="w-full bg-primary text-primary-foreground rounded-2xl py-4 font-sans font-semibold text-base shadow-md shadow-primary/20 disabled:opacity-60 flex items-center justify-center gap-2"
          >
            {saving ? (
              <span className="w-5 h-5 border-2 border-primary-foreground border-t-transparent rounded-full animate-spin" />
            ) : saved ? (
              <><Check size={18} /> Saved!</>
            ) : 'Save Changes'}
          </motion.button>
        </div>
      )}

      {/* Choose Photo Source — Take Photo / Choose from Library / Cancel */}
      <AnimatePresence>
        {showSourceSheet && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setShowSourceSheet(false)}
              className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40"
            />
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="fixed bottom-0 left-0 right-0 bg-card rounded-t-[28px] z-50 shadow-2xl p-4 pb-8"
            >
              <div className="w-12 h-1 bg-muted rounded-full mx-auto mb-4" />
              <h2 className="text-foreground font-semibold font-sans text-base text-center mb-4">Update Profile Photo</h2>
              <div className="space-y-2">
                <button
                  onClick={() => { setShowSourceSheet(false); cameraInputRef.current?.click(); }}
                  className="w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl bg-muted/50 hover:bg-muted transition-colors cursor-pointer"
                >
                  <div className="w-10 h-10 rounded-full bg-accent/10 flex items-center justify-center flex-shrink-0">
                    <Camera size={18} className="text-accent" />
                  </div>
                  <span className="text-foreground font-sans text-sm font-medium">Take Photo</span>
                </button>
                <button
                  onClick={() => { setShowSourceSheet(false); fileInputRef.current?.click(); }}
                  className="w-full flex items-center gap-3 px-4 py-3.5 rounded-2xl bg-muted/50 hover:bg-muted transition-colors cursor-pointer"
                >
                  <div className="w-10 h-10 rounded-full bg-accent/10 flex items-center justify-center flex-shrink-0">
                    <ImageIcon size={18} className="text-accent" />
                  </div>
                  <span className="text-foreground font-sans text-sm font-medium">Choose from Library</span>
                </button>
                <button
                  onClick={() => setShowSourceSheet(false)}
                  className="w-full text-center px-4 py-3.5 rounded-2xl bg-muted/50 hover:bg-muted transition-colors text-muted-foreground font-sans text-sm font-semibold cursor-pointer mt-1"
                >
                  Cancel
                </button>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      {/* Crop — pan/zoom the selected photo before it's applied */}
      <AnimatePresence>
        {cropSourceUrl && (
          <PhotoCropSheet imageUrl={cropSourceUrl} onCancel={handleCropCancel} onDone={handleCropDone} />
        )}
      </AnimatePresence>
    </PageContainer>
  );
}
