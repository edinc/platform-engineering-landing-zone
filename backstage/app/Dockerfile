FROM node:24-trixie-slim

ENV NODE_ENV=production
ENV NODE_OPTIONS=--no-node-snapshot
ENV PYTHON=/usr/bin/python3

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends python3 g++ build-essential libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

USER node
WORKDIR /app

COPY --chown=node:node . .

RUN node .yarn/releases/yarn-4.4.1.cjs install --immutable && \
    node .yarn/releases/yarn-4.4.1.cjs tsc && \
    node .yarn/releases/yarn-4.4.1.cjs build:backend

RUN tar xzf packages/backend/dist/skeleton.tar.gz && \
    node .yarn/releases/yarn-4.4.1.cjs workspaces focus --all --production && \
    node .yarn/releases/yarn-4.4.1.cjs cache clean && \
    tar xzf packages/backend/dist/bundle.tar.gz

EXPOSE 7007
CMD ["node", "scripts/start-backstage.mjs", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
