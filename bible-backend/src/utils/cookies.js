const { config } = require("../config/env");

const buildRefreshCookieOptions = () => ({
  httpOnly: true,
  secure: config.authCookieSecure,
  sameSite: config.authCookieSameSite,
  path: config.authCookiePath,
  domain: config.authCookieDomain || undefined,
  maxAge: config.refreshSessionTtlMs,
});

const setRefreshTokenCookie = (res, refreshToken) => {
  res.cookie(config.authCookieName, refreshToken, buildRefreshCookieOptions());
};

const clearRefreshTokenCookie = (res) => {
  res.clearCookie(config.authCookieName, buildRefreshCookieOptions());
};

module.exports = {
  buildRefreshCookieOptions,
  setRefreshTokenCookie,
  clearRefreshTokenCookie,
};
