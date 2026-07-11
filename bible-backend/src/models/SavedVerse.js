const mongoose = require("mongoose");

const { Schema } = mongoose;

const savedVerseSchema = new Schema(
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
    passageId: {
      type: String,
      required: true,
      trim: true,
    },
    verseNumber: {
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
    timestamps: { createdAt: true, updatedAt: false },
    versionKey: false,
  }
);

module.exports = mongoose.model("SavedVerse", savedVerseSchema);
