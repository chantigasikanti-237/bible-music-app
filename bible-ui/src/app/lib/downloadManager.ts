// Runs whole-Bible downloads outside any screen's component lifecycle, so
// navigating away from the Downloads screen (Home, Profile, Music, etc.)
// does not stop an in-progress download — only pressing Cancel does.
import { downloadWholeBible, DownloadProgress } from './downloadBible';

export type VersionDownloadStatus = 'idle' | 'downloading';

export interface VersionDownloadState {
  status: VersionDownloadStatus;
  progress: DownloadProgress;
}

const IDLE_STATE: VersionDownloadState = {
  status: 'idle',
  progress: { chaptersDone: 0, chaptersTotal: 0, currentBookTitle: '' },
};

const stateByVersion = new Map<number, VersionDownloadState>();
const cancelFlags = new Map<number, boolean>();
const listeners = new Set<() => void>();

function notify(): void {
  for (const listener of listeners) listener();
}

export function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function getSnapshot(versionId: number): VersionDownloadState {
  return stateByVersion.get(versionId) ?? IDLE_STATE;
}

export function isDownloading(versionId: number): boolean {
  return stateByVersion.get(versionId)?.status === 'downloading';
}

export function startVersionDownload(versionId: number, lang: string): void {
  if (isDownloading(versionId)) return; // already running — never double-start

  cancelFlags.set(versionId, false);
  stateByVersion.set(versionId, {
    status: 'downloading',
    progress: { chaptersDone: 0, chaptersTotal: 0, chaptersUnavailable: 0, currentBookTitle: '' },
  });
  notify();

  downloadWholeBible(
    versionId,
    lang,
    (progress) => {
      stateByVersion.set(versionId, { status: 'downloading', progress });
      notify();
    },
    () => cancelFlags.get(versionId) === true,
  ).finally(() => {
    stateByVersion.delete(versionId);
    cancelFlags.delete(versionId);
    notify();
  });
}

export function cancelVersionDownload(versionId: number): void {
  cancelFlags.set(versionId, true);
}
