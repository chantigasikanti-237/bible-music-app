const mongoose = require("mongoose");

const { Schema } = mongoose;

const verseRefSchema = new Schema(
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
      trim: true,
      default: null,
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

const songRefSchema = new Schema(
  {
    songId: {
      type: String,
      required: true,
      trim: true,
    },
    languageCode: {
      type: String,
      trim: true,
      default: null,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    slug: {
      type: String,
      trim: true,
      default: null,
    },
  },
  {
    _id: false,
  }
);

const bookmarkSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    targetType: {
      type: String,
      enum: ["verse", "song"],
      required: true,
    },
    targetKey: {
      type: String,
      required: true,
      trim: true,
    },
    folderId: {
      type: String,
      trim: true,
      default: null,
    },
    folderName: {
      type: String,
      trim: true,
      default: null,
    },
    note: {
      type: String,
      trim: true,
      default: null,
    },
    verseRef: {
      type: verseRefSchema,
      default: null,
    },
    songRef: {
      type: songRefSchema,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  }
);

bookmarkSchema.index({ userId: 1, targetKey: 1 }, { unique: true });
bookmarkSchema.index({ userId: 1, createdAt: -1, _id: -1 });

module.exports = mongoose.model("Bookmark", bookmarkSchema);
