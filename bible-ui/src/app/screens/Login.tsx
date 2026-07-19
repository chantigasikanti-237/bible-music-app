import { useState } from 'react';
import { useNavigate } from 'react-router';
import { motion } from 'motion/react';
import { Eye, EyeOff, BookOpen, ChevronLeft } from 'lucide-react';
import { setToken, apiFetch } from '../lib/api';

type Mode = 'login' | 'register' | 'forgot-request' | 'forgot-confirm' | 'verify-email';

export function Login() {
  const navigate = useNavigate();
  const [mode, setMode] = useState<Mode>('login');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');

  // Forgot-password flow
  const [otpCode, setOtpCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmNewPassword, setConfirmNewPassword] = useState('');
  const [showNewPassword, setShowNewPassword] = useState(false);

  const goToForgotPassword = () => {
    setError('');
    setInfo('');
    setMode('forgot-request');
  };

  const backToSignIn = () => {
    setError('');
    setInfo('');
    setOtpCode('');
    setNewPassword('');
    setConfirmNewPassword('');
    setMode('login');
  };

  const handleForgotRequest = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const res = await apiFetch<{ message: string }>('/api/v1/auth/password-reset/request', {
        method: 'POST',
        body: JSON.stringify({ email }),
      });
      setInfo(res.message || 'If the account exists, a reset code has been sent to your email.');
      setMode('forgot-confirm');
    } catch (err: any) {
      setError(err.message || 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  const handleForgotConfirm = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    if (newPassword !== confirmNewPassword) {
      setError('Passwords do not match');
      return;
    }
    setLoading(true);
    try {
      await apiFetch('/api/v1/auth/password-reset/confirm', {
        method: 'POST',
        body: JSON.stringify({ otpCode, password: newPassword, confirmPassword: confirmNewPassword }),
      });
      setPassword('');
      setOtpCode('');
      setNewPassword('');
      setConfirmNewPassword('');
      setInfo('Password reset successful. Please sign in.');
      setMode('login');
    } catch (err: any) {
      setError(err.message || 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyEmailConfirm = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      await apiFetch('/api/v1/auth/verify-email/confirm', {
        method: 'POST',
        body: JSON.stringify({ otpCode }),
      });
      setOtpCode('');
      setInfo('Email verified. Please sign in.');
      setMode('login');
    } catch (err: any) {
      setError(err.message || 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  const resendVerificationCode = async () => {
    setError('');
    setLoading(true);
    try {
      const res = await apiFetch<{ message: string }>('/api/v1/auth/verify-email/resend', {
        method: 'POST',
        body: JSON.stringify({ email }),
      });
      setInfo(res.message || 'If the account exists and isn\'t verified yet, a new code has been sent.');
    } catch (err: any) {
      setError(err.message || 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    if (mode === 'forgot-request') return handleForgotRequest(e);
    if (mode === 'forgot-confirm') return handleForgotConfirm(e);
    if (mode === 'verify-email') return handleVerifyEmailConfirm(e);

    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (mode === 'login') {
        const res = await apiFetch<{ accessToken: string; token: string }>('/api/v1/auth/login', {
          method: 'POST',
          body: JSON.stringify({ email, password }),
        });
        setToken(res.accessToken || res.token);
        navigate('/profile');
      } else {
        await apiFetch('/api/v1/auth/register', {
          method: 'POST',
          body: JSON.stringify({ name, email, password }),
        });
        setInfo('Account created. Check your email for a 6-digit verification code.');
        setMode('verify-email');
      }
    } catch (err: any) {
      setError(err.message || 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background flex flex-col items-center justify-center px-6 pb-10">
      {/* Logo */}
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        className="mb-10 flex flex-col items-center"
      >
        <div className="w-20 h-20 rounded-[24px] bg-primary flex items-center justify-center mb-4 shadow-lg shadow-primary/30">
          <BookOpen size={36} className="text-primary-foreground" />
        </div>
        <h1 className="text-foreground font-serif text-3xl font-bold mb-1">Christ Selah</h1>
        <p className="text-muted-foreground font-sans text-sm">Your spiritual journey</p>
      </motion.div>

      {/* Card */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.1 }}
        className="w-full max-w-sm bg-card rounded-[28px] shadow-sm border border-border p-6"
      >
        {/* Tab Toggle */}
        {(mode === 'login' || mode === 'register') && (
          <div className="flex bg-muted rounded-2xl p-1 mb-6">
            {(['login', 'register'] as const).map((m) => (
              <button
                key={m}
                onClick={() => { setMode(m); setError(''); setInfo(''); }}
                className={`flex-1 py-2.5 rounded-xl font-sans text-sm font-semibold transition-all ${
                  mode === m
                    ? 'bg-card text-foreground shadow-sm'
                    : 'text-muted-foreground'
                }`}
              >
                {m === 'login' ? 'Sign In' : 'Register'}
              </button>
            ))}
          </div>
        )}

        {/* Forgot-password header */}
        {(mode === 'forgot-request' || mode === 'forgot-confirm') && (
          <div className="flex items-center gap-2 mb-6">
            <button onClick={backToSignIn} className="text-muted-foreground p-1 -ml-1 rounded-full hover:bg-muted">
              <ChevronLeft size={20} />
            </button>
            <h2 className="text-foreground font-sans text-base font-semibold">
              {mode === 'forgot-request' ? 'Reset password' : 'Enter reset code'}
            </h2>
          </div>
        )}

        {/* Verify-email header */}
        {mode === 'verify-email' && (
          <h2 className="text-foreground font-sans text-base font-semibold mb-6">Verify your email</h2>
        )}

        {info && (
          <p className="text-primary font-sans text-sm bg-primary/10 rounded-xl px-4 py-3 mb-4">
            {info}
          </p>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          {mode === 'register' && (
            <div>
              <label className="block text-foreground font-sans text-sm font-medium mb-1.5">Name</label>
              <input
                type="text"
                value={name}
                onChange={e => setName(e.target.value)}
                placeholder="Your name"
                required
                className="w-full bg-muted rounded-xl px-4 py-3 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 font-sans text-base"
              />
            </div>
          )}

          {(mode === 'login' || mode === 'register' || mode === 'forgot-request') && (
            <div>
              <label className="block text-foreground font-sans text-sm font-medium mb-1.5">Email</label>
              <input
                type="email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                placeholder="you@example.com"
                required
                className="w-full bg-muted rounded-xl px-4 py-3 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 font-sans text-base"
              />
            </div>
          )}

          {(mode === 'login' || mode === 'register') && (
            <div>
              <label className="block text-foreground font-sans text-sm font-medium mb-1.5">Password</label>
              <div className="relative">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="••••••••"
                  required
                  className="w-full bg-muted rounded-xl px-4 py-3 pr-12 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 font-sans text-base"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(v => !v)}
                  className="absolute right-4 top-1/2 -translate-y-1/2 text-muted-foreground"
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
              {mode === 'register' && (
                <p className="text-muted-foreground font-sans text-xs mt-1.5">At least 10 characters, with 1 uppercase letter and 1 special character</p>
              )}
              {mode === 'login' && (
                <button
                  type="button"
                  onClick={goToForgotPassword}
                  className="mt-2 text-primary font-sans text-xs font-semibold hover:underline"
                >
                  Forgot password?
                </button>
              )}
            </div>
          )}

          {mode === 'forgot-confirm' && (
            <>
              <div>
                <label className="block text-foreground font-sans text-sm font-medium mb-1.5">6-digit code</label>
                <input
                  type="text"
                  inputMode="numeric"
                  maxLength={6}
                  value={otpCode}
                  onChange={e => setOtpCode(e.target.value.replace(/\D/g, ''))}
                  placeholder="123456"
                  required
                  className="w-full bg-muted rounded-xl px-4 py-3 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 font-sans text-base tracking-widest"
                />
                <p className="text-muted-foreground font-sans text-xs mt-1.5">Sent to {email}</p>
              </div>

              <div>
                <label className="block text-foreground font-sans text-sm font-medium mb-1.5">New password</label>
                <div className="relative">
                  <input
                    type={showNewPassword ? 'text' : 'password'}
                    value={newPassword}
                    onChange={e => setNewPassword(e.target.value)}
                    placeholder="At least 10 characters"
                    required
                    className="w-full bg-muted rounded-xl px-4 py-3 pr-12 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 font-sans text-base"
                  />
                  <button
                    type="button"
                    onClick={() => setShowNewPassword(v => !v)}
                    className="absolute right-4 top-1/2 -translate-y-1/2 text-muted-foreground"
                  >
                    {showNewPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </div>
                <p className="text-muted-foreground font-sans text-xs mt-1.5">At least 10 characters, with 1 uppercase letter and 1 special character</p>
              </div>

              <div>
                <label className="block text-foreground font-sans text-sm font-medium mb-1.5">Confirm new password</label>
                <input
                  type={showNewPassword ? 'text' : 'password'}
                  value={confirmNewPassword}
                  onChange={e => setConfirmNewPassword(e.target.value)}
                  placeholder="Re-enter new password"
                  required
                  className="w-full bg-muted rounded-xl px-4 py-3 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 font-sans text-base"
                />
              </div>

              <button
                type="button"
                onClick={handleForgotRequest}
                className="text-primary font-sans text-xs font-semibold hover:underline"
              >
                Resend code
              </button>
            </>
          )}

          {mode === 'verify-email' && (
            <div>
              <label className="block text-foreground font-sans text-sm font-medium mb-1.5">6-digit code</label>
              <input
                type="text"
                inputMode="numeric"
                maxLength={6}
                value={otpCode}
                onChange={e => setOtpCode(e.target.value.replace(/\D/g, ''))}
                placeholder="123456"
                required
                className="w-full bg-muted rounded-xl px-4 py-3 text-foreground placeholder:text-muted-foreground border border-border focus:outline-none focus:ring-2 focus:ring-primary/20 font-sans text-base tracking-widest"
              />
              <p className="text-muted-foreground font-sans text-xs mt-1.5">Sent to {email}</p>
              <button type="button" onClick={resendVerificationCode} className="mt-2 text-primary font-sans text-xs font-semibold hover:underline">
                Resend code
              </button>
            </div>
          )}

          {error && (
            <p className="text-destructive font-sans text-sm bg-destructive/10 rounded-xl px-4 py-3">
              {error}
            </p>
          )}

          <motion.button
            type="submit"
            disabled={loading}
            whileTap={{ scale: 0.98 }}
            className="w-full bg-primary text-primary-foreground rounded-2xl py-4 font-sans font-semibold text-base shadow-md shadow-primary/20 disabled:opacity-60 transition-all"
          >
            {loading ? (
              <span className="flex items-center justify-center gap-2">
                <span className="w-4 h-4 border-2 border-primary-foreground border-t-transparent rounded-full animate-spin" />
                {mode === 'login' ? 'Signing in…'
                  : mode === 'register' ? 'Creating account…'
                  : mode === 'forgot-request' ? 'Sending code…'
                  : mode === 'forgot-confirm' ? 'Resetting password…'
                  : 'Verifying…'}
              </span>
            ) : (
              mode === 'login' ? 'Sign In'
                : mode === 'register' ? 'Create Account'
                : mode === 'forgot-request' ? 'Send reset code'
                : mode === 'forgot-confirm' ? 'Reset password'
                : 'Verify email'
            )}
          </motion.button>
        </form>

        {/* Guest access */}
        {(mode === 'login' || mode === 'register') && (
        <div className="mt-4 text-center">
          <button
            onClick={() => navigate('/')}
            className="text-muted-foreground font-sans text-sm hover:text-foreground transition-colors"
          >
            Continue as guest
          </button>
        </div>
        )}
      </motion.div>
    </div>
  );
}
