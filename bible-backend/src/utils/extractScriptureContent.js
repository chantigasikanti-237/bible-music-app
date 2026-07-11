const pickString = (...values) =>
  values.find((value) => typeof value === "string" && value.trim().length > 0);

const extractScriptureContent = (payload) => {
  if (typeof payload === "string") {
    return payload;
  }

  if (!payload || typeof payload !== "object") {
    return "";
  }

  const directContent = pickString(
    payload.content,
    payload.text,
    payload.body,
    payload.html
  );

  if (directContent) {
    return directContent;
  }

  const nestedContent = pickString(
    payload?.data?.content,
    payload?.data?.text,
    payload?.passage?.content,
    payload?.passage?.text
  );

  if (nestedContent) {
    return nestedContent;
  }

  if (Array.isArray(payload.verses) && payload.verses.length > 0) {
    return payload.verses
      .map((verse, index) => {
        const text = pickString(verse.text, verse.content);
        if (!text) {
          return null;
        }

        const number =
          Number.parseInt(
            verse.number ?? verse.verseNumber ?? verse.verse ?? index + 1,
            10
          ) || index + 1;
        return `${number} ${text}`.trim();
      })
      .filter(Boolean)
      .join("\n");
  }

  return JSON.stringify(payload);
};

module.exports = extractScriptureContent;
