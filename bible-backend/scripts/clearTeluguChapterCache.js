/**
 * One-time migration: deletes all BibleChapter records for Telugu (versionId=2692)
 * that were cached with incorrect verse counts due to the extractBalancedSpan bug.
 *
 * Usage:
 *   node bible-backend/scripts/clearTeluguChapterCache.js
 *
 * MONGO_URI is read from the .env file in the bible-backend directory.
 */

require("dotenv").config({ path: require("path").join(__dirname, "../.env") });
const mongoose = require("mongoose");
const BibleChapter = require("../src/models/BibleChapter");

async function run() {
  const uri = process.env.MONGO_URI;
  if (!uri) {
    console.error("MONGO_URI is not set — check bible-backend/.env");
    process.exit(1);
  }

  await mongoose.connect(uri);
  console.log("Connected to MongoDB");

  const result = await BibleChapter.deleteMany({ versionId: 2692 });
  console.log(
    `Deleted ${result.deletedCount} Telugu (versionId=2692) chapter(s) from MongoDB`
  );

  await mongoose.disconnect();
  console.log("Done");
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
