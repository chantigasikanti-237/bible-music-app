const normalizeText = (value) =>
  String(value ?? "")
    .normalize("NFKD")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();

module.exports = normalizeText;
