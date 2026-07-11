const bcrypt = require("bcrypt");

const logger = require("../config/logger");
const { config } = require("../config/env");
const { userRepository } = require("../repositories/userRepository");
const {
  authSessionRepository,
} = require("../repositories/authSessionRepository");
const {
  loginAttemptRepository,
} = require("../repositories/loginAttemptRepository");
const AppError = require("../utils/AppError");
const {
  createOpaqueSessionToken,
  parseOpaqueSessionToken,
  compareHashedValue,
  createPasswordResetOtp,
  createEmailVerificationOtp,
  hashValue,
} = require("../utils/security");
const {
  signupSchema,
  loginSchema,
  passwordResetRequestSchema,
  passwordResetSchema,
  emailVerificationResendSchema,
  emailVerificationConfirmSchema,
  validateWithSchema,
} = require("../utils/validationSchemas");
const { tokenService } = require("./tokenService");
const { emailService } = require("./emailService");

const INVALID_CREDENTIALS_MESSAGE = "Invalid credentials";
const INVALID_SESSION_MESSAGE = "Invalid or expired session";
const PASSWORD_RESET_REQUEST_MESSAGE =
  "If the account exists, a password reset email will be sent.";
const EMAIL_VERIFICATION_RESEND_MESSAGE =
  "If the account exists and isn't verified yet, a new verification code will be sent.";
const DUMMY_PASSWORD_HASH = bcrypt.hashSync(
  "replace-this-with-a-dummy-password",
  12
);

const toPublicUser = (user) => ({
  id: String(user._id || user.id),
  name: user.name || null,
  email: user.email,
  roles: Array.isArray(user.roles) ? user.roles : ["user"],
  status: user.status || "active",
  preferences: user.preferences || {
    bibleLanguage: "en",
    songsLanguage: "en",
  },
  createdAt: user.createdAt,
  updatedAt: user.updatedAt,
  lastLoginAt: user.lastLoginAt || null,
  emailVerifiedAt: user.emailVerifiedAt || null,
  passwordChangedAt: user.passwordChangedAt || null,
});

const resolveStoredPasswordHash = (user) =>
  String(user.passwordHash || user.password || "");

const logAuthEvent = (message, metadata = {}) => {
  logger.info(message, metadata);
};

const buildAccessToken = (tokens, user, sessionId) =>
  tokens.signAccessToken({
    userId: user._id || user.id,
    sessionId,
    sessionVersion: Number(user.refreshTokenVersion || 0),
    roles: user.roles || ["user"],
  });

const buildSessionExpiry = () =>
  new Date(Date.now() + config.refreshSessionTtlMs);

const createLoginAttemptLogger =
  ({ loginAttemptRepo }) =>
  async ({
    email,
    userId = null,
    ipAddress = null,
    userAgent = null,
    outcome,
    reason = null,
  }) => {
    try {
      await loginAttemptRepo.create({
        email,
        userId,
        ipAddress,
        userAgent,
        outcome,
        reason,
      });
    } catch (error) {
      logger.warn("Failed to persist login attempt", {
        error: error.message,
        email,
        outcome,
      });
    }
  };

