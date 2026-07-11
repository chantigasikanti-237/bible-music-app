require("dotenv").config();

const http = require("http");
const app = require("./app");
const logger = require("./src/config/logger");
const { connectDB, disconnectDB } = require("./src/config/db");
const { closeRedis, ensureRedisConnection } = require("./src/config/redis");
const { validateEnv, config } = require("./src/config/env");

const startServer = async () => {
  validateEnv();
  await connectDB();
  await ensureRedisConnection();

  const server = http.createServer(app);

  server.listen(config.port, "0.0.0.0", () => {
    logger.info("Server running", {
      port: config.port,
      environment: config.env,
    });
  });

  const shutdown = async (signal) => {
    logger.info("Shutdown signal received", { signal });
    server.close(async () => {
      await closeRedis();
      await disconnectDB();
      logger.info("HTTP server closed");
      process.exit(0);
    });
  };

  process.on("SIGINT", () => {
    shutdown("SIGINT").catch((error) => {
      logger.error("Shutdown failed", {
        signal: "SIGINT",
        error: error.message,
      });
      process.exit(1);
    });
  });
  process.on("SIGTERM", () => {
    shutdown("SIGTERM").catch((error) => {
      logger.error("Shutdown failed", {
        signal: "SIGTERM",
        error: error.message,
      });
      process.exit(1);
    });
  });

  process.on("unhandledRejection", (reason) => {
    logger.error("Unhandled rejection", {
      reason:
        reason instanceof Error
          ? { message: reason.message, stack: reason.stack }
          : reason,
    });
  });

  process.on("uncaughtException", (error) => {
    logger.error("Uncaught exception", {
      error: error.message,
      stack: error.stack,
    });
    process.exit(1);
  });
};

startServer().catch((error) => {
  logger.error("Failed to start server", {
    error: error.message,
    stack: error.stack || null,
  });
  if (error.details) {
    logger.error("Startup error details", {
      details: error.details,
    });
  }
  process.exit(1);
});
