import { saveChapterOffline, saveAudioOffline, markVersionComplete } from './offlineStore';

interface BibleBook {
  id: string;
  title: string;
  canon: string;
  chapterCount: number;
}

interface ChapterData {
  bookName: string;
  chapterNumber: number;
  verses: { number: number; text: string }[];
  audio: { url: string | null; provider: string | null };
}

export interface DownloadProgress {
  chaptersDone: number;
  chaptersTotal: number;
  chaptersUnavailable: number;
  currentBookTitle: string;
}

export async function fetchBooksForVersion(versionId: number, lang: string): Promise<BibleBook[]> {
  const res = await fetch(`/api/v1/bibles/${versionId}/books?lang=${lang}`);
  const data: { success: boolean; data: BibleBook[] } = await res.json();
  if (!data.success || !Array.isArray(data.data)) return [];
  return data.data;
}

// How many chapters to download at once. The backend's bible content routes
// have no rate limiting, so this is bounded only by being polite to the
// browser's per-origin connection pool.
const CONCURRENCY = 6;

interface DownloadTask {
  book: BibleBook;
  chapterNumber: number;
}

type ChapterResult = 'saved' | 'unavailable' | 'error';

async function downloadChapter(
  versionId: number,
  task: DownloadTask,
): Promise<ChapterResult> {
  const { book, chapterNumber } = task;
  try {
    const res = await fetch(`/api/v1/bibles/${versionId}/books/${book.id}/chapters/${chapterNumber}`);
    const data: { success: boolean; data: ChapterData } = await res.json();
    // The backend reports success:false when the upstream source doesn't
    // have this chapter at all (e.g. an Old Testament chapter in a
    // New-Testament-only translation) — that's "unavailable", not an error.
    if (!data.success || !data.data) return 'unavailable';

    await saveChapterOffline({
      versionId,
      bookId: book.id,
      chapterNumber,
      bookName: data.data.bookName || book.title,
      verses: data.data.verses || [],
    });

    const audioUrl = data.data.audio?.url;
    if (audioUrl) {
      try {
        const audioRes = await fetch(audioUrl);
        if (audioRes.ok) {
          const blob = await audioRes.blob();
          await saveAudioOffline({
            versionId,
            bookId: book.id,
            chapterNumber,
            blob,
            mimeType: audioRes.headers.get('content-type') || 'audio/mpeg',
          });
        }
      } catch {
        // Audio unavailable for this chapter — skip and continue with text.
      }
    }
    return 'saved';
  } catch {
    // Chapter fetch failed — skip this chapter and keep going so one
    // flaky/missing chapter doesn't abort the whole download.
    return 'error';
  }
}

// Downloads every chapter's text and audio for every book of a Bible version,
// several chapters at a time (see CONCURRENCY) instead of one-by-one — a
// fully sequential download of ~1,200 chapters would take 20-40+ minutes.
export async function downloadWholeBible(
  versionId: number,
  lang: string,
  onProgress: (progress: DownloadProgress) => void,
  isCancelled: () => boolean,
): Promise<void> {
  const books = await fetchBooksForVersion(versionId, lang);
  const chaptersTotal = books.reduce((sum, b) => sum + b.chapterCount, 0);
  let chaptersDone = 0;
  let chaptersUnavailable = 0;

  const tasks: DownloadTask[] = [];
  for (const book of books) {
    for (let chapterNumber = 1; chapterNumber <= book.chapterCount; chapterNumber++) {
      tasks.push({ book, chapterNumber });
    }
  }

  let nextIndex = 0;
  let cancelled = false;

  const worker = async () => {
    while (true) {
      if (isCancelled()) {
        cancelled = true;
        return;
      }
      const index = nextIndex++;
      if (index >= tasks.length) return;

      const task = tasks[index];
      const result = await downloadChapter(versionId, task);
      if (result === 'unavailable') chaptersUnavailable++;

      chaptersDone++;
      onProgress({ chaptersDone, chaptersTotal, chaptersUnavailable, currentBookTitle: task.book.title });
    }
  };

  await Promise.all(Array.from({ length: CONCURRENCY }, worker));

  if (!cancelled && !isCancelled()) {
    await markVersionComplete(versionId, chaptersTotal, chaptersUnavailable);
  }
}
