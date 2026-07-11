// IndexedDB-backed offline storage for favorite song audio — mirrors
// offlineStore.ts's approach for Bible chapters/audio, scoped to songs.

const DB_NAME = 'bible_music_offline';
const DB_VERSION = 1;
const SONGS_STORE = 'songs';

interface StoredSong {
  videoId: string;
  title: string;
  artist: string;
  image: string;
  language: string;
  isLongMix: boolean;
  blob: Blob;
  mimeType: string;
  savedAt: string;
}

let dbPromise: Promise<IDBDatabase> | null = null;

function openDb(): Promise<IDBDatabase> {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(SONGS_STORE)) {
        db.createObjectStore(SONGS_STORE, { keyPath: 'videoId' });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return dbPromise;
}

async function withStore<T>(
  mode: IDBTransactionMode,
  fn: (store: IDBObjectStore) => IDBRequest<T>,
): Promise<T> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(SONGS_STORE, mode);
    const store = tx.objectStore(SONGS_STORE);
    const req = fn(store);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function saveSongAudioOffline(params: {
  videoId: string;
  title: string;
  artist: string;
  image: string;
  language: string;
  isLongMix: boolean;
  blob: Blob;
  mimeType: string;
}): Promise<void> {
  const record: StoredSong = { ...params, savedAt: new Date().toISOString() };
  await withStore('readwrite', (store) => store.put(record));
}

export interface DownloadedSong {
  videoId: string;
  title: string;
  artist: string;
  image: string;
  language: string;
  isLongMix: boolean;
}

export async function listDownloadedSongs(): Promise<DownloadedSong[]> {
  const results = await withStore<StoredSong[]>('readonly', (store) => store.getAll());
  return results
    .sort((a, b) => b.savedAt.localeCompare(a.savedAt))
    .map(({ videoId, title, artist, image, language, isLongMix }) => ({
      videoId, title, artist, image, language: language || '', isLongMix: Boolean(isLongMix),
    }));
}

export async function getSongAudioBlobUrlOffline(videoId: string): Promise<string | null> {
  const result = await withStore<StoredSong | undefined>('readonly', (store) => store.get(videoId));
  return result ? URL.createObjectURL(result.blob) : null;
}

export async function isSongDownloaded(videoId: string): Promise<boolean> {
  const result = await withStore<StoredSong | undefined>('readonly', (store) => store.get(videoId));
  return result != null;
}

export async function removeSongOffline(videoId: string): Promise<void> {
  await withStore('readwrite', (store) => store.delete(videoId));
}
