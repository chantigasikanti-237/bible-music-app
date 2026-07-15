FROM node:20

WORKDIR /app

COPY bible-backend/package*.json ./

RUN npm install

COPY bible-backend/ .

EXPOSE 5000

CMD ["npm", "start"]
