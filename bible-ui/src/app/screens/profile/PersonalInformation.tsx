import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router';
import { User, Mail, Edit3, Check, Camera } from 'lucide-react';
import { motion } from 'motion/react';
import { PageContainer, AppBar } from '../../components/BibleSystem';
import { apiFetch, getToken } from '../../lib/api';

interface UserProfile {
  id: string;
  name: string | null;
  email: string;
  photo: string | null;
  preferences: { bibleLanguage: string; songsLanguage: string };
}

const resizeImageToDataUrl = (file: File, maxSize = 400): Promise<string> =>
  new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      const scale = Math.min(1, maxSize / Math.max(img.width, img.height));
      const w = Math.round(img.width * scale);
      const h = Math.round(img.height * scale);
      const canvas = document.createElement('canvas');
      canvas.width = w; canvas.height = h;
      canvas.getContext('2d')!.drawImage(img, 0, 0, w, h);
      URL.revokeObjectURL(url);
      resolve(canvas.toDataURL('image/jpeg', 0.82));
    };
    img.onerror = reject;
    img.src = url;
  });

export function PersonalInformation() {
  const navigate = useNavigate();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [user, setUser] = useState<UserProfile | null>(null);
  const [name, setName] = useState('');
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (!getToken()) { navigate('/login'); return; }
    apiFetch<{ success: boolean; data: UserProfile }>('/api/v1/users/me')
      .then(res => {
        if (res.success) {
          setUser(res.data);
          setName(res.data.name || '');
          setPhotoPreview(res.data.photo || null);
        }
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const handlePhotoSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const resized = await resizeImageToDataUrl(file);
      setPhotoPreview(resized);
      setPhotoFile(file);
    } catch {
      setError('Could not process image');
    }
  };

  const handleSave = async () => {
    setSaving(true); setError('');
    try {
      // Upload photo if changed
      if (photoFile) {
        const resized = await resizeImageToDataUrl(photoFile);
        const blob = await fetch(resized).then(r => r.blob());
        const form = new FormData();
        form.append('photo', blob, 'photo.jpg');
        const token = getToken();
        await fetch('/api/v1/users/me/photo', {
          method: 'POST',
          headers: token ? { Authorization: `Bearer ${token}` } : {},
          body: form,
        }).then(r => r.json());
      }
      // Save name
      if (name.trim()) {
        await apiFetch('/api/v1/users/me', { method: 'PATCH', body: JSON.stringify({ name: name.trim() }) });
      }
      setSaved(true);
      setPhotoFile(null);
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
                onClick={() => fileInputRef.current?.click()}
                className="w-24 h-24 rounded-full bg-gradient-to-br from-accent/20 to-accent/5 border-4 border-accent/30 overflow-hidden flex items-center justify-center shadow-md relative group"
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
                onClick={() => fileInputRef.current?.click()}
                className="absolute -bottom-1 -right-1 w-8 h-8 rounded-full bg-accent text-white flex items-center justify-center shadow-lg border-2 border-background"
              >
                <Camera size={14} />
              </motion.button>
            </div>

            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              className="hidden"
              onChange={handlePhotoSelect}
            />

            <p className="text-muted-foreground font-sans text-sm mt-3">
              {photoFile ? 'New photo selected — tap Save to apply' : 'Tap photo to change'}
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
            disabled={saving || (!name.trim() && !photoFile)}
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
    </PageContainer>
  );
}
