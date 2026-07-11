const mongoose = require("mongoose");

const { Schema } = mongoose;

const chapterVerseSchema = new Schema(
  {
    number: {
      type: Number,
      required: true,
      min: 1,
    },
    text: {
      type: String,
      required: true,
      trim: true,
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
    url: {
      type: String,
      trim: true,
      default: null,
    },
    storageKey: {
      type: String,
      trim: true,
      default: null,
    },
  },
  {
    _id: false,
  }
);

const sourceSchema = new Schema(
  {
    type: {
      type: String,
      trim: true,
      default: null,
    },
    provider: {
      type: String,
      trim: true,
      default: null,
    },
    fetchedAt: {
      type: Date,
      default: null,
    },
  },
  {
    _id: false,
  }
);

const bibleChapterSchema = new Schema(
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
    passageId: {
      type: String,
      required: true,
      trim: true,
    },
    verseCount: {
      type: Number,
      required: true,
      min: 0,
    },
    content: {
      type: String,
      required: true,
    },
    verses: {
      type: [chapterVerseSchema],
      default: [],
    },
    audio: {
      type: audioSchema,
      default: () => ({}),
    },
    source: {
      type: sourceSchema,
      default: () => ({}),
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

bibleChapterSchema.index({ versionId: 1, bookId: 1, chapterNumber: 1 }, { unique: true });
bibleChapterSchema.index({ versionId: 1, passageId: 1 });

module.exports = mongoose.model("BibleChapter", bibleChapterSchema);
