# ADR 0003 — Custom Access Token Hook for Agency/Role Claims

**Status:** accepted  
**Phase:** 2  
**Deciders:** Phase 2 implementation  
**Date:** 2026-08-25

## Context

Transit is multi-tenant by `agency_id` from day one. Every RLS policy and every Go API handler needs to know:

- which agency the request belongs to, and
- which roles the actor holds in that agency.

Supabase Auth stores users in `auth.users`. By default the JWT contains standard claims (`sub`, `email`, `role`, etc.) but nothing about our domain roles. If we put roles in `user_metadata`, users can edit their own role and escalate privileges. That is unacceptable for a government-facing product.

## Decision

Use a **Supabase Auth custom access token hook** (`auth.custom_access_token_hook` style, implemented as `transit.custom_access_token_hook`) to look up `transit.user_roles` at login/refresh time and inject server-owned claims into the JWT:

- `agency_id` — active agency for this session
- `roles` — array of roles held in that agency
- `depot_id` — depot scope, when the user is a dispatcher or driver
- `app_metadata.transit` — mirror of the same data, for client-side convenience

The hook also writes the same data into `auth.users.raw_app_meta_data` so the user object returned by Supabase Auth stays consistent with the JWT.

GoTrue is configured with:

```text
GOTRUE_HOOK_CUSTOM_ACCESS_TOKEN_ENABLED=true
GOTRUE_HOOK_CUSTOM_ACCESS_TOKEN_URI=pg-functions://postgres/transit/custom_access_token_hook
```

The hook function is `SECURITY DEFINER` and owned by the migration role, so it can read `transit.user_roles` and `auth.users` while being executable by `supabase_auth_admin`.

## Consequences

### Positive

- Authorisation claims are server-owned; users cannot escalate by editing `user_metadata`.
- RLS policies can use the top-level JWT claims directly (`current_agency_id()`, `current_user_role()`).
- Go middleware can trust the same signed claims after JWKS/HMAC verification.
- Active agency is resolved once per token issue, avoiding per-request lookups.

### Negative / Risks

- Token refresh is required for role changes to take effect. This is acceptable because roles change infrequently and the default access-token lifetime is short (1 hour).
- A bug in the hook can prevent login. Mitigation: the function wraps all work in `EXCEPTION WHEN OTHERS` and returns the original event unchanged, so login still succeeds but RLS denies access until the bug is fixed.
- The hook adds a small DB query on every token issue/refresh. Indexes on `user_roles(user_id, agency_id, role)` and `driver_profiles(user_id, agency_id)` keep it fast.

## Alternatives considered

1. **Read roles per request.** Rejected: adds a DB round-trip to every API call and every RLS check.
2. **Store roles in `user_metadata`.** Rejected: users can write their own `user_metadata`; this is a privilege-escalation hole.
3. **Store roles in `raw_app_meta_data` only and let GoTrue include it.** Rejected: `raw_app_meta_data` is safer than `user_metadata`, but changes still require updating the user object. The hook centralises the lookup and keeps the source of truth in `transit.user_roles`.

## References

- `docs/BUILD_PROMPT.md` §3.1 — role model and the “never read user_metadata for authorisation” rule.
- `infra/supabase/migrations/0004_roles_and_audit.sql` — `user_roles`, `driver_profiles`, RLS helpers.
- `infra/supabase/migrations/0005_custom_access_token_hook.sql` — hook implementation.
- `deploy/compose/compose.yaml` — GoTrue hook environment variables.
