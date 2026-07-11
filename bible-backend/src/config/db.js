const mongoose = require("mongoose");

const { config } = require("./env");
const logger = require("./logger");

const connectDB = async () => {
  try {
    await mongoose.connect(config.mongoUri, {
      autoIndex: config.env !== "production",
    });
    logger.info("MongoDB connected successfully");
  } catch (error) {
    logger.error("MongoDB connection failed", {
      error: error.message,
    });
    throw error;
  }
};

const disconnectDB = async () => {
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
  }
};

const getDatabaseHealth = () => ({
  readyState: mongoose.connection.readyState,
  ready:
    mongoose.connection.readyState === 1 || mongoose.connection.readyState === 2,
  host: mongoose.connection.host || null,
  name: mongoose.connection.name || null,
});

module.exports = {
  connectDB,
  disconnectDB,
  getDatabaseHealth,
};
