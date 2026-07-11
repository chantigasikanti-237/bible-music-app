import { useState } from 'react';
import { useNavigate } from 'react-router';
import { Check } from 'lucide-react';
import { motion } from 'motion/react';
import { PageContainer, AppBar } from '../../components/BibleSystem';
import { getBibleVersionId, setBibleVersionId } from '../../lib/api';
import { BIBLE_VERSIONS } from '../BibleLibrary';
import {
  UNIVERSAL_LANGUAGES,
  type LanguageCode,
  isUniversalLanguageEnabled,
  setUniversalLanguageEnabled,
  getUniversalLanguage,
  applyUniversalLanguage,
  getHymnsLanguage,
  setHymnsLanguage,
  getMusicLanguageKey,
  setMusicLanguageKey,
  musicKeyToCode,
  codeToMusicKey,
  getMusicFollowsUniversal,
  setMusicFollowsUniversal,
} from '../../lib/languagePreference';

const defaultVersionIdFor = (code: LanguageCode): number =>
  BIBLE_VERSIONS.find(v => v.lang === code)?.id ?? BIBLE_VERSIONS[0].id;

function ToggleSwitch({ on, onChange }: { on: boolean; onChange: (next: boolean) => void }) {
  return (
    <button
      onClick={() => onChange(!on)}
      className={`relative w-12 h-7 rounded-full transition-colors flex-shrink-0 ${on ? 'bg-primary' : 'bg-muted'}`}
    >
      <motion.div
        className="absolute top-0.5 w-6 h-6 rounded-full bg-white shadow-sm"
        animate={{ left: on ? '22px' : '2px' }}
        transition={{ type: 'spring', stiffness: 500, damping: 32 }}
      />
    </button>
  );
}

function LanguageOption({ label, selected, onSelect }: { label: string; selected: boolean; onSelect: () => void }) {
  return (
    <motion.button
      whileTap={{ scale: 0.98 }}
      onClick={onSelect}
      className={`w-full flex items-center gap-4 py-4 px-2 rounded-xl transition-all ${selected ? 'bg-primary/5' : 'hover:bg-muted/50'}`}
    >
      <div className={`w-6 h-6 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-all ${selected ? 'border-primary bg-primary' : 'border-border'}`}>
        {selected && <Check size={12} className="text-primary-foreground" strokeWidth={3} />}
      </div>
      <p className={`font-sans text-sm font-semibold text-left ${selected ? 'text-primary' : 'text-foreground'}`}>{label}</p>
    </motion.button>
  );
}

