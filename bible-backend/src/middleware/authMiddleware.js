const AppError = require("../utils/AppError");
const asyncHandler = require("../utils/asyncHandler");
const { userRepository } = require("../repositories/userRepository");
const {
  authSessionRepository,
} = require("../repositories/authSessionRepository");
const { tokenService } = require("../services/tokenService");
const { getRequestIp, getRequestUserAgent } = require("../utils/http");

const authMiddleware = asyncHandler(async (req, _res, next) => {
  const authHeader = req.headers.authorization || "";

  if (!authHeader.startsWith("Bearer ")) {
    throw new AppError(401, "Authorization token is required");
  }

  const accessToken = authHeader.split(" ")[1];
  const decodedToken = tokenService.verifyAccessToken(accessToken);

  if (decodedToken.type !== "access" || !decodedToken.sid || !decodedToken.sub) {
    throw new AppError(401, "Invalid or expired access token");
  }

  const [user, session] = await Promise.all([
    userRepository.findPublicById(decodedToken.sub),
    authSessionRepository.findActiveBySessionId(decodedToken.sid),
  ]);

  if (!user || user.status !== "active") {
    throw new AppError(401, "Invalid or expired access token");
  }

  if (!session || String(session.userId) !== String(user._id)) {
    throw new AppError(401, "Invalid or expired access token");
  }

  if (
    Number(decodedToken.sv || 0) !== Number(user.refreshTokenVersion || 0) ||
    Number(session.sessionVersion || 0) !== Number(user.refreshTokenVersion || 0)
  ) {
    throw new AppError(401, "Session has been revoked");
  }

  const lastUsedAtMs = session.lastUsedAt
    ? new Date(session.lastUsedAt).getTime()
    : 0;
  if (Date.now() - lastUsedAtMs > 5 * 60 * 1000) {
    await authSessionRepository.touchSession(session.sessionId, {
      ipAddress: getRequestIp(req),
      userAgent: getRequestUserAgent(req),
    });
  }

  req.user = user;
  req.auth = {
    sessionId: session.sessionId,
    tokenVersion: Number(user.refreshTokenVersion || 0),
  };

  next();
});

module.exports = authMiddleware;
