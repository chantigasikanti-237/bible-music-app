const ms = require("ms");

const AppError = require("../utils/AppError");

const parseInteger = (value, fallbackValue) => {
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) ? parsed : fallbackValue;
};

const parseBoolean = (value, fallbackValue = false) => {
  if (value === undefined || value === null || value === "") {
    return fallbackValue;
  }

  return ["1", "true", "yes", "on"].includes(
    String(value).trim().toLowerCase()
  );
};

const parseList = (value) =>
  String(value ?? "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);

const parseDurationToMs = (value, fallbackValue) => {
  const parsed = ms(String(value ?? fallbackValue).trim());
  return typeof parsed === "number" ? parsed : ms(fallbackValue);
};

const sanitizeSameSite = (value) => {
  const normalized = String(value || "strict").trim().toLowerCase();
  if (["strict", "lax", "none"].includes(normalized)) {
    return normalized;
  }
  return "strict";
};

const env = String(process.env.NODE_ENV || "development")
  .trim()
  .toLowerCase();

const corsOrigins = parseList(process.env.CORS_ORIGIN || "*");
const allowAnyCorsOrigin =
  corsOrigins.length === 0 ||
  (corsOrigins.length === 1 && corsOrigins[0] === "*");

const config = Object.freeze({
  env,
  isProduction: env === "production",
  port: parseInteger(process.env.PORT, 5000),
  mongoUri: String(process.env.MONGO_URI || "").trim(),
  jwtSecret: String(process.env.JWT_SECRET || "").trim(),
  jwtIssuer: String(process.env.JWT_ISSUER || "bible-backend").trim(),
  jwtAudience: String(process.env.JWT_AUDIENCE || "bible-app").trim(),
  jwtAccessExpiresIn: String(
    process.env.JWT_ACCESS_EXPIRES_IN || "15m"
  ).trim(),
  refreshSessionExpiresIn: String(
    process.env.JWT_REFRESH_EXPIRES_IN || "30d"
  ).trim(),
  refreshSessionTtlMs: parseDurationToMs(
    process.env.JWT_REFRESH_EXPIRES_IN,
    "30d"
  ),
  passwordResetTtlMinutes: parseInteger(
    process.env.PASSWORD_RESET_TTL_MINUTES,
    15
  ),
  passwordResetTtlMs:
    parseInteger(process.env.PASSWORD_RESET_TTL_MINUTES, 15) * 60 * 1000,
  emailVerificationTtlMinutes: parseInteger(
    process.env.EMAIL_VERIFICATION_TTL_MINUTES,
    60
  ),
  emailVerificationTtlMs:
    parseInteger(process.env.EMAIL_VERIFICATION_TTL_MINUTES, 60) * 60 * 1000,
  bcryptSaltRounds: parseInteger(process.env.BCRYPT_SALT_ROUNDS, 12),
  youVersionAppKey: String(process.env.YOUVERSION_APP_KEY || "").trim(),
  corsOrigins,
  allowAnyCorsOrigin,
  redisUrl: String(process.env.REDIS_URL || "").trim(),
  chapterCacheTtlSeconds: parseInteger(
    process.env.CHAPTER_CACHE_TTL_SECONDS,
    3600
  ),
  logLevel: String(process.env.LOG_LEVEL || "info").trim().toLowerCase(),
  trustProxy: parseBoolean(process.env.TRUST_PROXY, env === "production"),
  authCookieName: String(
    process.env.AUTH_COOKIE_NAME || "refresh_token"
  ).trim(),
  authCookieDomain: String(process.env.AUTH_COOKIE_DOMAIN || "").trim() || null,
  authCookiePath: String(process.env.AUTH_COOKIE_PATH || "/api/auth").trim(),
  authCookieSecure: parseBoolean(
    process.env.AUTH_COOKIE_SECURE,
    env === "production"
  ),
  authCookieSameSite: sanitizeSameSite(process.env.AUTH_COOKIE_SAME_SITE),
  smtpHost: String(process.env.SMTP_HOST || "").trim(),
  smtpPort: parseInteger(process.env.SMTP_PORT, 587),
  smtpSecure: parseBoolean(process.env.SMTP_SECURE, false),
  smtpUser: String(process.env.SMTP_USER || "").trim(),
  smtpPass: String(process.env.SMTP_PASS || "").trim(),
  smtpFrom: String(process.env.SMTP_FROM || process.env.SMTP_USER || "")
    .trim(),
});

const validateEnv = () => {
  const missingVars = [];
  const validationIssues = [];

  if (!config.mongoUri) {
    missingVars.push("MONGO_URI");
  }
  if (!config.jwtSecret) {
    missingVars.push("JWT_SECRET");
  }

  if (missingVars.length > 0) {
    throw new AppError(
      500,
      "Missing required environment variables",
      missingVars
    );
  }

  if (config.isProduction && config.jwtSecret.length < 32) {
    validationIssues.push(
      "JWT_SECRET must be at least 32 characters long in production"
    );
  }

  if (config.isProduction && config.allowAnyCorsOrigin) {
    validationIssues.push(
      "CORS_ORIGIN must be explicitly configured in production"
    );
  }

  if (config.authCookieSameSite === "none" && !config.authCookieSecure) {
    validationIssues.push(
      "AUTH_COOKIE_SECURE must be true when AUTH_COOKIE_SAME_SITE is none"
    );
  }

  if (validationIssues.length > 0) {
    throw new AppError(
      500,
      "Invalid environment configuration",
      validationIssues
    );
  }
};

module.exports = {
  config,
  validateEnv,
};
