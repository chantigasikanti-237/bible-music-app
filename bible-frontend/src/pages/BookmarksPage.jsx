import { useState, useEffect, useRef } from 'react'
import { bookmarkApi } from '../api/client'

export default function BookmarksPage() {
  const [tab, setTab] = useState('verse')
  const [bookmarks, setBookmarks] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [nextCursor, setNextCursor] = useState(null)
  const cursorRef = useRef(null)

  const load = async (reset = true) => {
    setLoading(true)
    setError('')
    try {
      const params = (!reset && cursorRef.current) ? { cursor: cursorRef.current } : {}
      const res = await bookmarkApi.list(params)
      const items = Array.isArray(res.data) ? res.data : []
      setBookmarks(prev => reset ? items : [...prev, ...items])
      const nc = res.pagination?.nextCursor || null
      cursorRef.current = nc
      setNextCursor(nc)
    } catch (err) {
      setError(err.message || 'Failed to load bookmarks')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load(true) }, []) // eslint-disable-line

  const handleDelete = async (id) => {
    try {
      await bookmarkApi.remove(id)
      setBookmarks(prev => prev.filter(b => (b.id || b._id) !== id))
    } catch (err) {
      setError(err.message || 'Failed to delete bookmark')
    }
  }

  const verseBookmarks = bookmarks.filter(b =>
    b.targetType === 'verse' || (!b.targetType && b.verseNumber != null)
  )
  const songBookmarks = bookmarks.filter(b =>
    b.targetType === 'song' || b.songId != null
  )
  const displayed = tab === 'verse' ? verseBookmarks : songBookmarks

  return (
    <div>
      <div className="page-header">
        <h1>Bookmarks</h1>
        <span style={{ fontSize: '0.875rem', color: 'var(--text-muted)' }}>
          {bookmarks.length} saved
        </span>
      </div>

      <div className="bookmarks-page">
        <div className="tab-nav">
          <button
            className={`tab-btn${tab === 'verse' ? ' active' : ''}`}
            onClick={() => setTab('verse')}
          >
            📖 Verses ({verseBookmarks.length})
          </button>
          <button
            className={`tab-btn${tab === 'song' ? ' active' : ''}`}
            onClick={() => setTab('song')}
          >
            🎵 Songs ({songBookmarks.length})
          </button>
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        {loading && bookmarks.length === 0 && (
          <div className="loading-overlay"><div className="spinner" /></div>
        )}

        {!loading && displayed.length === 0 && (
          <div className="empty-state">
            <span className="empty-icon">{tab === 'verse' ? '📖' : '🎵'}</span>
            <p>No {tab === 'verse' ? 'verse' : 'song'} bookmarks yet</p>
            <p style={{ fontSize: '0.8rem' }}>
              {tab === 'verse'
                ? 'Tap 🔖 on any verse while reading the Bible'
                : 'Tap 🔖 Bookmark on a song in the Songs page'}
            </p>
          </div>
        )}

        <div className="bookmark-list">
          {displayed.map(b => {
            const id = b.id || b._id
            return (
              <div key={id} className="bookmark-item">
                {tab === 'verse' ? (
                  <div className="bookmark-icon">📖</div>
                ) : b.thumbnail ? (
                  <img src={b.thumbnail} alt="" className="bookmark-song-thumb" />
                ) : (
                  <div className="bookmark-icon">🎵</div>
                )}

                <div className="bookmark-body">
                  <div className="bookmark-ref">
                    {tab === 'verse'
                      ? (b.reference || `${b.bookId} ${b.chapterNumber}:${b.verseNumber}`)
                      : (b.title || 'Song')}
                  </div>
                  {tab === 'verse' && b.text && (
                    <div className="bookmark-text">"{b.text}"</div>
                  )}
                  {tab === 'song' && b.channelTitle && (
                    <div className="bookmark-text">{b.channelTitle}</div>
                  )}
                  <div className="bookmark-meta">
                    <span className={`badge ${tab === 'verse' ? 'badge-verse' : 'badge-song'}`}>
                      {tab === 'verse' ? 'Verse' : 'Song'}
                    </span>
                    {b.createdAt && (
                      <span style={{ marginLeft: '0.5rem' }}>
                        {new Date(b.createdAt).toLocaleDateString()}
                      </span>
                    )}
                  </div>
                </div>

                <button
                  className="btn-delete"
                  onClick={() => handleDelete(id)}
                  title="Remove bookmark"
                >
                  ✕
                </button>
              </div>
            )
          })}
        </div>

        {nextCursor && (
          <div style={{ textAlign: 'center', marginTop: '1.5rem' }}>
            <button
              className="btn btn-ghost"
              style={{ width: 'auto' }}
              onClick={() => load(false)}
              disabled={loading}
            >
              {loading ? 'Loading…' : 'Load more'}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
