import { useState } from 'react'
import { Link } from 'react-router-dom'
import { authApi } from '../api/client'

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      await authApi.requestReset(email)
      setSent(true)
    } catch (err) {
      setError(err.message || 'Failed to send reset email.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="auth-logo">
          <span className="auth-logo-icon">🔐</span>
          <h1>Reset Password</h1>
          <p>We'll send a reset link to your email</p>
        </div>

        {sent ? (
          <>
            <div className="alert alert-success">
              ✓ Check your inbox — reset instructions sent!
            </div>
            <div className="auth-links">
              <Link to="/login">← Back to Sign In</Link>
            </div>
          </>
        ) : (
          <>
            {error && <div className="alert alert-error">{error}</div>}
            <form onSubmit={handleSubmit}>
              <div className="form-group">
                <label>Email Address</label>
                <input
                  type="email"
                  placeholder="you@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  autoFocus
                />
              </div>
              <button className="btn btn-primary" type="submit" disabled={loading}>
                {loading ? <><span className="spinner-sm" /> Sending…</> : 'Send Reset Link'}
              </button>
            </form>
            <div className="auth-links">
              <Link to="/login">← Back to Sign In</Link>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
