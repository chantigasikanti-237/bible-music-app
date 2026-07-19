// Background sync between the local-first bookmark store (offlineBookmarks.ts)
// and the account's bookmarks on the backend. Local IndexedDB is always the
// source of truth for the UI - this only ever runs best-effort in the
// background, same as musicDownloadManager's quota release: if it fails
// (offline, or not logged in), the pending records just stay pending and
// the next call (app start, or the browser's 'online' event) retries them.
import { apiFetch, getToken } from './api';
import {
  getPendingSyncBookmarks,
  getPendingDeleteBookmarks,
  markBookmarkSynced,
  finalizeDeleteOffline,
  mergeServerBookmarks,
} from './offlineBookmarks';

let syncing = false;

export async function syncBookmarks(): Promise<void> {
  if (syncing || !getToken()) return;
  syncing = true;
  try {
    const pendingCreates = await getPendingSyncBookmarks();
    for (const b of pendingCreates) {
      try {
        const res = await apiFetch<{ success: boolean; data: { _id: string } }>('/api/v1/users/me/bookmarks', {
          method: 'POST',
          body: JSON.stringify({
            targetType: 'verse',
            bibleId: b.versionId,
            passageId: `${b.bookId.toUpperCase()}.${b.chapterNumber}`,
            verseNumber: b.verseNumber,
            text: b.text,
            bookName: b.bookName,
            languageCode: b.languageCode,
            ...(b.note ? { note: b.note } : {}),
          }),
        });
        if (res.success && res.data?._id) {
          await markBookmarkSynced(b.localId, res.data._id);
        }
      } catch {
        // Still offline, or a transient failure - leave it pending for next time.
      }
    }

    const pendingDeletes = await getPendingDeleteBookmarks();
    for (const b of pendingDeletes) {
      if (!b.serverId) continue;
      try {
        await apiFetch(`/api/v1/users/me/bookmarks/${b.serverId}`, { method: 'DELETE' });
        await finalizeDeleteOffline(b.localId);
      } catch {
        // Leave pendingDelete set - retried next sync pass.
      }
    }

    try {
      const res = await apiFetch<{ success: boolean; data: any[] }>('/api/v1/users/me/bookmarks?targetType=verse');
      if (res.success && Array.isArray(res.data)) {
        await mergeServerBookmarks(
          res.data
            .filter((b) => b.verseRef)
            .map((b) => ({
              _id: b._id,
              versionId: b.verseRef.versionId,
              bookId: b.verseRef.bookId,
              chapterNumber: b.verseRef.chapterNumber,
              verseNumber: b.verseRef.verseNumber,
              text: b.verseRef.text,
              bookName: b.verseRef.bookName || b.verseRef.bookId,
              languageCode: b.verseRef.languageCode || 'en',
              note: b.note || null,
              createdAt: b.createdAt,
            })),
        );
      }
    } catch {
      // Offline - local list stands as-is until next sync.
    }
  } finally {
    syncing = false;
  }
}