export function Language() {
  const navigate = useNavigate();

  const [universal, setUniversal] = useState(isUniversalLanguageEnabled);
  const [universalCode, setUniversalCode] = useState<LanguageCode>(getUniversalLanguage);
  const [bibleVersionId, setBibleVersionIdState] = useState<number>(getBibleVersionId);
  const [hymnsCode, setHymnsCode] = useState<LanguageCode>(getHymnsLanguage);
  const [musicCode, setMusicCode] = useState<LanguageCode>(() => musicKeyToCode(getMusicLanguageKey()));
  const [musicFollowsUniversal, setMusicFollowsUniversalState] = useState(getMusicFollowsUniversal);

  const bibleCode = (BIBLE_VERSIONS.find(v => v.id === bibleVersionId)?.lang as LanguageCode) || 'en';

  const handleToggle = (next: boolean) => {
    setUniversal(next);
    setUniversalLanguageEnabled(next);
    if (next) {
      // Seed the shared language from whatever Bible is currently set to, so
      // turning it on doesn't silently reset everything to English.
      const seed: LanguageCode = UNIVERSAL_LANGUAGES.some(l => l.code === bibleCode) ? bibleCode : 'en';
      applyUniversalLanguage(seed, defaultVersionIdFor(seed));
      setUniversalCode(seed);
      setBibleVersionIdState(defaultVersionIdFor(seed));
      setHymnsCode(seed);
      setMusicCode(seed);
    }
  };

  const selectUniversal = (code: LanguageCode) => {
    applyUniversalLanguage(code, defaultVersionIdFor(code));
    setUniversalCode(code);
    setBibleVersionIdState(defaultVersionIdFor(code));
    setHymnsCode(code);
    setMusicCode(code);
  };

  const selectBible = (code: LanguageCode) => {
    const versionId = defaultVersionIdFor(code);
    setBibleVersionId(versionId);
    setBibleVersionIdState(versionId);
  };

  const selectHymns = (code: LanguageCode) => {
    setHymnsLanguage(code);
    setHymnsCode(code);
  };

  const selectMusic = (code: LanguageCode) => {
    setMusicLanguageKey(codeToMusicKey(code));
    setMusicCode(code);
  };

  const handleToggleMusicFollows = (next: boolean) => {
    setMusicFollowsUniversal(next);
    setMusicFollowsUniversalState(next);
    if (next) {
      // Re-sync Music to the shared language immediately instead of waiting
      // for the next time someone picks a language.
      setMusicLanguageKey(codeToMusicKey(universalCode));
      setMusicCode(universalCode);
    }
  };

  return (
    <PageContainer className="pt-0 pb-24">
      <AppBar title="Language" onBack={() => navigate('/profile')} />

      <div className="pt-6 space-y-6">
        {/* Universal toggle */}
        <div className="bg-card rounded-[24px] border border-border shadow-sm p-4 flex items-center gap-4">
          <div className="flex-1">
            <p className="text-foreground font-sans text-sm font-semibold mb-1">Universal Language</p>
            <p className="text-muted-foreground font-sans text-xs">
              {universal
                ? 'One language for Bible, Hymns, and Music together.'
                : 'Bible, Hymns, and Music each keep their own language.'}
            </p>
          </div>
          <ToggleSwitch on={universal} onChange={handleToggle} />
        </div>

        {universal ? (
          <>
            <div>
              <h3 className="text-muted-foreground font-sans text-xs font-semibold uppercase tracking-wider mb-3 px-1">
                Language
              </h3>
              <div className="bg-card rounded-[24px] border border-border shadow-sm px-4">
                {UNIVERSAL_LANGUAGES.map((l, i) => (
                  <div key={l.code} className={i !== UNIVERSAL_LANGUAGES.length - 1 ? 'border-b border-border' : ''}>
                    <LanguageOption label={l.label} selected={universalCode === l.code} onSelect={() => selectUniversal(l.code)} />
                  </div>
                ))}
              </div>
            </div>

            {/* Music-only opt-out of Universal Language */}
            <div className="bg-card rounded-[24px] border border-border shadow-sm p-4 flex items-center gap-4">
              <div className="flex-1">
                <p className="text-foreground font-sans text-sm font-semibold mb-1">Include Music</p>
                <p className="text-muted-foreground font-sans text-xs">
                  {musicFollowsUniversal
                    ? 'Music follows the language above.'
                    : 'Music keeps its own language, separate from Bible and Hymns.'}
                </p>
              </div>
              <ToggleSwitch on={musicFollowsUniversal} onChange={handleToggleMusicFollows} />
            </div>

            {!musicFollowsUniversal && (
              <div>
                <h3 className="text-muted-foreground font-sans text-xs font-semibold uppercase tracking-wider mb-3 px-1">
                  Music Language
                </h3>
                <div className="bg-card rounded-[24px] border border-border shadow-sm px-4">
                  {UNIVERSAL_LANGUAGES.map((l, i) => (
                    <div key={l.code} className={i !== UNIVERSAL_LANGUAGES.length - 1 ? 'border-b border-border' : ''}>
                      <LanguageOption label={l.label} selected={musicCode === l.code} onSelect={() => selectMusic(l.code)} />
                    </div>
                  ))}
                </div>
              </div>
            )}
          </>
        ) : (
          <>
            {/* Bible Language */}
            <div>
              <h3 className="text-muted-foreground font-sans text-xs font-semibold uppercase tracking-wider mb-3 px-1">
                Bible Language
              </h3>
              <div className="bg-card rounded-[24px] border border-border shadow-sm px-4">
                {UNIVERSAL_LANGUAGES.map((l, i) => (
                  <div key={l.code} className={i !== UNIVERSAL_LANGUAGES.length - 1 ? 'border-b border-border' : ''}>
                    <LanguageOption label={l.label} selected={bibleCode === l.code} onSelect={() => selectBible(l.code)} />
                  </div>
                ))}
              </div>
            </div>

            {/* Hymns Language */}
            <div>
              <h3 className="text-muted-foreground font-sans text-xs font-semibold uppercase tracking-wider mb-3 px-1">
                Hymns Language
              </h3>
              <div className="bg-card rounded-[24px] border border-border shadow-sm px-4">
                {UNIVERSAL_LANGUAGES.map((l, i) => (
                  <div key={l.code} className={i !== UNIVERSAL_LANGUAGES.length - 1 ? 'border-b border-border' : ''}>
                    <LanguageOption label={l.label} selected={hymnsCode === l.code} onSelect={() => selectHymns(l.code)} />
                  </div>
                ))}
              </div>
            </div>

            {/* Songs Language */}
            <div>
              <h3 className="text-muted-foreground font-sans text-xs font-semibold uppercase tracking-wider mb-3 px-1">
                Music Language
              </h3>
              <div className="bg-card rounded-[24px] border border-border shadow-sm px-4">
                {UNIVERSAL_LANGUAGES.map((l, i) => (
                  <div key={l.code} className={i !== UNIVERSAL_LANGUAGES.length - 1 ? 'border-b border-border' : ''}>
                    <LanguageOption label={l.label} selected={musicCode === l.code} onSelect={() => selectMusic(l.code)} />
                  </div>
                ))}
              </div>
            </div>
          </>
        )}
      </div>
    </PageContainer>
  );
}
