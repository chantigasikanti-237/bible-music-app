const Redis = require("ioredis");

const { config } = require("./env");
const logger = require("./logger");

let redisClient = null;

const getRedisClient = () => {
  if (!config.redisUrl) {
    return null;
  }

  if (redisClient) {
    return redisClient;
  }

  redisClient = new Redis(config.redisUrl, {
    lazyConnect: true,
    maxRetriesPerRequest: 1,
  });

  redisClient.on("error", (error) => {
    logger.warn("Redis client error", {
      error: error.message,
    });
  });

  return redisClient;
};

const ensureRedisConnection = async () => {
  const client = getRedisClient();
  if (!client) {
    return null;
  }

  if (client.status === "ready" || client.status === "connect") {
    return client;
  }

  try {
    await client.connect();
    logger.info("Redis connected successfully");
    return client;
  } catch (error) {
    logger.warn("Redis connection failed", {
      error: error.message,
    });
    return null;
  }
};

const closeRedis = async () => {
  if (redisClient) {
    try {
      await redisClient.quit();
    } catch (_) {
      try {
        redisClient.disconnect();
      } catch (_) {}
    }
    redisClient = null;
  }
};

const getRedisHealth = () => {
  const client = redisClient;
  return {
    configured: Boolean(config.redisUrl),
    ready: Boolean(client && client.status === "ready"),
    status: client ? client.status : "disabled",
  };
};

module.exports = {
  ensureRedisConnection,
  getRedisClient,
  closeRedis,
  getRedisHealth,
};
