import { useState, useEffect, useSyncExternalStore } from 'react';
import { useNavigate } from 'react-router';
import { CloudDownload, Check, X, Trash2 } from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import { PageContainer, AppBar, Text } from '../../components/BibleSystem';
import { BIBLE_VERSIONS } from '../BibleLibrary';
import { fetchBooksForVersion } from '../../lib/downloadBible';
import { getVersionCompletionInfo, clearVersionOffline, VersionCompletionInfo } from '../../lib/offlineStore';
import { subscribe, getSnapshot, startVersionDownload, cancelVersionDownload } from '../../lib/downloadManager';

type BibleVersion = (typeof BIBLE_VERSIONS)[number];

function VersionCard({
  version,
  completionInfo,
  onCompletionChange,
  onOpenConfirm,
}: {
  version: BibleVersion;
  completionInfo: VersionCompletionInfo | null;
  onCompletionChange: (info: VersionCompletionInfo | null) => void;
  onOpenConfirm: (version: BibleVersion) => void;
}) {
  // Subscribes directly to the module-level download manager, so this card
  // shows the correct state even after the whole screen unmounts/remounts
  // (e.g. navigating to Home/Profile/Music and back) — the download itself
  // keeps running independent of this component's lifecycle.
  const snapshot = useSyncExternalStore(subscribe, () => getSnapshot(version.id));
  const isDownloading = snapshot.status === 'downloading';

  // When a download finishes or is cancelled, re-check completion state.
  useEffect(() => {
    if (isDownloading) return;
    getVersionCompletionInfo(version.id).then(onCompletionChange);
  }, [isDownloading, version.id]);

  const removeDownload = async () => {
    await clearVersionOffline(version.id);
    onCompletionChange(null);
  };

  return (
    <div className="bg-card rounded-[24px] border border-border shadow-sm p-4">
      <div className="flex items-center gap-3 mb-3">
        <span className="text-2xl flex-shrink-0">{version.flag}</span>
        <div className="flex-1 min-w-0">
          <p className="text-foreground font-semibold font-sans text-sm truncate">{version.label}</p>
          <p className="text-muted-foreground font-sans text-xs truncate">{version.sublabel}</p>
        </div>
      </div>

      {isDownloading ? (
        <div>
          <div className="h-1.5 bg-muted rounded-full overflow-hidden mb-2">
            <div
              className="h-full bg-primary rounded-full transition-all"
              style={{
                width: `${snapshot.progress.chaptersTotal > 0
                  ? (snapshot.progress.chaptersDone / snapshot.progress.chaptersTotal) * 100
                  : 0}%`,
              }}
            />
          </div>
          <div className="flex items-center justify-between">
            <span className="text-muted-foreground font-sans text-xs truncate">
              {snapshot.progress.currentBookTitle || 'Starting…'} — {snapshot.progress.chaptersDone}/{snapshot.progress.chaptersTotal}
              {snapshot.progress.chaptersUnavailable > 0 && ` (${snapshot.progress.chaptersUnavailable} not available)`}
            </span>
            <button
              onClick={() => cancelVersionDownload(version.id)}
              className="text-destructive font-sans text-xs font-semibold flex-shrink-0 ml-2"
            >
              Cancel
            </button>
          </div>
        </div>
      ) : completionInfo ? (
        <div>
          <div className="flex items-center justify-between">
            <span className="flex items-center gap-1.5 text-primary font-sans text-xs font-semibold bg-primary/10 rounded-full px-3 py-1.5">
              <Check size={14} /> Downloaded
            </span>
            <motion.button
              whileTap={{ scale: 0.9 }}
              onClick={removeDownload}
              className="w-9 h-9 rounded-xl bg-muted flex items-center justify-center text-muted-foreground"
            >
              <Trash2 size={16} />
            </motion.button>
          </div>
          {completionInfo.unavailableChapters > 0 && (
            <p className="text-muted-foreground font-sans text-xs mt-2">
              {completionInfo.unavailableChapters} of {completionInfo.totalChapters} chapters aren't available in this
              translation (e.g. Old Testament) and were skipped.
            </p>
          )}
        </div>
      ) : (
        <motion.button
          whileTap={{ scale: 0.98 }}
          onClick={() => onOpenConfirm(version)}
          className="w-full flex items-center justify-center gap-2 bg-primary/10 text-primary rounded-xl py-2.5 font-sans text-sm font-semibold"
        >
          <CloudDownload size={16} />
          Download whole Bible (with audio)
        </motion.button>
      )}
    </div>
  );
}

export function Downloads() {
  const navigate = useNavigate();
  const [completions, setCompletions] = useState<Record<number, VersionCompletionInfo | null>>({});
  const [confirmVersion, setConfirmVersion] = useState<BibleVersion | null>(null);
  const [confirmCounts, setConfirmCounts] = useState<{ books: number; chapters: number } | null>(null);

  const openConfirm = async (version: BibleVersion) => {
    const books = await fetchBooksForVersion(version.id, version.lang);
    const chapters = books.reduce((sum, b) => sum + b.chapterCount, 0);
    setConfirmCounts({ books: books.length, chapters });
    setConfirmVersion(version);
  };

  const confirmDownload = () => {
    if (!confirmVersion) return;
    startVersionDownload(confirmVersion.id, confirmVersion.lang);
    setConfirmVersion(null);
  };

  return (
    <PageContainer className="pt-0 pb-24">
      <AppBar title="Downloads" onBack={() => navigate('/profile')} />

      <div className="pt-6 pb-4 px-1">
        <Text>Download Bible text and audio per language so you can read and listen offline. Downloads keep running in the background if you leave this screen.</Text>
      </div>

      <div className="space-y-3">
        {BIBLE_VERSIONS.map((version) => (
          <VersionCard
            key={version.id}
            version={version}
            completionInfo={completions[version.id] ?? null}
            onCompletionChange={(info) => setCompletions((c) => ({ ...c, [version.id]: info }))}
            onOpenConfirm={openConfirm}
          />
        ))}
      </div>

      {/* Confirmation Sheet */}
      <AnimatePresence>
        {confirmVersion && (
          <>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              onClick={() => setConfirmVersion(null)}
              className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40"
            />
            <motion.div
              initial={{ y: '100%' }}
              animate={{ y: 0 }}
              exit={{ y: '100%' }}
              transition={{ type: 'spring', damping: 30, stiffness: 300 }}
              className="fixed bottom-0 left-0 right-0 bg-card rounded-t-[28px] z-50 shadow-2xl p-6"
            >
              <div className="flex items-center justify-between mb-3">
                <h2 className="text-foreground font-semibold font-sans text-base">Download whole Bible?</h2>
                <motion.button whileTap={{ scale: 0.9 }} onClick={() => setConfirmVersion(null)} className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
                  <X size={16} className="text-muted-foreground" />
                </motion.button>
              </div>
              <Text className="mb-6">
                This downloads all {confirmCounts?.books ?? 66} books (~{confirmCounts?.chapters ?? ''} chapters) of text and
                audio for {confirmVersion.label}. This can take a while and use significant storage on your device.
              </Text>
              <motion.button
                whileTap={{ scale: 0.98 }}
                onClick={confirmDownload}
                className="w-full bg-primary text-primary-foreground rounded-2xl py-4 font-sans font-semibold text-base shadow-md shadow-primary/20"
              >
                Continue
              </motion.button>
            </motion.div>
          </>
        )}
      </AnimatePresence>
    </PageContainer>
  );
}
