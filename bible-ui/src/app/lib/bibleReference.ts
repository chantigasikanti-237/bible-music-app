// Parses queries like "genesis 7:16" or "ephesians 22" into a book + chapter
// (+ optional verse), so typing a reference jumps straight to it instead of
// just filtering the book list by name.

export interface ReferenceBook {
  id: string;
  title: string;
  titleRomanized?: string;
  englishTitle?: string;
}

export interface ParsedReference {
  book: ReferenceBook;
  chapter: number;
  verse?: number;
}

const norm = (s: string) => s.trim().toLowerCase();

const bookMatchesQuery = (book: ReferenceBook, q: string): boolean =>
  norm(book.title) === q ||
  (book.titleRomanized ? norm(book.titleRomanized) === q : false) ||
  (book.englishTitle ? norm(book.englishTitle) === q : false) ||
  norm(book.id) === q;

const bookStartsWithQuery = (book: ReferenceBook, q: string): boolean =>
  norm(book.title).startsWith(q) ||
  (book.titleRomanized ? norm(book.titleRomanized).startsWith(q) : false) ||
  (book.englishTitle ? norm(book.englishTitle).startsWith(q) : false);

const findBook = (bookPart: string, books: ReferenceBook[]): ReferenceBook | null => {
  const q = norm(bookPart);
  if (!q) return null;
  return (
    books.find(b => bookMatchesQuery(b, q)) ||
    books.find(b => bookStartsWithQuery(b, q)) ||
    null
  );
};

// Matches "<book> <chapter>" or "<book> <chapter>:<verse>" (colon may have
// surrounding spaces, e.g. "genesis 7 : 16").
const REFERENCE_PATTERN = /^(.+?)\s+(\d+)(?:\s*:\s*(\d+))?$/;

export function parseReference(query: string, books: ReferenceBook[]): ParsedReference | null {
  const match = REFERENCE_PATTERN.exec(query.trim());
  if (!match) return null;

  const [, bookPart, chapterStr, verseStr] = match;
  const chapter = Number(chapterStr);
  if (!Number.isFinite(chapter) || chapter < 1) return null;

  const book = findBook(bookPart, books);
  if (!book) return null;

  const verse = verseStr ? Number(verseStr) : undefined;
  return { book, chapter, verse: verse && verse > 0 ? verse : undefined };
}
