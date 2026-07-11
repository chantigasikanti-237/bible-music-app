const AppError = require("./AppError");

const CHAPTER_PATTERN = /^([1-3]?[A-Z]{2,})(?:\.(\d{1,3}))$/;

const parsePassageId = (passageId) => {
  const normalized = String(passageId ?? "").trim().toUpperCase();
  const match = CHAPTER_PATTERN.exec(normalized);
  if (!match) {
    return null;
  }

  const chapterNumber = Number.parseInt(match[2], 10);
  if (!Number.isFinite(chapterNumber) || chapterNumber <= 0) {
    return null;
  }

  return {
    bookId: match[1],
    chapterNumber,
    passageId: normalized,
  };
};

const requirePassageId = (passageId) => {
  const parsed = parsePassageId(passageId);
  if (!parsed) {
    throw new AppError(
      400,
      "passageId must be a canonical chapter id like GEN.1 or JHN.3"
    );
  }

  return parsed;
};

const buildPassageId = (bookId, chapterNumber) =>
  `${String(bookId ?? "").trim().toUpperCase()}.${Number(chapterNumber)}`;

module.exports = {
  parsePassageId,
  requirePassageId,
  buildPassageId,
};
