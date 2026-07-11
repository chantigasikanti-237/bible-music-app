// Shared "Universal Language" preference. Bible, Hymns, and Music each have
// their own language storage (their own keys, their own value formats —
// Bible uses a version id, Music uses full names like "English"). This
// module doesn't replace those; it coordinates them:
//  - OFF: each section keeps remembering its own language independently
//    (already true for Bible; Hymns/Music now persist too, see their screens).
//  - ON: picking a language anywhere calls applyUniversalLanguage(), which
//    writes through to all three sections' own storage at once, so the next
//    time any of them mounts it just reads its normal key and is in sync.
import { setBibleVersionId } from './api';

export type LanguageCode = 'en' | 'te' | 'hi' | 'ta';

// Only languages available across Bible, Hymns, and Music at once — Universal
// mode can't offer a language one of the three sections doesn't have.
export const UNIVERSAL_LANGUAGES: { code: LanguageCode; label: string }[] = [
  { code: 'en', label: 'English' },
  { code: 'te', label: 'Telugu (తెలుగు)' },
  { code: 'hi', label: 'Hindi (हिंदी)' },
  { code: 'ta', label: 'Tamil (தமிழ்)' },
];

const ENABLED_KEY = 'universal_language_enabled';
const UNIVERSAL_CODE_KEY = 'universal_language_code';
const HYMNS_LANG_KEY = 'hymns_language_code';
const MUSIC_LANG_KEY = 'music_language_key';
const MUSIC_FOLLOWS_UNIVERSAL_KEY = 'music_follows_universal';

export const isUniversalLanguageEnabled = (): boolean =>
  localStorage.getItem(ENABLED_KEY) === 'true';

export const setUniversalLanguageEnabled = (enabled: boolean): void => {
  localStorage.setItem(ENABLED_KEY, enabled ? 'true' : 'false');
};

// Scoped to the Music tab only — lets Music opt out of Universal Language
// while Bible and Hymns stay synced (e.g. always keep Music in English
// regardless of what Bible/Hymns are set to). Defaults to true so existing
// Universal Language users keep their current fully-synced behavior.
export const getMusicFollowsUniversal = (): boolean => {
  const raw = localStorage.getItem(MUSIC_FOLLOWS_UNIVERSAL_KEY);
  return raw === null ? true : raw === 'true';
};

export const setMusicFollowsUniversal = (follows: boolean): void => {
  localStorage.setItem(MUSIC_FOLLOWS_UNIVERSAL_KEY, follows ? 'true' : 'false');
};

export const getUniversalLanguage = (): LanguageCode =>
  (localStorage.getItem(UNIVERSAL_CODE_KEY) as LanguageCode | null) || 'en';

export const getHymnsLanguage = (): LanguageCode =>
  (localStorage.getItem(HYMNS_LANG_KEY) as LanguageCode | null) || 'en';

export const setHymnsLanguage = (code: LanguageCode): void => {
  localStorage.setItem(HYMNS_LANG_KEY, code);
};

export const getMusicLanguageKey = (): string =>
  localStorage.getItem(MUSIC_LANG_KEY) || 'English';

export const setMusicLanguageKey = (key: string): void => {
  localStorage.setItem(MUSIC_LANG_KEY, key);
};

const MUSIC_KEY_BY_CODE: Record<LanguageCode, string> = {
  en: 'English', te: 'Telugu', hi: 'Hindi', ta: 'Tamil',
};
const MUSIC_CODE_BY_KEY: Record<string, LanguageCode> = {
  English: 'en', Telugu: 'te', Hindi: 'hi', Tamil: 'ta',
};

export const codeToMusicKey = (code: LanguageCode): string => MUSIC_KEY_BY_CODE[code] || 'English';
// Music has languages (e.g. Malayalam, Kannada) outside the universal set —
// falls back to English rather than throwing when there's no mapping.
export const musicKeyToCode = (key: string): LanguageCode => MUSIC_CODE_BY_KEY[key] || 'en';

// Call whenever a language is picked anywhere while Universal mode is on.
// `bibleVersionId` is resolved by the caller (each screen already has the
// Bible version list in scope) to avoid a circular import with BibleLibrary.
export const applyUniversalLanguage = (code: LanguageCode, bibleVersionId: number): void => {
  localStorage.setItem(UNIVERSAL_CODE_KEY, code);
  setHymnsLanguage(code);
  if (getMusicFollowsUniversal()) {
    setMusicLanguageKey(codeToMusicKey(code));
  }
  setBibleVersionId(bibleVersionId);
};
