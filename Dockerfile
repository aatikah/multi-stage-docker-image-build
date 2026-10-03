# Alpine keeps the runtime image small and reduces the package footprint, but it uses musl
# instead of glibc and may require caution for binaries that assume glibc behavior.
FROM node:20.11.1-alpine3.20 AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts && npm cache clean --force

FROM node:20.11.1-alpine3.20 AS runtime

ENV NODE_ENV=production \
    PORT=3000 \
    NODE_OPTIONS="--max-old-space-size=256"

WORKDIR /app

RUN addgroup -S -g 1001 appuser && adduser -S -D -H -G appuser -u 1001 appuser

COPY --from=build --chown=appuser:appuser /app/node_modules ./node_modules
COPY --chown=appuser:appuser server.js ./

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get({ host: '127.0.0.1', port: process.env.PORT || 3000, path: '/health' }, (res) => { process.exit(res.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1));"

CMD ["node", "server.js"]
