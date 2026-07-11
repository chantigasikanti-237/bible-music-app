const mongoose = require("mongoose");

const { Schema } = mongoose;

// Tracks which songs count against a user's download quota. The actual audio
// file is never stored here (or anywhere server-side) — it lives in the
// browser's IndexedDB on whichever device downloaded it (see offlineMusicStore.ts).
// This just makes the 200/100 quota an account-wide limit instead of a
// per-device one, so it can't be bypassed by switching devices/browsers.
const musicDownloadSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    videoId: {
      type: String,
      required: true,
      trim: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    artist: {
      type: String,
      trim: true,
      default: null,
    },
    image: {
      type: String,
      trim: true,
      default: null,
    },
    language: {
      type: String,
      trim: true,
      default: null,
    },
    isLongMix: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

musicDownloadSchema.index({ userId: 1, videoId: 1 }, { unique: true });

module.exports = mongoose.model("MusicDownload", musicDownloadSchema);
