const test = require("node:test");
const assert = require("node:assert/strict");

const { createAuthService } = require("../src/services/authService");
const {
  createOpaqueSessionToken,
  hashValue,
} = require("../src/utils/security");

const buildTokens = () => ({
  signAccessToken({ userId, sessionId, sessionVersion }) {
    return `access:${userId}:${sessionId}:${sessionVersion}`;
  },
});

test("registerUser hashes passwords before saving the user", async () => {
  const createdPayloads = [];
  const authService = createAuthService({
    userRepo: {
      async findByEmail() {
        return null;
      },
      async create(payload) {
        createdPayloads.push(payload);
        return {
          _id: "user-1",
          ...payload,
          roles: ["user"],
          status: "active",
          preferences: {
            bibleLanguage: "en",
            songsLanguage: "en",
          },
          mfa: {
            enabled: false,
            enabledAt: null,
          },
          refreshTokenVersion: 0,
          createdAt: new Date("2026-04-19T00:00:00.000Z"),
          updatedAt: new Date("2026-04-19T00:00:00.000Z"),
        };
      },
      async incrementRefreshTokenVersion() {
        throw new Error("should not be called");
      },
    },
    sessionRepo: {
      async create() {
        throw new Error("should not create a session during signup");
      },
      async revokeAllForUser() {
        throw new Error("should not be called");
      },
    },
    loginAttemptRepo: {
      async create() {},
    },
    tokens: buildTokens(),
  });

  const result = await authService.registerUser({
    email: "test@example.com",
    password: "correct horse battery",
    name: "Test User",
  });

  assert.equal(result.user.email, "test@example.com");
  assert.equal(createdPayloads.length, 1);
  assert.notEqual(createdPayloads[0].passwordHash, "correct horse battery");
  assert.equal(createdPayloads[0].password, createdPayloads[0].passwordHash);
});

test("loginUser returns a generic error when the email is unknown", async () => {
  const authService = createAuthService({
    userRepo: {
      async findByEmail() {
        return null;
      },
      async incrementRefreshTokenVersion() {},
    },
    sessionRepo: {
      async create() {
        throw new Error("should not create a session");
      },
      async revokeAllForUser() {},
    },
    loginAttemptRepo: {
      async create() {},
    },
    tokens: buildTokens(),
  });

  await assert.rejects(
    () =>
      authService.loginUser(
        {
          email: "missing@example.com",
          password: "whatever-password",
        },
        {
          ipAddress: "127.0.0.1",
          userAgent: "node-test",
        }
      ),
    /Invalid credentials/
  );
});

