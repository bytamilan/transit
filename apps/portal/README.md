# Portal (Next.js App Router + Tailwind) — Phases 4/6/9

Public data portal (`/datasets`, `/request`, `/docs`, `/dashboard` — later
phases) plus the agency back office (`/admin`: fleet, routes, drivers, duty
assignment; live dispatch board arrives in Phase 9). See
`docs/BUILD_PROMPT.md` §1C and §3.2.

## Phase 6 — admin console

- Auth: `@supabase/ssr`, same Supabase Auth project the Go API verifies JWTs
  against. `middleware.ts` refreshes the session and gates `/admin/*`;
  `src/app/admin/layout.tsx` additionally checks for a
  `fleet_manager`/`dispatcher`/`agency_admin`/`super_admin` role read from
  `user.app_metadata.transit.roles` (mirrored by the custom access token hook
  per ADR 0003) before rendering the nav.
- Data: every page calls the Go API (`services/api`) directly with the
  signed-in user's access token as a bearer credential — the portal never
  talks to Postgres. See `src/lib/api.ts`.
- Pages: `/admin/vehicles`, `/admin/drivers` (CRUD + CSV bulk import),
  `/admin/routes` + `/admin/routes/[routeId]` (routes, service calendars,
  trip stop-sequence editor), `/admin/roster` (assign blocks to a
  driver+vehicle for a date, see conflicts, and apply a recurring weekly
  roster across a date range).
- The client-side role checks in `src/lib/rbac.ts` are a UI convenience
  only — the Go API's table-driven RBAC (`internal/httpapi/rbac`) is what
  actually authorises every request.

## Local development

```sh
cp .env.example .env.local   # fill in NEXT_PUBLIC_SUPABASE_ANON_KEY
make portal.install
make portal.dev              # http://localhost:3000
```

`make portal.build` type-checks and production-builds the app (also run in
CI via `make lint`/`make test` equivalents for the portal).
