const path = require("path");
const express = require("express");
const compression = require("compression");
const cors = require("cors");
const helmet = require("helmet");
const cookieParser = require("cookie-parser");

const { config } = require("./src/config/env");
const { getDatabaseHealth } = require("./src/config/db");
const { getRedisHealth } = require("./src/config/redis");
const AppError = require("./src/utils/AppError");
const requestContext = require("./src/middleware/requestContext");
const requestLogger = require("./src/middleware/requestLogger");
const { apiLimiter } = require("./src/middleware/rateLimiters");
const authRoutes = require("./src/routes/authRoutes");
const profileRoutes = require("./src/routes/profileRoutes");
const scriptureRoutes = require("./src/routes/scriptureRoutes");
const verseRoutes = require("./src/routes/verseRoutes");
const historyRoutes = require("./src/routes/historyRoutes");
const songRoutes = require("./src/routes/songRoutes");
const audioRoutes = require("./src/routes/audioRoutes");
const v1Routes = require("./src/routes/v1Routes");
const { notFound, errorHandler } = require("./src/middleware/errorHandler");

const app = express();

const corsOrigin = (origin, callback) => {
  if (!origin) {
    return callback(null, true);
  }

  if (config.allowAnyCorsOrigin && !config.isProduction) {
    return callback(null, true);
  }

  if (config.corsOrigins.includes(origin)) {
    return callback(null, true);
  }

  return callback(new AppError(403, "CORS origin denied"));
};

if (config.trustProxy) {
  app.set("trust proxy", 1);
}

app.use(
  helmet({
    // Default img-src ('self' + data:) would silently block every YouTube
    // song/hymn thumbnail now that the frontend's HTML is served from here
    // too and inherits this CSP - those come straight from YouTube's
    // thumbnail CDN, not our own origin. Same problem for media-src (no
    // explicit default, falls back to 'self') and the Bible chapter audio
    // narration, which streams straight from YouVersion's CDN.
    contentSecurityPolicy: {
      directives: {
        ...helmet.contentSecurityPolicy.getDefaultDirectives(),
        "img-src": ["'self'", "data:", "https://i.ytimg.com", "https://*.ggpht.com", "https://*.googleusercontent.com"],
        "media-src": ["'self'", "https://*.youversionapi.com"],
      },
    },
  })
);
app.use(
  cors({
    origin: corsOrigin,
    credentials: true,
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "X-Request-Id"],
    exposedHeaders: ["X-Request-Id"],
  })
);
app.use(compression());
app.use(cookieParser());
app.use(requestContext);
app.use(requestLogger);
app.use(express.json({ limit: "1mb" }));
app.use(express.urlencoded({ extended: false, limit: "1mb" }));
app.use(apiLimiter);

app.get("/health", (_req, res) => {
  const database = getDatabaseHealth();
  const redis = getRedisHealth();
  res.status(200).json({
    success: database.ready,
    status: database.ready ? "ok" : "degraded",
    environment: config.env,
    services: {
      database,
      redis,
    },
    uptimeSeconds: Math.round(process.uptime()),
  });
});

app.get("/ready", (_req, res) => {
  const database = getDatabaseHealth();
  const redis = getRedisHealth();
  const ready = database.ready;
  res.status(ready ? 200 : 503).json({
    success: ready,
    status: ready ? "ready" : "not_ready",
    services: {
      database,
      redis,
    },
  });
});

app.use("/api/auth", authRoutes);
app.use(profileRoutes);
app.use("/api/scripture", scriptureRoutes);
app.use("/api/verses", verseRoutes);
app.use("/api/history", historyRoutes);
app.use("/api/songs", songRoutes);
app.use("/api/audio", audioRoutes);
app.use("/api/v1", v1Routes);

// Serves the built bible-ui SPA (copied into public/ during the Docker
// build - see root Dockerfile) so the Flutter app's WebView, and any
// browser, can load the whole app from this one deployed origin,
// same-origin with /api, instead of needing a separate frontend host or a
// dev-machine tunnel. Static files first so real assets (JS/CSS/images)
// are served directly; anything else non-API falls through to index.html
// for React Router's client-side routing.
const staticDir = path.join(__dirname, "public");
app.use(express.static(staticDir));
app.get(/^\/(?!api\/).*/, (_req, res) => {
  res.sendFile(path.join(staticDir, "index.html"));
});

app.use(notFound);
app.use(errorHandler);

module.exports = app;
