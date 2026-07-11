const mongoose = require("mongoose");

const { Schema } = mongoose;

const bibleVerseSchema = new Schema(
  {
    versionId: {
      type: Number,
      required: true,
      min: 1,
    },
    languageCode: {
      type: String,
      trim: true,
      default: null,
    },
    bookId: {
      type: String,
      required: true,
      trim: true,
    },
    bookName: {
      type: String,
      required: true,
      trim: true,
    },
    chapterNumber: {
      type: Number,
      required: true,
      min: 1,
    },
    verseNumber: {
      type: Number,
      required: true,
      min: 1,
    },
    reference: {
      type: String,
      required: true,
      trim: true,
    },
    passageId: {
      type: String,
      required: true,
      trim: true,
    },
    chapterKey: {
      type: String,
      required: true,
      trim: true,
    },
    text: {
      type: String,
      required: true,
      trim: true,
    },
    normalizedText: {
      type: String,
      required: true,
      trim: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

bibleVerseSchema.index(
  { versionId: 1, bookId: 1, chapterNumber: 1, verseNumber: 1 },
  { unique: true }
);
bibleVerseSchema.index({ normalizedText: 1 });
bibleVerseSchema.index({ versionId: 1, passageId: 1 });

module.exports = mongoose.model("BibleVerse", bibleVerseSchema);
