FROM node:22-alpine AS build
WORKDIR /app
RUN apk add --no-cache python3 make g++
COPY package.json ./
RUN npm install
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
RUN apk add --no-cache libstdc++ python3 make g++
COPY package.json ./
RUN npm install --omit=dev && apk del python3 make g++ && npm cache clean --force
COPY --from=build /app/dist ./dist
COPY db ./db
CMD ["node", "dist/server.js"]