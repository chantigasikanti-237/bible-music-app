const BIBLE_VERSION_STORAGE_KEY = 'bible_version_id';

export const getBibleVersionId = (): number => {
  const stored = localStorage.getItem(BIBLE_VERSION_STORAGE_KEY);
  return stored ? Number(stored) : 111;
};

export const setBibleVersionId = (id: number) => {
  localStorage.setItem(BIBLE_VERSION_STORAGE_KEY, String(id));
};

// Keep for backward compat — always reads current value
export const BIBLE_VERSION_ID = 111;

export const getToken = () => localStorage.getItem('access_token');
export const setToken = (token: string) => localStorage.setItem('access_token', token);
export const clearToken = () => {
  localStorage.removeItem('access_token');
  localStorage.removeItem('user');
};

export const getUser = () => {
  try {
    const raw = localStorage.getItem('user');
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
};

export const apiFetch = async <T = unknown>(url: string, options?: RequestInit): Promise<T> => {
  const token = getToken();
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options?.headers as Record<string, string> ?? {}),
  };
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  let res: Response;
  try {
    res = await fetch(url, { ...options, headers });
  } catch {
    // fetch() itself throws (not an HTTP error response) when the network
    // request never reached a server at all — wrong host, dropped
    // connection, offline, etc. The raw error here is just the browser's
    // generic "Failed to fetch", which tells the user nothing useful.
    throw new Error("Can't reach the server. Check your connection and try again.");
  }

  if (!res.ok) {
    const error = await res.json().catch(() => ({ message: res.statusText }));
    throw new Error(error.message || error.error || res.statusText);
  }
  return res.json() as Promise<T>;
};
