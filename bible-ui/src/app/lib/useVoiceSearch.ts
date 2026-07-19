import { useCallback, useRef, useState } from 'react';

// Ambient types for the Web Speech API — not part of TypeScript's default
// DOM lib, and only implemented by some browsers/WebViews (support is
// inconsistent, especially inside Android WebView vs. full Chrome).
interface SpeechRecognitionAlternativeLike {
  transcript: string;
}
interface SpeechRecognitionResultLike {
  [index: number]: SpeechRecognitionAlternativeLike;
}
interface SpeechRecognitionEventLike {
  results: { [index: number]: SpeechRecognitionResultLike };
}
interface SpeechRecognitionLike extends EventTarget {
  lang: string;
  interimResults: boolean;
  maxAlternatives: number;
  start: () => void;
  stop: () => void;
  onresult: ((event: SpeechRecognitionEventLike) => void) | null;
  onerror: (() => void) | null;
  onend: (() => void) | null;
}

declare global {
  interface Window {
    SpeechRecognition?: new () => SpeechRecognitionLike;
    webkitSpeechRecognition?: new () => SpeechRecognitionLike;
  }
}

const getConstructor = () =>
  typeof window !== 'undefined' ? window.SpeechRecognition || window.webkitSpeechRecognition : undefined;

export const isVoiceSearchSupported = (): boolean => !!getConstructor();

// Maps the app's short language codes (from musicKeyToCode / languagePreference)
// to BCP-47 locale tags the Web Speech API expects.
const LOCALE_BY_CODE: Record<string, string> = {
  en: 'en-US', te: 'te-IN', hi: 'hi-IN', ta: 'ta-IN', ml: 'ml-IN', kn: 'kn-IN',
};

export function useVoiceSearch(onResult: (transcript: string) => void, languageCode = 'en') {
  const [isListening, setIsListening] = useState(false);
  const recognitionRef = useRef<SpeechRecognitionLike | null>(null);

  const start = useCallback(() => {
    const Ctor = getConstructor();
    if (!Ctor) return;

    const recognition = new Ctor();
    recognition.lang = LOCALE_BY_CODE[languageCode] || 'en-US';
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;
    recognition.onresult = (event) => {
      const transcript = event.results[0]?.[0]?.transcript;
      if (transcript) onResult(transcript);
    };
    recognition.onerror = () => setIsListening(false);
    recognition.onend = () => setIsListening(false);

    recognitionRef.current = recognition;
    setIsListening(true);
    recognition.start();
  }, [onResult, languageCode]);

  const stop = useCallback(() => {
    recognitionRef.current?.stop();
    setIsListening(false);
  }, []);

  return { isListening, start, stop };
}
