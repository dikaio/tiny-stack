FROM node:lts AS base
WORKDIR /app

# Install Litestream
ENV LITESTREAM_VERSION="0.3.13"
ARG TARGETARCH

RUN case "${TARGETARCH}" in \
    'amd64') \
      ARCH='amd64';; \
    'arm64') \
      ARCH='arm64';; \
    'arm') \
      ARCH='armv7';; \
    *) \
      echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    wget https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-v${LITESTREAM_VERSION}-linux-${ARCH}.deb \
    && dpkg -i litestream-v${LITESTREAM_VERSION}-linux-${ARCH}.deb \
    && rm litestream-v${LITESTREAM_VERSION}-linux-${ARCH}.deb

COPY package.json package-lock.json ./

FROM base AS prod-deps
RUN npm install --production

FROM base AS build-deps
RUN npm install --production=false

FROM build-deps AS build
COPY . .
RUN npm run build

FROM base AS runtime
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/knexfile.mjs knexfile.mjs
COPY --from=build /app/db db
COPY --from=build /app/scripts/run.sh run.sh
COPY --from=build /app/litestream.yml /etc/litestream.yml

RUN mkdir -p /data

ENV HOST=0.0.0.0
ENV PORT=4321
ENV NODE_ENV=production
EXPOSE 4321
CMD ["sh", "run.sh"]