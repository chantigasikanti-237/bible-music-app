const Song = require("../models/Song");
const {
  parseLimit,
  parsePage,
  buildObjectIdCursorFilter,
  buildNextCursor,
} = require("../utils/pagination");

const escapeRegex = (value) =>
  String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const createSongRepository = ({ model = Song } = {}) => ({
  async upsertSong(payload) {
    return model
      .findOneAndUpdate(
        {
          languageCode: payload.languageCode,
          slug: payload.slug,
        },
        {
          $set: payload,
        },
        {
          upsert: true,
          new: true,
          setDefaultsOnInsert: true,
        }
      )
      .lean()
      .exec();
  },

  async listSongs({ languageCode, search, limit, cursor, page }) {
    const normalizedLimit = parseLimit(limit);
    const filter = {
      isPublished: true,
    };
    if (languageCode) {
      filter.languageCode = languageCode;
    }
    if (search) {
      const pattern = escapeRegex(search);
      // Matches either the native-script title or its romanized form, so a
      // query typed in English letters can find a hymn stored in Telugu,
      // Devanagari, etc. — see src/utils/transliterate.js.
      filter.$or = [
        { title: { $regex: pattern, $options: "i" } },
        { titleRomanized: { $regex: pattern, $options: "i" } },
      ];
    }

    if (cursor) {
      const cursorFilter = {
        ...filter,
        ...buildObjectIdCursorFilter(cursor),
      };

      const items = await model
        .find(cursorFilter)
        .sort({ _id: -1 })
        .limit(normalizedLimit)
        .lean()
        .exec();

      return {
        items,
        limit: normalizedLimit,
        nextCursor: buildNextCursor(items),
        hasNextPage: items.length === normalizedLimit,
      };
    }

    const normalizedPage = parsePage(page);
    const skip = (normalizedPage - 1) * normalizedLimit;

    const itemsPlusOne = await model
      .find(filter)
      .sort({ title: 1, _id: 1 })
      .skip(skip)
      .limit(normalizedLimit + 1)
      .lean()
      .exec();

    const hasNextPage = itemsPlusOne.length > normalizedLimit;
    const items = hasNextPage
      ? itemsPlusOne.slice(0, normalizedLimit)
      : itemsPlusOne;

    return {
      items,
      page: normalizedPage,
      limit: normalizedLimit,
      nextPage: hasNextPage ? normalizedPage + 1 : null,
      nextCursor: buildNextCursor(items),
      hasNextPage,
    };
  },
});

module.exports = {
  createSongRepository,
  songRepository: createSongRepository(),
};