const createAuthService = ({
  userRepo = userRepository,
  sessionRepo = authSessionRepository,
  loginAttemptRepo = loginAttemptRepository,
  tokens = tokenService,
  emailer = emailService,
  bcryptLib = bcrypt,
} = {}) => {
  const recordLoginAttempt = createLoginAttemptLogger({ loginAttemptRepo });

  const establishSession = async (user, context) => {
    // We use JWTs only for short-lived access tokens. The refresh credential is
    // an opaque random secret that is hashed in MongoDB, which gives us server-
    // side revocation and one-time rotation without exposing a long-lived JWT.
    const { sessionId, refreshToken, refreshTokenHash } =
      createOpaqueSessionToken();
    const expiresAt = buildSessionExpiry();

    await sessionRepo.create({
      sessionId,
      userId: user._id || user.id,
      refreshTokenHash,
      sessionVersion: Number(user.refreshTokenVersion || 0),
      ipAddress: context.ipAddress || null,
      userAgent: context.userAgent || null,
      expiresAt,
      lastUsedAt: new Date(),
    });

    return {
      accessToken: buildAccessToken(tokens, user, sessionId),
      refreshToken,
      session: {
        id: sessionId,
        expiresAt,
      },
    };
  };

  const revokeAllUserSessions = async (userId, reason) => {
    await Promise.all([
      sessionRepo.revokeAllForUser(userId, reason),
      userRepo.incrementRefreshTokenVersion(userId),
    ]);
  };

  // Verification email is best-effort: a delivery failure (SMTP down, bad
  // config, etc.) must not block account creation. The user can always ask
  // for another code later via resendVerificationEmail.
  const issueEmailVerificationOtp = async (user) => {
    try {
      const verificationOtp = createEmailVerificationOtp(
        config.emailVerificationTtlMs
      );

      await userRepo.setEmailVerificationToken(user._id, {
        tokenHash: verificationOtp.tokenHash,
        expiresAt: verificationOtp.expiresAt,
      });

      await emailer.sendEmailVerificationOtp({
        to: user.email,
        otp: verificationOtp.otp,
        expiresInMinutes: config.emailVerificationTtlMinutes,
      });
    } catch (error) {
      logger.warn("Failed to issue email verification OTP", {
        userId: String(user._id),
        error: error.message,
      });
    }
  };

  return {
    async registerUser(payload) {
      const validatedPayload = validateWithSchema(signupSchema, payload);

      const existingUser = await userRepo.findByEmail(validatedPayload.email);
      if (existingUser) {
        throw new AppError(409, "An account with that email already exists");
      }

      const passwordHash = await bcryptLib.hash(
        validatedPayload.password,
        config.bcryptSaltRounds
      );

      const user = await userRepo.create({
        name: validatedPayload.name || null,
        email: validatedPayload.email,
        passwordHash,
        password: passwordHash,
      });

      logAuthEvent("User registered", {
        userId: String(user._id),
        email: user.email,
      });

      // Fire-and-forget: sending the verification email involves a real SMTP
      // round-trip (seconds). Registration itself must not wait on it, or
      // signup would feel slow. issueEmailVerificationOtp already catches
      // its own errors, so this can't produce an unhandled rejection.
      issueEmailVerificationOtp(user);

      return {
        user: toPublicUser(user),
      };
    },

    async loginUser(payload, context = {}) {
      const validatedPayload = validateWithSchema(loginSchema, payload);
      const user = await userRepo.findByEmail(validatedPayload.email, {
        includeSensitive: true,
      });

      if (!user) {
        await bcryptLib.compare(validatedPayload.password, DUMMY_PASSWORD_HASH);
        await recordLoginAttempt({
          email: validatedPayload.email,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
          outcome: "failure",
          reason: "user_not_found",
        });
        throw new AppError(401, INVALID_CREDENTIALS_MESSAGE);
      }

      if (user.status !== "active") {
        await recordLoginAttempt({
          email: validatedPayload.email,
          userId: user._id,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
          outcome: "failure",
          reason: "user_disabled",
        });
        throw new AppError(401, INVALID_CREDENTIALS_MESSAGE);
      }

      const passwordMatches = await bcryptLib.compare(
        validatedPayload.password,
        resolveStoredPasswordHash(user)
      );

      if (!passwordMatches) {
        await recordLoginAttempt({
          email: validatedPayload.email,
          userId: user._id,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
          outcome: "failure",
          reason: "password_mismatch",
        });
        throw new AppError(401, INVALID_CREDENTIALS_MESSAGE);
      }

      const updatedUser = await userRepo.touchLogin(user._id);
      const sessionBundle = await establishSession(updatedUser, context);

      await recordLoginAttempt({
        email: validatedPayload.email,
        userId: updatedUser._id,
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        outcome: "success",
        reason: "login_success",
      });

      logAuthEvent("User logged in", {
        userId: String(updatedUser._id),
        sessionId: sessionBundle.session.id,
        ipAddress: context.ipAddress || null,
      });

      return {
        accessToken: sessionBundle.accessToken,
        refreshToken: sessionBundle.refreshToken,
        session: sessionBundle.session,
        user: toPublicUser(updatedUser),
      };
    },

    async refreshSession(rawRefreshToken, context = {}) {
      const parsedToken = parseOpaqueSessionToken(rawRefreshToken);
      if (!parsedToken) {
        throw new AppError(401, INVALID_SESSION_MESSAGE);
      }

      const session = await sessionRepo.findBySessionId(parsedToken.sessionId, {
        includeSensitive: true,
      });

      if (!session) {
        throw new AppError(401, INVALID_SESSION_MESSAGE);
      }

      if (
        session.revokedAt ||
        !session.refreshTokenHash ||
        session.expiresAt <= new Date()
      ) {
        throw new AppError(401, INVALID_SESSION_MESSAGE);
      }

      const refreshTokenMatches = compareHashedValue(
        parsedToken.sessionSecret,
        session.refreshTokenHash
      );

      if (!refreshTokenMatches) {
        await revokeAllUserSessions(session.userId, "refresh_token_reuse");
        throw new AppError(401, INVALID_SESSION_MESSAGE);
      }

      const user = await userRepo.findById(session.userId);
      if (!user || user.status !== "active") {
        await sessionRepo.revokeBySessionId(session.sessionId, "user_inactive");
        throw new AppError(401, INVALID_SESSION_MESSAGE);
      }

      if (
        Number(session.sessionVersion || 0) !==
        Number(user.refreshTokenVersion || 0)
      ) {
        await sessionRepo.revokeBySessionId(
          session.sessionId,
          "session_version_mismatch"
        );
        throw new AppError(401, INVALID_SESSION_MESSAGE);
      }

      const rotatedToken = createOpaqueSessionToken();
      const expiresAt = buildSessionExpiry();

      await sessionRepo.rotateSession(session.sessionId, {
        refreshTokenHash: rotatedToken.refreshTokenHash,
        expiresAt,
        ipAddress: context.ipAddress || null,
        userAgent: context.userAgent || null,
      });

      return {
        accessToken: buildAccessToken(tokens, user, session.sessionId),
        refreshToken: `${session.sessionId}.${rotatedToken.refreshToken.split(".")[1]}`,
        session: {
          id: session.sessionId,
          expiresAt,
        },
        user: toPublicUser(user),
      };
    },

    async logoutUser({ sessionId, userId = null }) {
      if (!sessionId) {
        return;
      }

      await sessionRepo.revokeBySessionId(sessionId, "user_logout");

      logAuthEvent("User logged out", {
        userId: userId ? String(userId) : null,
        sessionId,
      });
    },

    async requestPasswordReset(payload) {
      const validatedPayload = validateWithSchema(
        passwordResetRequestSchema,
        payload
      );
      emailer.assertConfigured();

      const user = await userRepo.findByEmail(validatedPayload.email, {
        includeSensitive: true,
      });

      if (!user || user.status !== "active") {
        return {
          message: PASSWORD_RESET_REQUEST_MESSAGE,
        };
      }

      const resetOtp = createPasswordResetOtp(config.passwordResetTtlMs);

      await userRepo.setPasswordResetToken(user._id, {
        tokenHash: resetOtp.tokenHash,
        expiresAt: resetOtp.expiresAt,
      });

      await emailer.sendPasswordResetOtp({
        to: user.email,
        otp: resetOtp.otp,
        expiresInMinutes: config.passwordResetTtlMinutes,
      });

      logAuthEvent("Password reset OTP issued", {
        userId: String(user._id),
        expiresAt: resetOtp.expiresAt.toISOString(),
      });

      return {
        message: PASSWORD_RESET_REQUEST_MESSAGE,
      };
    },

    async resetPassword(payload) {
      const validatedPayload = validateWithSchema(passwordResetSchema, payload);
      const user = await userRepo.findByPasswordResetTokenHash(
        hashValue(validatedPayload.otpCode)
      );

      if (!user || user.status !== "active") {
        throw new AppError(400, "Invalid or expired password reset code");
      }

      const passwordHash = await bcryptLib.hash(
        validatedPayload.password,
        config.bcryptSaltRounds
      );

      const updatedUser = await userRepo.resetPassword(user._id, {
        passwordHash,
        passwordChangedAt: new Date(),
      });

      await sessionRepo.revokeAllForUser(updatedUser._id, "password_reset");

      logAuthEvent("Password reset completed", {
        userId: String(updatedUser._id),
      });

      return {
        user: toPublicUser(updatedUser),
      };
    },

    async resendVerificationEmail(payload) {
      const validatedPayload = validateWithSchema(
        emailVerificationResendSchema,
        payload
      );
      emailer.assertConfigured();

      const user = await userRepo.findByEmail(validatedPayload.email);

      // Same generic response whether the account exists, is already
      // verified, or doesn't exist — avoids leaking which emails are
      // registered (same anti-enumeration pattern as password reset).
      if (!user || user.status !== "active" || user.emailVerifiedAt) {
        return {
          message: EMAIL_VERIFICATION_RESEND_MESSAGE,
        };
      }

      await issueEmailVerificationOtp(user);

      return {
        message: EMAIL_VERIFICATION_RESEND_MESSAGE,
      };
    },

    async verifyEmail(payload) {
      const validatedPayload = validateWithSchema(
        emailVerificationConfirmSchema,
        payload
      );
      const user = await userRepo.findByEmailVerificationTokenHash(
        hashValue(validatedPayload.otpCode)
      );

      if (!user || user.status !== "active") {
        throw new AppError(400, "Invalid or expired verification code");
      }

      const updatedUser = await userRepo.markEmailVerified(user._id);

      logAuthEvent("Email verified", {
        userId: String(updatedUser._id),
      });

      return {
        user: toPublicUser(updatedUser),
      };
    },

    async getCurrentUser(userId) {
      const user = await userRepo.findPublicById(userId);
      if (!user) {
        throw new AppError(404, "User not found");
      }

      return toPublicUser(user);
    },

  };
};

module.exports = {
  createAuthService,
  authService: createAuthService(),
  toPublicUser,
};
