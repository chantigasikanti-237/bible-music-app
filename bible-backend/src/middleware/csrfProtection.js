const { config } = require("../config/env");
const AppError = require("../utils/AppError");

const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);
const SAME_SITE_VALUES = new Set(["same-origin", "same-site", "none"]);

const isAllowedOrigin = (origin) => {
  if (!origin) {
    return true;
  }

  if (config.allowAnyCorsOrigin) {
    return !config.isProduction;
  }

  return config.corsOrigins.includes(origin);
};

const csrfProtection = (req, _res, next) => {
  if (SAFE_METHODS.has(req.method)) {
    return next();
  }

  // CSRF matters only when the browser auto-sends the refresh cookie. Native
  // clients using bearer tokens or explicit refresh payloads skip this branch.
  const hasRefreshCookie = Boolean(req.cookies?.[config.authCookieName]);
  if (!hasRefreshCookie) {
    return next();
  }

  const origin = req.get("origin");
  const fetchSite = String(req.get("sec-fetch-site") || "")
    .trim()
    .toLowerCase();

  if (!isAllowedOrigin(origin)) {
    return next(new AppError(403, "Cross-site request blocked"));
  }

  if (fetchSite && !SAME_SITE_VALUES.has(fetchSite)) {
    return next(new AppError(403, "Cross-site request blocked"));
  }

  return next();
};

module.exports = csrfProtection;
