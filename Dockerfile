# The Flutter app's WebView just loads a URL - previously localhost:3000,
# which only worked tethered to a dev machine via `adb reverse`. Building
# bible-ui here and serving it from this same backend means the phone (or
# any browser) can load the whole app from one deployed origin, same-origin
# with /api, with nothing else running.
FROM node:20 AS frontend-build

WORKDIR /frontend

COPY bible-ui/package*.json ./

RUN npm install --legacy-peer-deps

COPY bible-ui/ .

RUN npm run build

FROM node:20

WORKDIR /app

COPY bible-backend/package*.json ./

RUN npm install

COPY bible-backend/ .

# bookMetadata.js resolves book titles/chapter counts from this Dart file
# (shared with the Flutter app) via a path three levels above its own
# location — which lands at the container's filesystem root, not /app.
# Without this, every Bible book/chapter list 500s with ENOENT even though
# the actual verse content in MongoDB is untouched.
COPY lib/config /lib/config

COPY --from=frontend-build /frontend/dist ./public

EXPOSE 5000

CMD ["npm", "start"]