test("refreshSession rotates the refresh secret and returns a new access token", async () => {
  const initialToken = createOpaqueSessionToken();
  let rotatedHash = null;
  let rotatedExpiresAt = null;

  const authService = createAuthService({
    userRepo: {
      async findById() {
        return {
          _id: "user-1",
          email: "test@example.com",
          roles: ["user"],
          status: "active",
          preferences: {
            bibleLanguage: "en",
            songsLanguage: "en",
          },
          mfa: {
            enabled: false,
            enabledAt: null,
          },
          refreshTokenVersion: 2,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
      },
      async incrementRefreshTokenVersion() {
        throw new Error("should not revoke all sessions");
      },
    },
    sessionRepo: {
      async findBySessionId(sessionId) {
        assert.equal(sessionId, initialToken.sessionId);
        return {
          sessionId: initialToken.sessionId,
          userId: "user-1",
          refreshTokenHash: initialToken.refreshTokenHash,
          sessionVersion: 2,
          expiresAt: new Date(Date.now() + 60_000),
          revokedAt: null,
        };
      },
      async rotateSession(sessionId, payload) {
        assert.equal(sessionId, initialToken.sessionId);
        rotatedHash = payload.refreshTokenHash;
        rotatedExpiresAt = payload.expiresAt;
        return {
          sessionId,
          ...payload,
        };
      },
      async revokeAllForUser() {
        throw new Error("should not revoke all sessions");
      },
      async revokeBySessionId() {
        throw new Error("should not revoke the active session");
      },
    },
    loginAttemptRepo: {
      async create() {},
    },
    tokens: buildTokens(),
  });

  const result = await authService.refreshSession(initialToken.refreshToken, {
    ipAddress: "127.0.0.1",
    userAgent: "node-test",
  });

  assert.match(result.accessToken, /^access:user-1:/);
  assert.match(result.refreshToken, new RegExp(`^${initialToken.sessionId}\\.`));
  assert.notEqual(hashValue(result.refreshToken.split(".")[1]), initialToken.refreshTokenHash);
  assert.equal(rotatedHash, hashValue(result.refreshToken.split(".")[1]));
  assert.ok(rotatedExpiresAt instanceof Date);
});

test("resetPassword revokes every old session after updating the password", async () => {
  const revokedUsers = [];

  const authService = createAuthService({
    userRepo: {
      async findByPasswordResetTokenHash(tokenHash) {
        assert.equal(tokenHash, hashValue("123456"));
        return {
          _id: "user-1",
          email: "test@example.com",
          roles: ["user"],
          status: "active",
          preferences: {
            bibleLanguage: "en",
            songsLanguage: "en",
          },
          mfa: {
            enabled: false,
            enabledAt: null,
          },
          refreshTokenVersion: 4,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
      },
      async resetPassword(id, { passwordHash }) {
        assert.equal(id, "user-1");
        assert.notEqual(passwordHash, "new-password-123");
        return {
          _id: "user-1",
          email: "test@example.com",
          roles: ["user"],
          status: "active",
          preferences: {
            bibleLanguage: "en",
            songsLanguage: "en",
          },
          mfa: {
            enabled: false,
            enabledAt: null,
          },
          refreshTokenVersion: 5,
          createdAt: new Date(),
          updatedAt: new Date(),
          passwordChangedAt: new Date(),
        };
      },
      async incrementRefreshTokenVersion() {
        throw new Error("resetPassword handles version changes itself");
      },
    },
    sessionRepo: {
      async revokeAllForUser(userId, reason) {
        revokedUsers.push({ userId, reason });
      },
      async create() {
        throw new Error("not used");
      },
    },
    loginAttemptRepo: {
      async create() {},
    },
    tokens: buildTokens(),
  });

  const result = await authService.resetPassword({
    otpCode: "123456",
    password: "new-password-123",
    confirmPassword: "new-password-123",
  });

  assert.equal(result.user.email, "test@example.com");
  assert.deepEqual(revokedUsers, [
    {
      userId: "user-1",
      reason: "password_reset",
    },
  ]);
});

test("requestPasswordReset stores an OTP hash and emails the code", async () => {
  const savedTokens = [];
  const sentMessages = [];

  const authService = createAuthService({
    userRepo: {
      async findByEmail(email) {
        assert.equal(email, "test@example.com");
        return {
          _id: "user-1",
          email,
          status: "active",
        };
      },
      async setPasswordResetToken(userId, payload) {
        assert.equal(userId, "user-1");
        savedTokens.push(payload);
      },
      async incrementRefreshTokenVersion() {},
    },
    sessionRepo: {
      async create() {
        throw new Error("not used");
      },
      async revokeAllForUser() {},
    },
    loginAttemptRepo: {
      async create() {},
    },
    emailer: {
      assertConfigured() {},
      async sendPasswordResetOtp(message) {
        sentMessages.push(message);
      },
    },
    tokens: buildTokens(),
  });

  const result = await authService.requestPasswordReset({
    email: "test@example.com",
  });

  assert.match(result.message, /password reset email/);
  assert.equal(result.debug, undefined);
  assert.equal(savedTokens.length, 1);
  assert.equal(sentMessages.length, 1);
  assert.equal(sentMessages[0].to, "test@example.com");
  assert.match(sentMessages[0].otp, /^\d{6}$/);
  assert.equal(savedTokens[0].tokenHash, hashValue(sentMessages[0].otp));
});
