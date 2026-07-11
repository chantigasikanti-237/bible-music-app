const mongoose = require("mongoose");

const { Schema } = mongoose;

const userSchema = new Schema(
  {
    name: {
      type: String,
      trim: true,
      maxlength: 100,
      default: null,
    },
    photo: {
      type: String,
      default: null,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    passwordHash: {
      type: String,
      required: true,
      minlength: 60,
      select: false,
    },
    // Legacy field kept so older data can still be migrated safely.
    password: {
      type: String,
      required: false,
      minlength: 60,
      select: false,
    },
    roles: {
      type: [String],
      default: ["user"],
    },
    status: {
      type: String,
      enum: ["active", "disabled"],
      default: "active",
    },
    preferences: {
      bibleLanguage: {
        type: String,
        trim: true,
        default: "en",
      },
      songsLanguage: {
        type: String,
        trim: true,
        default: "en",
      },
    },
    refreshTokenVersion: {
      type: Number,
      default: 0,
      min: 0,
    },
    passwordChangedAt: {
      type: Date,
      default: null,
    },
    passwordResetTokenHash: {
      type: String,
      default: null,
      select: false,
    },
    passwordResetExpiresAt: {
      type: Date,
      default: null,
      select: false,
    },
    emailVerifiedAt: {
      type: Date,
      default: null,
    },
    emailVerificationTokenHash: {
      type: String,
      default: null,
      select: false,
    },
    emailVerificationExpiresAt: {
      type: Date,
      default: null,
      select: false,
    },
    lastLoginAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

userSchema.index({ email: 1 }, { unique: true });

module.exports = mongoose.model("User", userSchema);
