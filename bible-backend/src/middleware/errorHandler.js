const logger = require("../config/logger");
const { config } = require("../config/env");
const AppError = require("../utils/AppError");

const notFound = (req, _res, next) => {
  next(new AppError(404, `Route not found: ${req.method} ${req.originalUrl}`));
};

const errorHandler = (error, req, res, _next) => {
  let statusCode = error.statusCode || 500;
  let message = error.message || "Internal server error";
  let details = error.details || null;

  if (error.name === "ValidationError") {
    statusCode = 400;
    message = "Validation failed";
    details = null;
  }

  if (error.name === "CastError") {
    statusCode = 400;
    message = `Invalid ${error.path}`;
    details = null;
  }

  if (error.code === 11000) {
    statusCode = 409;
    message = error.keyPattern?.email
      ? "An account with that email already exists"
      : "Duplicate resource";
    details = null;
  }

  if (statusCode >= 500) {
    logger.error("Unhandled application error", {
      requestId: req.requestId || null,
      path: req.originalUrl,
      method: req.method,
      error: error.message,
      stack: error.stack || null,
    });
  }

  const responsePayload = {
    success: false,
    message,
    requestId: req.requestId || null,
  };

  if (!config.isProduction && details) {
    responsePayload.details = details;
  }

  res.status(statusCode).json(responsePayload);
};

module.exports = {
  notFound,
  errorHandler,
};
