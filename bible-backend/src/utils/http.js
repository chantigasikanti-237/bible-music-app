const { config } = require("../config/env");

const getRequestIp = (req) => {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.trim()) {
    return forwarded.split(",")[0].trim();
  }

  return req.ip || req.socket?.remoteAddress || null;
};

const getRequestUserAgent = (req) => {
  const value = req.get("user-agent");
  return value ? String(value).slice(0, 300) : null;
};

const getRefreshTokenFromRequest = (req) => {
  if (req.cookies?.[config.authCookieName]) {
    return String(req.cookies[config.authCookieName]).trim();
  }

  if (req.body?.refreshToken) {
    return String(req.body.refreshToken).trim();
  }

  return null;
};

module.exports = {
  getRequestIp,
  getRequestUserAgent,
  getRefreshTokenFromRequest,
};
