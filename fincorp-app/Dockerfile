# ---- Build stage ----
FROM node:20-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY src ./src

# ---- Runtime stage ----
FROM node:20-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
RUN groupadd -r fincorp && useradd -r -g fincorp -d /app fincorp \
    && chown -R fincorp:fincorp /app
COPY --from=build --chown=fincorp:fincorp /app/node_modules ./node_modules
COPY --from=build --chown=fincorp:fincorp /app/package*.json ./
COPY --from=build --chown=fincorp:fincorp /app/src ./src
USER fincorp
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"
CMD ["node", "src/server.js"]
