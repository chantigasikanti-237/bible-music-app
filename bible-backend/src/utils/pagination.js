const { Buffer } = require("buffer");
const mongoose = require("mongoose");

const AppError = require("./AppError");

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

const parseLimit = (value, fallbackValue = DEFAULT_LIMIT) => {
  if (value === undefined || value === null || value === "") {
    return fallbackValue;
  }

  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new AppError(400, "limit must be a positive integer");
  }

  return Math.min(parsed, MAX_LIMIT);
};

const parsePage = (value, fallbackValue = 1) => {
  if (value === undefined || value === null || value === "") {
    return fallbackValue;
  }

  const parsed = Number.parseInt(String(value), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new AppError(400, "page must be a positive integer");
  }

  return parsed;
};

const encodeCursor = (payload) =>
  Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");

const decodeCursor = (cursor) => {
  if (!cursor) {
    return null;
  }

  try {
    return JSON.parse(Buffer.from(String(cursor), "base64url").toString("utf8"));
  } catch (_) {
    throw new AppError(400, "Invalid cursor");
  }
};

const buildObjectIdCursorFilter = (cursor, fieldName = "_id") => {
  const decoded = decodeCursor(cursor);
  if (!decoded || !decoded.id) {
    return {};
  }

  if (!mongoose.Types.ObjectId.isValid(decoded.id)) {
    throw new AppError(400, "Invalid cursor");
  }

  return {
    [fieldName]: {
      $lt: new mongoose.Types.ObjectId(decoded.id),
    },
  };
};

const buildNextCursor = (items) => {
  if (!Array.isArray(items) || items.length === 0) {
    return null;
  }

  const lastItem = items[items.length - 1];
  if (!lastItem || !lastItem._id) {
    return null;
  }

  return encodeCursor({
    id: String(lastItem._id),
  });
};

module.exports = {
  DEFAULT_LIMIT,
  MAX_LIMIT,
  parseLimit,
  parsePage,
  encodeCursor,
  decodeCursor,
  buildObjectIdCursorFilter,
  buildNextCursor,
};
