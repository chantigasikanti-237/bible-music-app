import { Component, ReactNode } from 'react';
import { RouterProvider } from 'react-router';
import { router } from './routes';

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
  return <ErrorBoundary><RouterProvider router={router} /></ErrorBoundary>;
}