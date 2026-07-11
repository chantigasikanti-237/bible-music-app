const User = require("../models/User");

const PUBLIC_USER_FIELDS = [
  "_id",
  "name",
  "photo",
  "email",
  "roles",
  "status",
  "preferences",
  "refreshTokenVersion",
  "passwordChangedAt",
  "createdAt",
  "updatedAt",
  "lastLoginAt",
  "emailVerifiedAt",
].join(" ");

const SENSITIVE_USER_FIELDS = [
  "+passwordHash",
  "+password",
  "+passwordResetTokenHash",
  "+passwordResetExpiresAt",
  "+emailVerificationTokenHash",
  "+emailVerificationExpiresAt",
].join(" ");

const normalizeEmail = (email) => String(email ?? "").trim().toLowerCase();

const withSensitiveFields = (query, includeSensitive) => {
  if (!includeSensitive) {
    return query;
  }

  return query.select(SENSITIVE_USER_FIELDS);
};

const createUserRepository = ({ model = User } = {}) => ({
  async findByEmail(email, { includeSensitive = false } = {}) {
    const normalizedEmail = normalizeEmail(email);
    const query = model.findOne({ email: normalizedEmail });
    return withSensitiveFields(query, includeSensitive).exec();
  },

  async findById(id, { includeSensitive = false } = {}) {
    const query = model.findById(id);
    return withSensitiveFields(query, includeSensitive).exec();
  },

  async findPublicById(id) {
    return model.findById(id).select(PUBLIC_USER_FIELDS).lean().exec();
  },

  async findByPasswordResetTokenHash(tokenHash) {
    return model
      .findOne({
        passwordResetTokenHash: tokenHash,
        passwordResetExpiresAt: {
          $gt: new Date(),
        },
      })
      .select(SENSITIVE_USER_FIELDS)
      .exec();
  },

  async create(payload) {
    return model.create(payload);
  },

  async touchLogin(id) {
    return model
      .findByIdAndUpdate(
        id,
        {
          $set: {
            lastLoginAt: new Date(),
          },
        },
        { new: true }
      )
      .exec();
  },

  async incrementRefreshTokenVersion(id) {
    return model
      .findByIdAndUpdate(
        id,
        {
          $inc: {
            refreshTokenVersion: 1,
          },
        },
        { new: true }
      )
      .exec();
  },

  async setPasswordResetToken(id, { tokenHash, expiresAt }) {
    return model
      .findByIdAndUpdate(
        id,
        {
          $set: {
            passwordResetTokenHash: tokenHash,
            passwordResetExpiresAt: expiresAt,
          },
        },
        { new: true }
      )
      .exec();
  },

  async setEmailVerificationToken(id, { tokenHash, expiresAt }) {
    return model
      .findByIdAndUpdate(
        id,
        {
          $set: {
            emailVerificationTokenHash: tokenHash,
            emailVerificationExpiresAt: expiresAt,
          },
        },
        { new: true }
      )
      .exec();
  },

  async findByEmailVerificationTokenHash(tokenHash) {
    return model
      .findOne({
        emailVerificationTokenHash: tokenHash,
        emailVerificationExpiresAt: {
          $gt: new Date(),
        },
      })
      .select(SENSITIVE_USER_FIELDS)
      .exec();
  },

  async markEmailVerified(id) {
    return model
      .findByIdAndUpdate(
        id,
        {
          $set: {
            emailVerifiedAt: new Date(),
            emailVerificationTokenHash: null,
            emailVerificationExpiresAt: null,
          },
        },
        { new: true }
      )
      .exec();
  },

  async updatePhoto(id, dataUrl) {
    return model
      .findByIdAndUpdate(id, { $set: { photo: dataUrl } }, { new: true })
      .select(PUBLIC_USER_FIELDS)
      .lean()
      .exec();
  },

  async updateProfile(id, { name, preferences } = {}) {
    const $set = {};
    if (name !== undefined) $set.name = name;
    if (preferences?.bibleLanguage !== undefined) $set['preferences.bibleLanguage'] = preferences.bibleLanguage;
    if (preferences?.songsLanguage !== undefined) $set['preferences.songsLanguage'] = preferences.songsLanguage;
    return model
      .findByIdAndUpdate(id, { $set }, { new: true, runValidators: true })
      .select(PUBLIC_USER_FIELDS)
      .lean()
      .exec();
  },

  async resetPassword(id, { passwordHash, passwordChangedAt }) {
    return model
      .findByIdAndUpdate(
        id,
        {
          $set: {
            passwordHash,
            password: passwordHash,
            passwordChangedAt,
            passwordResetTokenHash: null,
            passwordResetExpiresAt: null,
          },
          $inc: {
            refreshTokenVersion: 1,
          },
        },
        { new: true }
      )
      .exec();
  },

});

module.exports = {
  createUserRepository,
  userRepository: createUserRepository(),
  PUBLIC_USER_FIELDS,
};
