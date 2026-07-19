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

EXPOSE 5000

CMD ["npm", "start"]
