const History = require("../models/History");
const {
  parseLimit,
  buildObjectIdCursorFilter,
  buildNextCursor,
} = require("../utils/pagination");

const createHistoryRepository = ({ model = History } = {}) => ({
  async upsertHistory(userId, payload) {
    return model
      .findOneAndUpdate(
        {
          userId,
          bibleId: payload.bibleId,
          passageId: payload.passageId,
        },
        {
          $set: {
            ...payload,
            lastReadAt: new Date(),
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

  async getLatestHistory(userId) {
    return model
      .findOne({ userId })
      .sort({ lastReadAt: -1, _id: -1 })
      .lean()
      .exec();
  },

  async listHistory({ userId, limit, cursor }) {
    const normalizedLimit = parseLimit(limit);
    const items = await model
      .find({
        userId,
        ...buildObjectIdCursorFilter(cursor),
      })
      .sort({ _id: -1 })
      .limit(normalizedLimit)
      .lean()
      .exec();

    return {
      items,
      nextCursor: buildNextCursor(items),
    };
  },
});

module.exports = {
  createHistoryRepository,
  historyRepository: createHistoryRepository(),
};
