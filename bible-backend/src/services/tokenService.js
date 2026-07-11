const jwt = require("jsonwebtoken");

const { config } = require("../config/env");
const AppError = require("../utils/AppError");

const createTokenService = ({
  jwtSecret = config.jwtSecret,
  accessExpiresIn = config.jwtAccessExpiresIn,
  jwtIssuer = config.jwtIssuer,
  jwtAudience = config.jwtAudience,
} = {}) => ({
  signAccessToken({ userId, sessionId, sessionVersion, roles = [] }) {
    return jwt.sign(
      {
        type: "access",
        sid: String(sessionId),
        sv: Number(sessionVersion || 0),
        roles,
      },
      jwtSecret,
      {
        expiresIn: accessExpiresIn,
        issuer: jwtIssuer,
        audience: jwtAudience,
        subject: String(userId),
      }
    );
  },

  verifyAccessToken(token) {
    try {
      return jwt.verify(token, jwtSecret, {
        issuer: jwtIssuer,
        audience: jwtAudience,
      });
    } catch (_) {
      throw new AppError(401, "Invalid or expired access token");
    }
  },
});

module.exports = {
  createTokenService,
  tokenService: createTokenService(),
};
