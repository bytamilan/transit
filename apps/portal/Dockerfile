# Phase 12: multi-stage build producing a minimal standalone Next.js
# server image, for the Helm chart's portal deployment. Built from the
# monorepo root (`docker build -f apps/portal/Dockerfile .`) since it's a
# pnpm workspace member, not a standalone package.
FROM node:22-slim AS build
WORKDIR /repo
RUN corepack enable

COPY pnpm-workspace.yaml pnpm-lock.yaml package.json* ./
COPY apps/portal/package.json apps/portal/package.json
RUN pnpm install --frozen-lockfile --filter ./apps/portal...

COPY apps/portal apps/portal
WORKDIR /repo/apps/portal

# NEXT_PUBLIC_* values are embedded into the browser bundle at build time.
# Compose supplies local overrides through build.args.
ARG NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
ARG NEXT_PUBLIC_EXPORTER_BASE_URL=http://localhost:8090
ARG NEXT_PUBLIC_SUPABASE_URL=http://localhost:8080/auth
ARG NEXT_PUBLIC_SUPABASE_ANON_KEY=
ARG NEXT_PUBLIC_MAP_STYLE_URL=https://demotiles.maplibre.org/style.json
ENV NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL}
ENV NEXT_PUBLIC_EXPORTER_BASE_URL=${NEXT_PUBLIC_EXPORTER_BASE_URL}
ENV NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL}
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY}
ENV NEXT_PUBLIC_MAP_STYLE_URL=${NEXT_PUBLIC_MAP_STYLE_URL}
RUN mkdir -p public
RUN pnpm build

FROM node:22-slim AS run
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3000

COPY --from=build /repo/apps/portal/.next/standalone ./
COPY --from=build /repo/apps/portal/.next/static ./apps/portal/.next/static
COPY --from=build /repo/apps/portal/public ./apps/portal/public

USER node
EXPOSE 3000
CMD ["node", "apps/portal/server.js"]
