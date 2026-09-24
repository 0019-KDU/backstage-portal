# ---- build: compile TypeScript, then keep only production dependencies ----
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev
# Amazon RDS certificate bundle: the app verifies the database's TLS certificate
RUN wget -q -O rds-global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# ---- runtime: small, non-root, no compilers or dev tools ----
FROM node:24-alpine
ENV NODE_ENV=production PORT=8080
WORKDIR /app
COPY --from=build --chown=node:node /app/package.json ./
COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --from=build --chown=node:node /app/rds-global-bundle.pem ./certs/rds-global-bundle.pem
USER node
EXPOSE 8080
CMD ["node", "dist/main.js"]
