// IndexedDB-backed local-first storage for verse bookmarks/notes — mirrors
// offlineStore.ts's approach. Local is the source of truth for reads and
// writes so saving/removing a bookmark never needs the network; bookmarkSync.ts
// pushes/pulls against the account in the background when online.

const DB_NAME = 'bible_bookmarks_offline';
const DB_VERSION = 1;
const STORE = 'bookmarks';

export interface StoredBookmark {
  localId: string;
  serverId: string | null;
  versionId: number;
  bookId: string;
  chapterNumber: number;
  verseNumber: number;
  text: string;
  bookName: string;
  languageCode: string;
  note: string | null;
  createdAt: string;
  // Queued for a server-side delete but kept locally until that succeeds,
  // so a sync pull running in between doesn't resurrect it from the
  // account's (not-yet-updated) bookmark list.
  pendingDelete: boolean;
}

function dedupeKey(versionId: number, bookId: string, chapterNumber: number, verseNumber: number): string {
  return `${versionId}:${bookId.toUpperCase()}:${chapterNumber}:${verseNumber}`;
}

let dbPromise: Promise<IDBDatabase> | null = null;

function openDb(): Promise<IDBDatabase> {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: 'localId' });
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
    const tx = db.transaction(STORE, mode);
    const store = tx.objectStore(STORE);
    const req = fn(store);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function getAll(): Promise<StoredBookmark[]> {
  return withStore<StoredBookmark[]>('readonly', (store) => store.getAll());
}

export async function addBookmarkOffline(params: {
  versionId: number;
  bookId: string;
  chapterNumber: number;
  verseNumber: number;
  text: string;
  bookName: string;
  languageCode: string;
  note?: string | null;
}): Promise<StoredBookmark> {
  const record: StoredBookmark = {
    localId: `local_${Date.now()}_${Math.random().toString(36).slice(2)}`,
    serverId: null,
    versionId: params.versionId,
    bookId: params.bookId,
    chapterNumber: params.chapterNumber,
    verseNumber: params.verseNumber,
    text: params.text,
    bookName: params.bookName,
    languageCode: params.languageCode,
    note: params.note?.trim() || null,
    createdAt: new Date().toISOString(),
    pendingDelete: false,
  };
  await withStore(STORE_MODE_READWRITE, (store) => store.put(record));
  return record;
}

const STORE_MODE_READWRITE: IDBTransactionMode = 'readwrite';

export async function listBookmarksOffline(): Promise<StoredBookmark[]> {
  const all = await getAll();
  return all
    .filter((b) => !b.pendingDelete)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

export async function isVerseBookmarkedOffline(
  versionId: number,
  bookId: string,
  chapterNumber: number,
  verseNumber: number,
): Promise<StoredBookmark | null> {
  const key = dedupeKey(versionId, bookId, chapterNumber, verseNumber);
  const all = await getAll();
  return all.find((b) => !b.pendingDelete && dedupeKey(b.versionId, b.bookId, b.chapterNumber, b.verseNumber) === key) ?? null;
}

// Bookmarked verses for one chapter, keyed by verse number — the shape
// ReadingScreen's "already saved" preload needs, computed locally instead of
// via a network round trip.
export async function listBookmarkedVerseNumbersOffline(
  versionId: number,
  bookId: string,
  chapterNumber: number,
): Promise<Set<number>> {
  const all = await getAll();
  const normalizedBookId = bookId.toUpperCase();
  const result = new Set<number>();
  for (const b of all) {
    if (b.pendingDelete) continue;
    if (b.versionId === versionId && b.bookId.toUpperCase() === normalizedBookId && b.chapterNumber === chapterNumber) {
      result.add(b.verseNumber);
    }
  }
  return result;
}

// Removes a bookmark that was never synced (no server record exists yet) or
// marks it pendingDelete so bookmarkSync.ts can tell the server, then
// finalizeDeleteOffline() drops it for good once that succeeds.
export async function removeBookmarkOffline(localId: string): Promise<{ serverId: string | null }> {
  const record = await withStore<StoredBookmark | undefined>('readonly', (store) => store.get(localId));
  if (!record) return { serverId: null };

  if (!record.serverId) {
    await withStore(STORE_MODE_READWRITE, (store) => store.delete(localId));
    return { serverId: null };
  }

  await withStore(STORE_MODE_READWRITE, (store) => store.put({ ...record, pendingDelete: true }));
  return { serverId: record.serverId };
}

export async function markBookmarkSynced(localId: string, serverId: string): Promise<void> {
  const record = await withStore<StoredBookmark | undefined>('readonly', (store) => store.get(localId));
  if (!record) return;
  await withStore(STORE_MODE_READWRITE, (store) => store.put({ ...record, serverId }));
}

export async function finalizeDeleteOffline(localId: string): Promise<void> {
  await withStore(STORE_MODE_READWRITE, (store) => store.delete(localId));
}

export async function getPendingSyncBookmarks(): Promise<StoredBookmark[]> {
  const all = await getAll();
  return all.filter((b) => !b.serverId && !b.pendingDelete);
}

export async function getPendingDeleteBookmarks(): Promise<StoredBookmark[]> {
  const all = await getAll();
  return all.filter((b) => b.pendingDelete && b.serverId);
}

// Folds in bookmarks that exist on the account but not on this device yet
// (made before this feature existed, or from another device) - skips
// anything already present locally under the same verse, so a synced local
// record's serverId is never clobbered by a redundant duplicate.
export async function mergeServerBookmarks(
  serverRecords: Array<{
    _id: string;
    versionId: number;
    bookId: string;
    chapterNumber: number;
    verseNumber: number;
    text: string;
    bookName: string;
    languageCode: string;
    note: string | null;
    createdAt: string;
  }>,
): Promise<void> {
  const existing = await getAll();
  const existingKeys = new Set(
    existing.filter((b) => !b.pendingDelete).map((b) => dedupeKey(b.versionId, b.bookId, b.chapterNumber, b.verseNumber)),
  );

  for (const server of serverRecords) {
    const key = dedupeKey(server.versionId, server.bookId, server.chapterNumber, server.verseNumber);
    if (existingKeys.has(key)) continue;

    const record: StoredBookmark = {
      localId: `local_${Date.now()}_${Math.random().toString(36).slice(2)}`,
      serverId: server._id,
      versionId: server.versionId,
      bookId: server.bookId,
      chapterNumber: server.chapterNumber,
      verseNumber: server.verseNumber,
      text: server.text,
      bookName: server.bookName,
      languageCode: server.languageCode,
      note: server.note,
      createdAt: server.createdAt,
      pendingDelete: false,
    };
    await withStore(STORE_MODE_READWRITE, (store) => store.put(record));
    existingKeys.add(key);
  }
}
