FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN YOUTUBE_DL_SKIP_PYTHON_CHECK=1 npm ci --omit=dev

COPY . .

EXPOSE 5000

CMD ["node", "server.js"]
