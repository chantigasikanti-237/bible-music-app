const logger = require("../config/logger");

const requestLogger = (req, res, next) => {
  const startTime = Date.now();

  res.on("finish", () => {
    logger.info("HTTP request completed", {
      requestId: req.requestId || null,
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs: Date.now() - startTime,
      ip: req.ip,
      userId: req.user?._id ? String(req.user._id) : null,
    });
  });

  next();
};

module.exports = requestLogger;
