const { config } = require("./env");

const LEVEL_ORDER = {
  error: 0,
  warn: 1,
  info: 2,
  debug: 3,
};

const shouldLog = (level) =>
  LEVEL_ORDER[level] <=
  (LEVEL_ORDER[config.logLevel] ?? LEVEL_ORDER.info);

const writeLog = (level, message, metadata = {}) => {
  if (!shouldLog(level)) {
    return;
  }

  const payload = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...metadata,
  };

  const serialized = JSON.stringify(payload);
  if (level === "error") {
    console.error(serialized);
    return;
  }

  console.log(serialized);
};

const buildLogger = (baseMetadata = {}) => ({
  child(extraMetadata = {}) {
    return buildLogger({
      ...baseMetadata,
      ...extraMetadata,
    });
  },
  debug(message, metadata = {}) {
    writeLog("debug", message, {
      ...baseMetadata,
      ...metadata,
    });
  },
  info(message, metadata = {}) {
    writeLog("info", message, {
      ...baseMetadata,
      ...metadata,
    });
  },
  warn(message, metadata = {}) {
    writeLog("warn", message, {
      ...baseMetadata,
      ...metadata,
    });
  },
  error(message, metadata = {}) {
    writeLog("error", message, {
      ...baseMetadata,
      ...metadata,
    });
  },
});

module.exports = buildLogger();
