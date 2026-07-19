import { Component, ReactNode, useEffect } from 'react';
import { RouterProvider } from 'react-router';
import { router } from './routes';
import { syncBookmarks } from './lib/bookmarkSync';

class ErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null };
  static getDerivedStateFromError(error: Error) { return { error }; }
  render() {
    if (this.state.error) {
      const err = this.state.error as Error;
      return (
        <div style={{ padding: 24, fontFamily: 'monospace', background: '#fff', color: '#c00', minHeight: '100vh' }}>
          <h2 style={{ marginBottom: 8 }}>App Error</h2>
          <pre style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-all', fontSize: 13 }}>{err.message}{'\n\n'}{err.stack}</pre>
        </div>
      );
    }
    return this.props.children;
  }
}

export default function App() {
  // Bookmarks/notes are saved to IndexedDB first and always work offline;
  // this just opportunistically pushes/pulls against the account whenever
  // there's a network to do it with, on load and whenever connectivity
  // returns - never something the UI has to wait on.
  useEffect(() => {
    syncBookmarks();
    window.addEventListener('online', syncBookmarks);
    return () => window.removeEventListener('online', syncBookmarks);
  }, []);

  return <ErrorBoundary><RouterProvider router={router} /></ErrorBoundary>;
}