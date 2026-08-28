-- Migration 0017_fix_custom_access_token_hook_user_id_ambiguity
--
-- Fixes a bug in transit.custom_access_token_hook (0005): the PL/pgSQL
-- variable `user_id` had the same name as the `user_id` column on
-- transit.user_roles and transit.driver_profiles. Under Postgres's default
-- `#variable_conflict error`, any bare (unqualified) reference to `user_id`
-- inside a query against those tables is ambiguous and raises an error at
-- runtime — caught by the hook's own `EXCEPTION WHEN OTHERS` handler, which
-- silently returns the token unchanged (by design, so a broken hook never
-- blocks login) rather than surfacing the error. Net effect: every access
-- token was missing its agency/role/depot claims, for every user, since the
-- three affected queries (the roles array_agg, the dispatcher depot lookup,
-- and the driver depot lookup) always failed.
--
-- Fix: rename the local variable to hook_user_id (no bare `user_id`
-- anywhere in the function body afterwards), rather than qualifying each
-- call site — a renamed variable can't collide with any column in any
-- future query added to this function.
--
-- CREATE OR REPLACE fully replaces the function body; no data migration
-- needed, this only changes behavior on the next token issue/refresh.

SET LOCAL search_path TO transit, auth, public;

CREATE OR REPLACE FUNCTION transit.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'transit', 'auth', 'public'
AS $$
DECLARE
    claims jsonb;
    hook_user_id uuid;
    active_agency uuid;
    roles text[];
    depot_id uuid;
    app_meta jsonb;
    transit_meta jsonb;
BEGIN
    claims := event->'claims';
    IF claims IS NULL THEN
        RETURN event;
    END IF;

    hook_user_id := (claims->>'sub')::uuid;
    IF hook_user_id IS NULL THEN
        RETURN event;
    END IF;

    -- Service-role and anonymous tokens do not need tenant claims.
    IF claims->>'role' IN ('service_role', 'anon') THEN
        RETURN event;
    END IF;

    -- Active agency: explicit user preference wins, otherwise the first agency
    -- for which the user has a role.
    SELECT COALESCE(
        (u.raw_app_meta_data->>'active_agency_id')::uuid,
        (SELECT ur.agency_id
         FROM user_roles ur
         WHERE ur.user_id = u.id
         ORDER BY ur.created_at
         LIMIT 1)
    )
    INTO active_agency
    FROM auth.users u
    WHERE u.id = hook_user_id;

    IF active_agency IS NULL THEN
        -- No roles assigned yet; issue a token without transit claims.
        RETURN event;
    END IF;

    -- All roles the user holds in the active agency, and pick the highest-
    -- priority one as the top-level "role" claim expected by Phase 1 RLS helpers.
    SELECT array_agg(ur.role ORDER BY ur.role)
    INTO roles
    FROM user_roles ur
    WHERE ur.user_id = hook_user_id AND ur.agency_id = active_agency;

    claims := jsonb_set(claims, '{role}', to_jsonb(
        CASE
            WHEN 'super_admin' = ANY(roles) THEN 'super_admin'
            WHEN 'agency_admin' = ANY(roles) THEN 'agency_admin'
            WHEN 'fleet_manager' = ANY(roles) THEN 'fleet_manager'
            WHEN 'dispatcher' = ANY(roles) THEN 'dispatcher'
            WHEN 'driver' = ANY(roles) THEN 'driver'
            WHEN 'data_consumer' = ANY(roles) THEN 'data_consumer'
            WHEN 'rider' = ANY(roles) THEN 'rider'
            ELSE 'anon'
        END
    ));

    -- Depot scope: a dispatcher may be scoped to one depot. Drivers carry
    -- depot from their profile. Otherwise the claim is omitted.
    IF 'dispatcher' = ANY(roles) THEN
        SELECT ur.depot_id INTO depot_id
        FROM user_roles ur
        WHERE ur.user_id = hook_user_id
          AND ur.agency_id = active_agency
          AND ur.role = 'dispatcher'
          AND ur.depot_id IS NOT NULL
        LIMIT 1;
    END IF;
    IF depot_id IS NULL AND 'driver' = ANY(roles) THEN
        SELECT dp.depot_id INTO depot_id
        FROM driver_profiles dp
        WHERE dp.user_id = hook_user_id AND dp.agency_id = active_agency;
    END IF;

    -- Mirror the resolved claims into raw_app_meta_data so the user object
    -- returned by Supabase Auth stays consistent with the JWT. This is also
    -- written to the JWT app_metadata claim below.
    transit_meta := jsonb_build_object(
        'agency_id', active_agency,
        'roles', to_jsonb(COALESCE(roles, ARRAY[]::text[])),
        'depot_id', depot_id
    );
    UPDATE auth.users
    SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb)
                       || jsonb_build_object('transit', transit_meta)
    WHERE id = hook_user_id;

    -- Inject top-level custom claims used by RLS helpers and Go middleware.
    claims := jsonb_set(claims, '{agency_id}', to_jsonb(active_agency));
    claims := jsonb_set(claims, '{roles}', to_jsonb(COALESCE(roles, ARRAY[]::text[])));
    IF depot_id IS NOT NULL THEN
        claims := jsonb_set(claims, '{depot_id}', to_jsonb(depot_id));
    END IF;

    -- Defence in depth: also place the same data inside the standard
    -- app_metadata claim so the client can read it, but the server never
    -- authorises from app_metadata without re-verifying the JWT signature.
    app_meta := COALESCE(claims->'app_metadata', '{}'::jsonb)
             || jsonb_build_object('transit', transit_meta);
    claims := jsonb_set(claims, '{app_metadata}', app_meta);

    RETURN jsonb_set(event, '{claims}', claims);

EXCEPTION WHEN OTHERS THEN
    -- A failing hook must never prevent login. Return the token unchanged;
    -- downstream RLS will deny access until the hook is fixed.
    RAISE WARNING 'custom_access_token_hook error for user %: %', hook_user_id, SQLERRM;
    RETURN event;
END;
$$;

GRANT USAGE ON SCHEMA transit TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION transit.custom_access_token_hook TO supabase_auth_admin;
