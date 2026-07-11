import { useState, useRef } from 'react'
import { audioApi, bookmarkApi } from '../api/client'

const LANGUAGES = [
  'Telugu', 'English', 'Hindi', 'Tamil', 'Kannada', 'Malayalam', 'Marathi', 'Punjabi',
]

export default function SongsPage() {
  const [language, setLanguage] = useState('')
  const [songs, setSongs] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [currentSong, setCurrentSong] = useState(null)
  const [toast, setToast] = useState('')
  const toastTimer = useRef(null)

  const showToast = (msg) => {
    setToast(msg)
    clearTimeout(toastTimer.current)
    toastTimer.current = setTimeout(() => setToast(''), 2500)
  }

  const fetchSongs = async (lang) => {
    setError('')
    setLoading(true)
    setSongs([])
    try {
      const data = await audioApi.listByLanguage(lang)
      setSongs(Array.isArray(data) ? data : [])
    } catch (err) {
      setError(err.message || 'Failed to load songs. Check that YOUTUBE_API_KEY is configured.')
    } finally {
      setLoading(false)
    }
  }

  const handleLanguageChange = (e) => {
    const lang = e.target.value
    setLanguage(lang)
    setCurrentSong(null)
    if (lang) fetchSongs(lang)
    else setSongs([])
  }

  const handleBookmarkSong = async (song) => {
    try {
      await bookmarkApi.create({
        targetType: 'song',
        songId: song.id,
        title: song.title,
        thumbnail: song.thumbnail,
        channelTitle: song.channelTitle,
      })
      showToast('Song bookmarked ✓')
    } catch (err) {
      showToast(err.message || 'Could not bookmark song')
    }
  }

  return (
    <div className="songs-page">
      <div className="page-header">
        <div>
          <h1>Songs</h1>
          {songs.length > 0 && (
            <span style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
              {songs.length} songs found
            </span>
          )}
        </div>
        {currentSong && (
          <button
            className="btn btn-ghost"
            style={{ width: 'auto', fontSize: '0.85rem' }}
            onClick={() => handleBookmarkSong(currentSong)}
          >
            🔖 Bookmark Playing Song
          </button>
        )}
      </div>

      <div className="songs-toolbar">
        <label>Language:</label>
        <select value={language} onChange={handleLanguageChange}>
          <option value="">— Select a language —</option>
          {LANGUAGES.map(l => <option key={l} value={l}>{l}</option>)}
        </select>
        {loading && <div className="spinner" />}
      </div>

      <div className="songs-grid-container">
        {!language && (
          <div className="empty-state">
            <span className="empty-icon">🎵</span>
            <p>Choose a language to browse Christian worship songs</p>
            <p style={{ fontSize: '0.8rem' }}>Powered by YouTube</p>
          </div>
        )}

        {error && (
          <div className="alert alert-error" style={{ maxWidth: 480, margin: '2rem auto' }}>
            {error}
          </div>
        )}

        {!loading && language && !error && songs.length === 0 && (
          <div className="empty-state">
            <span className="empty-icon">🔍</span>
            <p>No songs found for "{language}"</p>
          </div>
        )}

        {songs.length > 0 && (
          <div className="songs-grid">
            {songs.map(song => (
              <div
                key={song.id}
                className={`song-card${currentSong?.id === song.id ? ' playing' : ''}`}
                onClick={() => setCurrentSong(song)}
              >
                {song.thumbnail
                  ? <img src={song.thumbnail} alt={song.title} className="song-thumb" loading="lazy" />
                  : <div className="song-thumb-placeholder">🎵</div>
                }
                <div className="song-info">
                  <div className="song-title">{song.title}</div>
                  <div className="song-channel">{song.channelTitle}</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {currentSong && (
        <div className="audio-player">
          {currentSong.thumbnail
            ? <img src={currentSong.thumbnail} alt="" className="audio-player-thumb" />
            : <div className="audio-player-thumb-ph">🎵</div>
          }
          <div className="audio-player-info">
            <div className="audio-player-title">{currentSong.title}</div>
            <div className="audio-player-channel">{currentSong.channelTitle}</div>
          </div>
          <audio
            key={currentSong.id}
            src={audioApi.streamUrl(currentSong.id)}
            controls
            autoPlay
            className="audio-el"
          />
        </div>
      )}

      {toast && (
        <div className="toast" style={{ bottom: currentSong ? '90px' : '2rem' }}>
          {toast}
        </div>
      )}
    </div>
  )
}
