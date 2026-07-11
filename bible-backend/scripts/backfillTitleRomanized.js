const path = require("path");
const mongoose = require("mongoose");

require("dotenv").config({
  path: path.resolve(__dirname, "../.env"),
});

const Song = require("../src/models/Song");
const { transliterateTitle } = require("../src/utils/transliterate");

const BATCH_SIZE = 500;

const getMongoUri = () => {
  const uri = String(process.env.MONGO_URI || "").trim();
  if (!uri) {
    throw new Error("MONGO_URI is required");
  }
  return uri;
};

const backfill = async () => {
  await mongoose.connect(getMongoUri(), { autoIndex: false });

  const cursor = Song.find(
    { titleRomanized: null },
    { title: 1, languageCode: 1 }
  )
    .lean()
    .cursor();

  let scanned = 0;
  let updated = 0;
  let batch = [];

  const flush = async () => {
    if (batch.length === 0) return;
    const result = await Song.bulkWrite(batch, { ordered: false });
    updated += result.modifiedCount || 0;
    batch = [];
  };

  for await (const song of cursor) {
    scanned += 1;
    batch.push({
      updateOne: {
        filter: { _id: song._id },
        update: {
          $set: {
            titleRomanized: transliterateTitle(song.title, song.languageCode),
          },
        },
      },
    });

    if (batch.length >= BATCH_SIZE) {
      await flush();
    }
  }

  await flush();

  return { scanned, updated };
};

backfill()
  .then((summary) => {
    console.log("titleRomanized backfill completed");
    console.log(JSON.stringify(summary, null, 2));
  })
  .catch((error) => {
    console.error("titleRomanized backfill failed");
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await mongoose.disconnect();
  });
