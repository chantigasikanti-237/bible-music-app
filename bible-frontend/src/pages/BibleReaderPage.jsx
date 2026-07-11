import { useState, useEffect, useCallback, useRef } from 'react'
import { bibleApi, bookmarkApi, historyApi } from '../api/client'

export default function BibleReaderPage() {
  const [versionId, setVersionId] = useState(1)
  const [versionInput, setVersionInput] = useState('1')

  const [books, setBooks] = useState([])
  const [chapters, setChapters] = useState([])
  const [chapterData, setChapterData] = useState(null)
  const [selectedBook, setSelectedBook] = useState(null)
  const [selectedChapter, setSelectedChapter] = useState(null)
  const [search, setSearch] = useState('')

  const [booksLoading, setBooksLoading] = useState(false)
  const [chaptersLoading, setChaptersLoading] = useState(false)
  const [chapterLoading, setChapterLoading] = useState(false)
  const [booksError, setBooksError] = useState('')
  const [toast, setToast] = useState('')
  const toastTimer = useRef(null)

  const showToast = (msg) => {
    setToast(msg)
    clearTimeout(toastTimer.current)
    toastTimer.current = setTimeout(() => setToast(''), 2500)
  }

  // Load books whenever version changes
  useEffect(() => {
    setBooksLoading(true)
    setBooksError('')
    setBooks([])
    setSelectedBook(null)
    setChapters([])
    setSelectedChapter(null)
    setChapterData(null)

    bibleApi.listBooks(versionId)
      .then(res => setBooks(Array.isArray(res.data) ? res.data : []))
      .catch(err => setBooksError(err.message || 'Could not load books for this version'))
      .finally(() => setBooksLoading(false))
  }, [versionId])

  // Load chapters whenever book changes
  useEffect(() => {
    if (!selectedBook) return
    setChaptersLoading(true)
    setChapters([])
    setSelectedChapter(null)
    setChapterData(null)

    const bookId = selectedBook.id || selectedBook.bookId || selectedBook._id
    bibleApi.listChapters(versionId, bookId)
      .then(res => setChapters(Array.isArray(res.data) ? res.data : []))
      .catch(() => setChapters([]))
      .finally(() => setChaptersLoading(false))
  }, [selectedBook, versionId])

  const loadChapter = useCallback(async (num) => {
    if (!selectedBook) return
    const bookId = selectedBook.id || selectedBook.bookId || selectedBook._id
    setChapterLoading(true)
    setChapterData(null)
    try {
      const res = await bibleApi.getChapter(versionId, bookId, num)
      setChapterData(res.data || res)
      setSelectedChapter(num)
      // fire-and-forget history tracking
      historyApi.create({
        bibleId: versionId,
        versionId,
        passageId: `${bookId}.${num}`,
        reference: `${selectedBook.name || bookId} ${num}`,
        languageCode: 'en',
      }).catch(() => {})
    } catch (err) {
      showToast(err.message || 'Failed to load chapter')
    } finally {
      setChapterLoading(false)
    }
  }, [selectedBook, versionId])

  const handleBookmark = async (verse) => {
    if (!selectedBook || !selectedChapter) return
    const bookId = selectedBook.id || selectedBook.bookId || selectedBook._id
    const verseNum = verse.verseNumber ?? verse.number ?? verse.verse
    try {
      await bookmarkApi.create({
        targetType: 'verse',
        bookId,
        chapterNumber: selectedChapter,
        verseNumber: verseNum,
        versionId,
        reference: `${selectedBook.name || bookId} ${selectedChapter}:${verseNum}`,
        text: verse.text || verse.content || '',
      })
      showToast('Verse bookmarked ✓')
    } catch (err) {
      showToast(err.message || 'Could not bookmark verse')
    }
  }

  const applyVersion = () => {
    const n = Number(versionInput)
    if (n > 0) setVersionId(n)
  }

  const filteredBooks = books.filter(b =>
    (b.name || b.title || '').toLowerCase().includes(search.toLowerCase())
  )
  const otBooks = filteredBooks.filter(b => b.testament === 'OT' || b.testament === 'old')
  const ntBooks = filteredBooks.filter(b => b.testament === 'NT' || b.testament === 'new')
  const otherBooks = filteredBooks.filter(b => !b.testament)

  const renderBookList = (list) => list.map(book => {
    const id = book.id || book.bookId || book._id
    const name = book.name || book.title || id
    const isActive = selectedBook && (selectedBook.id || selectedBook._id) === (book.id || book._id)
    return (
      <div key={id} className={`panel-item${isActive ? ' active' : ''}`} onClick={() => setSelectedBook(book)}>
        {name}
      </div>
    )
  })

  const verses = chapterData?.verses || chapterData?.content || []
  const bookName = selectedBook?.name || selectedBook?.title || ''
  const totalChapters = chapters.length

  return (
    <div className="reader-root">
      {/* Top controls */}
      <div className="reader-controls">
        <label>Bible Version ID:</label>
        <input
          type="number"
          min="1"
          value={versionInput}
          onChange={e => setVersionInput(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && applyVersion()}
          className="version-input"
        />
        <button className="btn-apply" onClick={applyVersion}>Load</button>
        <span className="reader-hint">Try IDs: 1, 12, 111 depending on your DB</span>
      </div>

      <div className="bible-reader">
        {/* Books panel */}
        <div className="panel">
          <div className="panel-header">📚 Books</div>
          <div className="panel-search">
            <input placeholder="Search…" value={search} onChange={e => setSearch(e.target.value)} />
          </div>
          <div className="panel-list">
            {booksLoading && <div className="loading-overlay"><div className="spinner" /></div>}
            {booksError && (
              <div className="empty-state">
                <span className="empty-icon">⚠️</span>
                <p style={{ color: 'var(--danger)' }}>{booksError}</p>
              </div>
            )}
            {!booksLoading && !booksError && books.length === 0 && (
              <div className="empty-state">
                <span className="empty-icon">📚</span>
                <p>Enter a version ID and click Load</p>
              </div>
            )}
            {otherBooks.length > 0 && renderBookList(otherBooks)}
            {otBooks.length > 0 && (
              <>
                <div className="testament-label">Old Testament</div>
                {renderBookList(otBooks)}
              </>
            )}
            {ntBooks.length > 0 && (
              <>
                <div className="testament-label">New Testament</div>
                {renderBookList(ntBooks)}
              </>
            )}
          </div>
        </div>

        {/* Chapters panel */}
        <div className="panel">
          <div className="panel-header">{bookName || 'Chapters'}</div>
          <div className="panel-list">
            {!selectedBook && <div className="empty-state"><p>Select a book</p></div>}
            {chaptersLoading && <div className="loading-overlay"><div className="spinner" /></div>}
            <div className="chapters-grid">
              {chapters.map(ch => {
                const num = ch.chapterNumber ?? ch.number ?? ch
                return (
                  <div
                    key={num}
                    className={`chapter-item${selectedChapter === num ? ' active' : ''}`}
                    onClick={() => loadChapter(num)}
                  >
                    {num}
                  </div>
                )
              })}
            </div>
          </div>
        </div>

        {/* Reading panel */}
        <div className="reading-column">
          {!chapterData && !chapterLoading && (
            <div className="empty-state" style={{ height: '100%' }}>
              <span className="empty-icon">📖</span>
              <p>Select a book and chapter to start reading</p>
              <p style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>Click 🔖 on any verse to bookmark it</p>
            </div>
          )}
          {chapterLoading && (
            <div className="loading-overlay" style={{ height: '100%' }}>
              <div className="spinner" />
            </div>
          )}
          {chapterData && !chapterLoading && (
            <>
              <div className="reading-panel">
                <div className="reading-header">
                  <div className="reading-title">{bookName} {selectedChapter}</div>
                  <div className="reading-subtitle">{verses.length} verses · Version {versionId}</div>
                </div>
                <div className="verse-list">
                  {verses.map((v, i) => {
                    const num = v.verseNumber ?? v.number ?? v.verse ?? (i + 1)
                    const text = v.text || v.content || v.value || ''
                    return (
                      <div key={num} className="verse">
                        <div className="verse-num">{num}</div>
                        <div className="verse-text">{text}</div>
                        <button
                          className="verse-bookmark-btn"
                          onClick={() => handleBookmark(v)}
                          title="Bookmark this verse"
                        >
                          🔖
                        </button>
                      </div>
                    )
                  })}
                </div>
              </div>

              <div className="chapter-nav">
                <button
                  className="btn btn-ghost nav-btn"
                  disabled={selectedChapter <= 1}
                  onClick={() => loadChapter(selectedChapter - 1)}
                >
                  ← Prev
                </button>
                <span className="chapter-nav-info">
                  {bookName} {selectedChapter}{totalChapters ? ` / ${totalChapters}` : ''}
                </span>
                <button
                  className="btn btn-ghost nav-btn"
                  disabled={totalChapters > 0 && selectedChapter >= totalChapters}
                  onClick={() => loadChapter(selectedChapter + 1)}
                >
                  Next →
                </button>
              </div>
            </>
          )}
        </div>
      </div>

      {toast && <div className="toast">{toast}</div>}
    </div>
  )
}
