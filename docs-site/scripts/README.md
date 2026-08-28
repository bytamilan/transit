# Portal screenshot capture

`portal_shots.spec.ts` drives a real login through the portal's browser-side
Supabase client and captures the admin screenshots used by
`docs-site/docs/`. It needs a running stack plus two pieces of local-only
scaffolding that aren't started automatically. None of the steps below touch
the shared repo, the shared Docker stack, or CI — everything is ephemeral
and killed at the end.

## Prerequisites

1. `make dev-full` running, migrated (`make db.migrate`) and seeded
   (`make db.seed`).
2. `docs-site/scripts/create_demo_admin.sh` run once against that stack —
   creates the `demo-admin@transit.local` user and grants it an
   `agency_admin` role via `transit.user_roles`.
3. Start the local auth/rest proxy. `deploy/compose/compose.yaml` has no
   Kong/gateway unifying GoTrue and PostgREST, but `@supabase/supabase-js`
   hardcodes `/auth/v1` and `/rest/v1` path prefixes and expects both behind
   one origin — `local_supabase_proxy.mjs` rewrites those prefixes onto the
   separate GoTrue (`:9999`) and PostgREST (`:3000`) ports and adds the CORS
   headers neither of them sends for the portal's dev-server origin:
   ```
   node docs-site/scripts/local_supabase_proxy.mjs &
   ```
   Defaults to listening on `:54321`; override with `PROXY_PORT`,
   `AUTH_TARGET`, `REST_TARGET` env vars if your stack uses different ports.
4. Create `apps/portal/.env.local` (gitignored — never commit it) pointing
   the portal at the proxy, not directly at GoTrue or PostgREST:
   ```
   NEXT_PUBLIC_SUPABASE_URL=http://localhost:54321
   NEXT_PUBLIC_SUPABASE_ANON_KEY=<an anon-role JWT signed with the same JWT_SECRET as .env>
   NEXT_PUBLIC_API_BASE_URL=http://localhost:8080
   ```
   Mint the anon key with the same HS256/`JWT_SECRET` technique
   `mint_service_role_jwt.py` uses for the service-role key, but with
   `"role": "anon"` in the payload instead of `"role": "service_role"`.
   `NEXT_PUBLIC_API_BASE_URL` is unrelated to Supabase — it's the Go API's
   published port (`transit-api-1`), read directly by
   `apps/portal/src/lib/api.ts` for pages like `/datasets` that call the API
   instead of PostgREST.
5. Start the portal dev server on an alternate port — PostgREST already
   uses `:3000` in this compose stack, so the portal can't also bind it:
   ```
   pnpm -C apps/portal dev -p 3002 &
   ```
   Use `-p 3002` directly, not `dev -- -p 3002` — pnpm appends that after the
   script's own `--`, so Next.js sees `-- -p 3002` and misparses `-p 3002` as
   a project-directory argument.
6. Capture the screenshots:
   ```
   PORTAL_URL=http://localhost:3002 pnpm -C docs-site/scripts run shots
   ```
   Output lands in `docs-site/scripts/.portal-shots/*.png` (committed —
   these are the images `docs-site/docs/` embeds).
7. Kill the proxy and portal dev server background processes when done, and
   confirm `docker ps` is unchanged — no container should have been added,
   removed, or reconfigured by any of the above.

## Troubleshooting

- **Admin pages show "Access restricted" instead of real dashboard
  content:** this means the signed-in user has no roles in
  `app_metadata.transit.roles`, which the GoTrue custom access token hook
  (`transit.custom_access_token_hook`,
  `infra/supabase/migrations/0017_fix_custom_access_token_hook_user_id_ambiguity.sql`)
  is supposed to populate from `transit.user_roles` on every token issuance.
  Confirm step 2 above actually ran, and that the hook migration is applied
  (`transit.schema_migrations`).
- **CORS / "Failed to fetch" on login:** confirm the proxy (step 3) is
  actually running and `NEXT_PUBLIC_SUPABASE_URL` points at it, not directly
  at GoTrue's `:9999`.
