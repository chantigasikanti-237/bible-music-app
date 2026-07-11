import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import ProtectedRoute from './components/ProtectedRoute'
import Layout from './components/Layout'
import LoginPage from './pages/LoginPage'
import RegisterPage from './pages/RegisterPage'
import ForgotPasswordPage from './pages/ForgotPasswordPage'
import BibleReaderPage from './pages/BibleReaderPage'
import SongsPage from './pages/SongsPage'
import BookmarksPage from './pages/BookmarksPage'

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/forgot-password" element={<ForgotPasswordPage />} />
          <Route element={<ProtectedRoute />}>
            <Route element={<Layout />}>
              <Route index element={<Navigate to="/bible" replace />} />
              <Route path="/bible" element={<BibleReaderPage />} />
              <Route path="/songs" element={<SongsPage />} />
              <Route path="/bookmarks" element={<BookmarksPage />} />
            </Route>
          </Route>
          <Route path="*" element={<Navigate to="/bible" replace />} />
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  )
}
