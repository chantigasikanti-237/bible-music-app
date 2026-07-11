const mongoose = require("mongoose");

const { Schema } = mongoose;

const chapterSchema = new Schema(
  {
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
    content: {
      type: String,
      required: true,
    },
    audioUrl: {
      type: String,
      trim: true,
      default: null,
    },
    verses: {
      type: [
        new Schema(
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
        ),
      ],
      default: undefined,
    },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
    versionKey: false,
  }
);

chapterSchema.index({ bibleId: 1, passageId: 1 }, { unique: true });

module.exports = mongoose.model("Chapter", chapterSchema);
