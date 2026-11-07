FROM node:20-slim

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install

COPY . .

EXPOSE 8010

CMD ["sh", "-c", "npm run db:migrate && npm start"]
