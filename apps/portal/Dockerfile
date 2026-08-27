# Phase 12: multi-stage build producing a minimal standalone Next.js
# server image, for the Helm chart's portal deployment. Built from the
# monorepo root (`docker build -f apps/portal/Dockerfile .`) since it's a
# pnpm workspace member, not a standalone package.
FROM node:20-slim AS build
WORKDIR /repo
RUN corepack enable

COPY pnpm-workspace.yaml package.json* ./
COPY apps/portal/package.json apps/portal/package.json
RUN pnpm install --frozen-lockfile --filter portal... || pnpm install --filter portal...

COPY apps/portal apps/portal
WORKDIR /repo/apps/portal
RUN pnpm build

FROM node:20-slim AS run
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

COPY --from=build /repo/apps/portal/.next/standalone ./
COPY --from=build /repo/apps/portal/.next/static ./apps/portal/.next/static
COPY --from=build /repo/apps/portal/public ./apps/portal/public

USER node
EXPOSE 3000
CMD ["node", "apps/portal/server.js"]
