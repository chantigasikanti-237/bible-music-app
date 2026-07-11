const mongoose = require("mongoose");

const { Schema } = mongoose;

const historySchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    bibleId: {
      type: Number,
      required: true,
      min: 1,
    },
    versionId: {
      type: Number,
      default: null,
    },
    languageCode: {
      type: String,
      trim: true,
      default: null,
    },
    bookId: {
      type: String,
      trim: true,
      default: null,
    },
    chapterNumber: {
      type: Number,
      min: 1,
      default: null,
    },
    passageId: {
      type: String,
      required: true,
      trim: true,
    },
    reference: {
      type: String,
      trim: true,
      default: null,
    },
    lastReadAt: {
      type: Date,
      required: true,
      default: Date.now,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

historySchema.index({ userId: 1, bibleId: 1, passageId: 1 }, { unique: true });
historySchema.index({ userId: 1, lastReadAt: -1, _id: -1 });

module.exports = mongoose.model("History", historySchema);
