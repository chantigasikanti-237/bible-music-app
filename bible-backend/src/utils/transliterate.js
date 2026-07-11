const Sanscript = require("@indic-transliteration/sanscript");

// Which Sanscript source scheme to read a language's native script as.
// Languages not listed here (e.g. "en", or any language whose titles are
// already stored in Latin script) skip transliteration entirely.
const SCHEME_BY_LANGUAGE_CODE = {
  te: "telugu",
  hi: "devanagari",
  mr: "devanagari",
  ta: "tamil",
  kn: "kannada",
  ml: "malayalam",
};

const isAsciiOnly = (text) => /^[\x00-\x7F]*$/.test(text);

// Produces a lowercase, ASCII-searchable version of a hymn title so a query
// typed in English letters (e.g. "Akasham") can match a title stored in
// native script (e.g. "ఆకాశం"). Some source rows are already Latin script —
// those are just lowercased, not re-transliterated.
const transliterateTitle = (title, languageCode) => {
  const text = String(title ?? "").trim();
  if (!text) return "";

  if (isAsciiOnly(text)) return text.toLowerCase();

  const scheme = SCHEME_BY_LANGUAGE_CODE[String(languageCode ?? "").toLowerCase()];
  if (!scheme) return text.toLowerCase();

  try {
    return Sanscript.t(text, scheme, "itrans").toLowerCase();
  } catch (err) {
    return text.toLowerCase();
  }
};

module.exports = { transliterateTitle };
