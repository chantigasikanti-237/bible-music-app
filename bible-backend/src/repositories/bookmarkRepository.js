const mongoose = require("mongoose");

const Bookmark = require("../models/Bookmark");
const {
  parseLimit,
  buildObjectIdCursorFilter,
  buildNextCursor,
} = require("../utils/pagination");

const createBookmarkRepository = ({ model = Bookmark } = {}) => ({
  async upsertBookmark(userId, payload) {
    return model
      .findOneAndUpdate(
        {
          userId,
          targetKey: payload.targetKey,
        },
        {
          $set: payload,
          $setOnInsert: {
            userId,
          },
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

  async listBookmarks({
    userId,
    targetType,
    limit,
    cursor,
  }) {
    const normalizedLimit = parseLimit(limit);
    const filter = {
      userId,
      ...buildObjectIdCursorFilter(cursor),
    };

    if (targetType) {
      filter.targetType = targetType;
    }

    const items = await model
      .find(filter)
      .sort({ _id: -1 })
      .limit(normalizedLimit)
      .lean()
      .exec();

    return {
      items,
      nextCursor: buildNextCursor(items),
    };
  },

  async listAllBookmarks({ userId, targetType }) {
    const filter = { userId };
    if (targetType) {
      filter.targetType = targetType;
    }

    return model
      .find(filter)
      .sort({ createdAt: -1, _id: -1 })
      .lean()
      .exec();
  },

  async deleteBookmark(userId, bookmarkId) {
    if (!mongoose.Types.ObjectId.isValid(bookmarkId)) {
      return null;
    }

    return model
      .findOneAndDelete({
        _id: bookmarkId,
        userId,
      })
      .lean()
      .exec();
  },

  async getBookmark(userId, bookmarkId) {
    if (!mongoose.Types.ObjectId.isValid(bookmarkId)) {
      return null;
    }

    return model
      .findOne({
        _id: bookmarkId,
        userId,
      })
      .lean()
      .exec();
  },
});

module.exports = {
  createBookmarkRepository,
  bookmarkRepository: createBookmarkRepository(),
};
