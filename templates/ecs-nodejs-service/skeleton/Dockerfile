# Small, non-root, production image
FROM node:24-alpine

WORKDIR /app
ENV NODE_ENV=production PORT=8080

# Only what the app needs at runtime (no tests, no git history)
COPY package.json server.js ./

# The official node image ships a non-root "node" user; never run as root
USER node

EXPOSE 8080
CMD ["node", "server.js"]
