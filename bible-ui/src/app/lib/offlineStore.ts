// IndexedDB-backed offline storage for Bible chapters + audio, mirroring the
// native app's offline_bible Hive cache but using browser storage since this
// runs inside a WebView with no filesystem access.

const DB_NAME = 'bible_offline';
const DB_VERSION = 1;
const CHAPTERS_STORE = 'chapters';
const AUDIO_STORE = 'audio';
const META_STORE = 'meta';

interface StoredChapter {
  key: string;
  versionId: number;
  bookId: string;
  chapterNumber: number;
  bookName: string;
  verses: { number: number; text: string }[];
  savedAt: string;
}

interface StoredAudio {
  key: string;
  versionId: number;
  bookId: string;
  chapterNumber: number;
  blob: Blob;
  mimeType: string;
  savedAt: string;
}

interface VersionCompleteMeta {
  key: string;
  versionId: number;
  totalChapters: number;
  unavailableChapters: number;
  completedAt: string;
}

export interface VersionCompletionInfo {
  totalChapters: number;
  unavailableChapters: number;
}

function chapterKey(versionId: number, bookId: string, chapterNumber: number): string {
  return `${versionId}:${bookId.toUpperCase()}:${chapterNumber}`;
}

function versionCompleteKey(versionId: number): string {
  return `version_complete:${versionId}`;
}

let dbPromise: Promise<IDBDatabase> | null = null;

function openDb(): Promise<IDBDatabase> {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(CHAPTERS_STORE)) {
        db.createObjectStore(CHAPTERS_STORE, { keyPath: 'key' });
      }
      if (!db.objectStoreNames.contains(AUDIO_STORE)) {
        db.createObjectStore(AUDIO_STORE, { keyPath: 'key' });
      }
      if (!db.objectStoreNames.contains(META_STORE)) {
        db.createObjectStore(META_STORE, { keyPath: 'key' });
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
  return dbPromise;
}

async function withStore<T>(
  storeName: string,
  mode: IDBTransactionMode,
  fn: (store: IDBObjectStore) => IDBRequest<T>,
): Promise<T> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, mode);
    const store = tx.objectStore(storeName);
    const req = fn(store);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

export async function saveChapterOffline(params: {
  versionId: number;
  bookId: string;
  chapterNumber: number;
  bookName: string;
  verses: { number: number; text: string }[];
}): Promise<void> {
  const record: StoredChapter = {
    key: chapterKey(params.versionId, params.bookId, params.chapterNumber),
    versionId: params.versionId,
    bookId: params.bookId,
    chapterNumber: params.chapterNumber,
    bookName: params.bookName,
    verses: params.verses,
    savedAt: new Date().toISOString(),
  };
  await withStore(CHAPTERS_STORE, 'readwrite', (store) => store.put(record));
}

export async function getChapterOffline(
  versionId: number,
  bookId: string,
  chapterNumber: number,
): Promise<StoredChapter | null> {
  const result = await withStore<StoredChapter | undefined>(CHAPTERS_STORE, 'readonly', (store) =>
    store.get(chapterKey(versionId, bookId, chapterNumber)),
  );
  return result ?? null;
}

export async function saveAudioOffline(params: {
  versionId: number;
  bookId: string;
  chapterNumber: number;
  blob: Blob;
  mimeType: string;
}): Promise<void> {
  const record: StoredAudio = {
    key: chapterKey(params.versionId, params.bookId, params.chapterNumber),
    versionId: params.versionId,
    bookId: params.bookId,
    chapterNumber: params.chapterNumber,
    blob: params.blob,
    mimeType: params.mimeType,
    savedAt: new Date().toISOString(),
  };
  await withStore(AUDIO_STORE, 'readwrite', (store) => store.put(record));
}

export async function getAudioBlobUrlOffline(
  versionId: number,
  bookId: string,
  chapterNumber: number,
): Promise<string | null> {
  const result = await withStore<StoredAudio | undefined>(AUDIO_STORE, 'readonly', (store) =>
    store.get(chapterKey(versionId, bookId, chapterNumber)),
  );
  if (!result) return null;
  return URL.createObjectURL(result.blob);
}

export async function hasAudioOffline(
  versionId: number,
  bookId: string,
  chapterNumber: number,
): Promise<boolean> {
  const result = await withStore<StoredAudio | undefined>(AUDIO_STORE, 'readonly', (store) =>
    store.get(chapterKey(versionId, bookId, chapterNumber)),
  );
  return result != null;
}

export async function markVersionComplete(
  versionId: number,
  totalChapters: number,
  unavailableChapters: number,
): Promise<void> {
  const record: VersionCompleteMeta = {
    key: versionCompleteKey(versionId),
    versionId,
    totalChapters,
    unavailableChapters,
    completedAt: new Date().toISOString(),
  };
  await withStore(META_STORE, 'readwrite', (store) => store.put(record));
}

export async function getVersionCompletionInfo(versionId: number): Promise<VersionCompletionInfo | null> {
  const result = await withStore<VersionCompleteMeta | undefined>(META_STORE, 'readonly', (store) =>
    store.get(versionCompleteKey(versionId)),
  );
  if (!result) return null;
  return { totalChapters: result.totalChapters, unavailableChapters: result.unavailableChapters ?? 0 };
}

export async function isVersionComplete(versionId: number): Promise<boolean> {
  const result = await withStore<VersionCompleteMeta | undefined>(META_STORE, 'readonly', (store) =>
    store.get(versionCompleteKey(versionId)),
  );
  return result != null;
}

export async function clearVersionOffline(versionId: number): Promise<void> {
  const db = await openDb();
  const clear = (storeName: string, matches: (key: string) => boolean) =>
    new Promise<void>((resolve, reject) => {
      const tx = db.transaction(storeName, 'readwrite');
      const store = tx.objectStore(storeName);
      const req = store.getAllKeys();
      req.onsuccess = () => {
        const keys = (req.result as string[]).filter(matches);
        for (const key of keys) store.delete(key);
        resolve();
      };
      req.onerror = () => reject(req.error);
    });

  const prefix = `${versionId}:`;
  await clear(CHAPTERS_STORE, (k) => k.startsWith(prefix));
  await clear(AUDIO_STORE, (k) => k.startsWith(prefix));
  await clear(META_STORE, (k) => k === versionCompleteKey(versionId));
}

export async function estimateStorageUsage(): Promise<{ usageMb: number; quotaMb: number } | null> {
  if (!navigator.storage?.estimate) return null;
  const { usage, quota } = await navigator.storage.estimate();
  if (usage == null || quota == null) return null;
  return { usageMb: usage / (1024 * 1024), quotaMb: quota / (1024 * 1024) };
}
