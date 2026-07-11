const mongoose = require("mongoose");

const { Schema } = mongoose;

const lyricsSectionSchema = new Schema(
  {
    label: {
      type: String,
      trim: true,
      default: null,
    },
    text: {
      type: String,
      trim: true,
      required: true,
    },
  },
  {
    _id: false,
  }
);

const audioSchema = new Schema(
  {
    provider: {
      type: String,
      trim: true,
      default: null,
    },
    storageKey: {
      type: String,
      trim: true,
      default: null,
    },
    url: {
      type: String,
      trim: true,
      default: null,
    },
    file: {
      type: String,
      trim: true,
      default: null,
    },
    durationSec: {
      type: Number,
      min: 0,
      default: null,
    },
  },
  {
    _id: false,
  }
);

const songSchema = new Schema(
  {
    songId: {
      type: String,
      required: true,
      trim: true,
    },
    languageCode: {
      type: String,
      required: true,
      trim: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    slug: {
      type: String,
      required: true,
      trim: true,
    },
    artist: {
      type: String,
      trim: true,
      default: null,
    },
    lyricsSections: {
      type: [lyricsSectionSchema],
      default: [],
    },
    audio: {
      type: audioSchema,
      default: () => ({}),
    },
    tags: {
      type: [String],
      default: [],
    },
    isPublished: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

songSchema.index({ languageCode: 1, slug: 1 }, { unique: true });
songSchema.index({ languageCode: 1, createdAt: -1, _id: -1 });
songSchema.index({ title: 1, _id: 1 });
songSchema.index({ languageCode: 1, title: 1, _id: 1 });

module.exports = mongoose.model("Song", songSchema);
