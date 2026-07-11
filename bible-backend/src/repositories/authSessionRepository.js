const AuthSession = require("../models/AuthSession");

const SENSITIVE_SESSION_FIELDS = "+refreshTokenHash";

const withSensitiveFields = (query, includeSensitive) => {
  if (!includeSensitive) {
    return query;
  }

  return query.select(SENSITIVE_SESSION_FIELDS);
};

const createAuthSessionRepository = ({ model = AuthSession } = {}) => ({
  async create(payload) {
    return model.create(payload);
  },

  async findBySessionId(sessionId, { includeSensitive = false } = {}) {
    const query = model.findOne({ sessionId });
    return withSensitiveFields(query, includeSensitive).exec();
  },

  async findActiveBySessionId(sessionId, { includeSensitive = false } = {}) {
    const query = model.findOne({
      sessionId,
      revokedAt: null,
      expiresAt: {
        $gt: new Date(),
      },
    });

    return withSensitiveFields(query, includeSensitive).exec();
  },

  async rotateSession(
    sessionId,
    { refreshTokenHash, expiresAt, ipAddress, userAgent }
  ) {
    return model
      .findOneAndUpdate(
        {
          sessionId,
          revokedAt: null,
        },
        {
          $set: {
            refreshTokenHash,
            expiresAt,
            ipAddress,
            userAgent,
            lastUsedAt: new Date(),
          },
        },
        {
          new: true,
        }
      )
      .exec();
  },

  async touchSession(sessionId, { ipAddress, userAgent } = {}) {
    return model
      .findOneAndUpdate(
        {
          sessionId,
          revokedAt: null,
        },
        {
          $set: {
            lastUsedAt: new Date(),
            ipAddress: ipAddress ?? null,
            userAgent: userAgent ?? null,
          },
        },
        {
          new: true,
        }
      )
      .exec();
  },

  async revokeBySessionId(sessionId, reason) {
    return model
      .findOneAndUpdate(
        {
          sessionId,
          revokedAt: null,
        },
        {
          $set: {
            revokedAt: new Date(),
            revokeReason: reason,
          },
        },
        {
          new: true,
        }
      )
      .exec();
  },

  async revokeAllForUser(userId, reason) {
    return model.updateMany(
      {
        userId,
        revokedAt: null,
      },
      {
        $set: {
          revokedAt: new Date(),
          revokeReason: reason,
        },
      }
    );
  },
});

module.exports = {
  createAuthSessionRepository,
  authSessionRepository: createAuthSessionRepository(),
};
