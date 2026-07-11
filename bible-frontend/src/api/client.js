const BASE = '/api'

let _token = localStorage.getItem('bibleAccessToken') || null

export const setToken = (t) => {
  _token = t
  if (t) localStorage.setItem('bibleAccessToken', t)
  else localStorage.removeItem('bibleAccessToken')
}

export const getToken = () => _token

const raw = async (method, path, body, { skipAuth = false, isRetry = false } = {}) => {
  const headers = { 'Content-Type': 'application/json' }
  if (_token && !skipAuth) headers['Authorization'] = `Bearer ${_token}`

  const res = await fetch(`${BASE}${path}`, {
    method,
    headers,
    credentials: 'include',
    body: body != null ? JSON.stringify(body) : undefined,
  })

  if (res.status === 401 && !skipAuth && !isRetry) {
    try {
      const rr = await fetch(`${BASE}/v1/auth/refresh`, {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
      })
      if (rr.ok) {
        const rd = await rr.json()
        setToken(rd.accessToken || rd.token)
        return raw(method, path, body, { skipAuth, isRetry: true })
      }
    } catch (_) {}
    setToken(null)
    window.dispatchEvent(new Event('auth:logout'))
    throw { status: 401, message: 'Session expired. Please sign in again.' }
  }

  let data
  try { data = await res.json() } catch (_) { data = {} }
  if (!res.ok) throw { status: res.status, message: data.message || data.error || 'Request failed', data }
  return data
}

export const api = {
  get: (path, opts) => raw('GET', path, null, opts),
  post: (path, body, opts) => raw('POST', path, body, opts),
  delete: (path, opts) => raw('DELETE', path, null, opts),
}

/* ── Auth ── */
export const authApi = {
  login: (email, password) =>
    raw('POST', '/v1/auth/login', { email, password }, { skipAuth: true }),
  register: (name, email, password) =>
    raw('POST', '/v1/auth/register', { name, email, password }, { skipAuth: true }),
  logout: () => api.post('/v1/auth/logout'),
  requestReset: (email) =>
    raw('POST', '/v1/auth/password-reset/request', { email }, { skipAuth: true }),
  getMe: () => api.get('/v1/users/me'),
}

/* ── Bible content ── */
export const bibleApi = {
  listBooks: (versionId) => api.get(`/v1/bibles/${versionId}/books`),
  listChapters: (versionId, bookId) =>
    api.get(`/v1/bibles/${versionId}/books/${bookId}/chapters`),
  getChapter: (versionId, bookId, chapterNumber) =>
    api.get(`/v1/bibles/${versionId}/books/${bookId}/chapters/${chapterNumber}`),
}

/* ── Reading history ── */
export const historyApi = {
  list: () => api.get('/v1/users/me/history'),
  create: (data) => api.post('/v1/users/me/history', data),
}

/* ── Bookmarks ── */
export const bookmarkApi = {
  list: (params) =>
    api.get(`/v1/users/me/bookmarks${params ? `?${new URLSearchParams(params)}` : ''}`),
  create: (data) => api.post('/v1/users/me/bookmarks', data),
  remove: (id) => api.delete(`/v1/users/me/bookmarks/${id}`),
}

/* ── Audio ── */
export const audioApi = {
  listByLanguage: async (language) => {
    const res = await fetch(`/api/audio/songs/${encodeURIComponent(language)}`, {
      credentials: 'include',
    })
    if (!res.ok) {
      let d; try { d = await res.json() } catch (_) { d = {} }
      throw { status: res.status, message: d.message || 'Failed to load songs' }
    }
    return res.json()
  },
  streamUrl: (videoId) => `/api/audio/stream/${encodeURIComponent(videoId)}`,
}

/* ── Search ── */
export const searchApi = {
  verses: (q, cursor) =>
    api.get(`/v1/search/verses?q=${encodeURIComponent(q)}${cursor ? `&cursor=${cursor}` : ''}`),
}
