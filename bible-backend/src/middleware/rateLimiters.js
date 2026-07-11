const rateLimit = require("express-rate-limit");
const { RedisStore } = require("rate-limit-redis");

const logger = require("../config/logger");
const { getRedisClient } = require("../config/redis");

const getStore = (prefix) => {
  const redisClient = getRedisClient();
  if (!redisClient) {
    return undefined;
  }

  return new RedisStore({
    prefix,
    sendCommand: (...args) => redisClient.call(...args),
  });
};

const buildHandler = (message, logMessage) => (req, res, _next) => {
  logger.warn(logMessage, {
    ipAddress: req.ip,
    path: req.originalUrl,
    requestId: req.requestId || null,
  });

  res.status(429).json({
    success: false,
    message,
    requestId: req.requestId || null,
  });
};

const buildLimiter = ({
  windowMs,
  max,
  message,
  prefix,
  logMessage,
  skipSuccessfulRequests = false,
}) =>
  rateLimit({
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests,
    store: getStore(prefix),
    handler: buildHandler(message, logMessage),
  });

const apiLimiter = buildLimiter({
  windowMs: 60 * 1000,
  max: 300,
  message: "Too many requests. Please try again shortly.",
  prefix: "rl:api:",
  logMessage: "API rate limit exceeded",
});

const authLimiter = buildLimiter({
  windowMs: 15 * 60 * 1000,
  max: 50,
  message: "Too many authentication requests. Please try again later.",
  prefix: "rl:auth:",
  logMessage: "Authentication rate limit exceeded",
});

const loginLimiter = buildLimiter({
  windowMs: 60 * 1000,
  max: 5,
  message: "Too many login attempts. Please wait a minute and try again.",
  prefix: "rl:login:",
  logMessage: "Login brute-force protection triggered",
});

const passwordResetRequestLimiter = buildLimiter({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message:
    "Too many password reset requests from this IP. Please try again later.",
  prefix: "rl:password-reset-request:",
  logMessage: "Password reset request rate limit exceeded",
});

const emailVerificationResendLimiter = buildLimiter({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message:
    "Too many verification email requests from this IP. Please try again later.",
  prefix: "rl:email-verification-resend:",
  logMessage: "Email verification resend rate limit exceeded",
});

const refreshLimiter = buildLimiter({
  windowMs: 15 * 60 * 1000,
  max: 30,
  message: "Too many session refresh attempts. Please log in again.",
  prefix: "rl:refresh:",
  logMessage: "Refresh rate limit exceeded",
});

module.exports = {
  apiLimiter,
  authLimiter,
  loginLimiter,
  passwordResetRequestLimiter,
  emailVerificationResendLimiter,
  refreshLimiter,
};
