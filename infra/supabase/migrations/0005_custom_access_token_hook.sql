-- Migration 0005_custom_access_token_hook
-- Installs the Supabase Auth custom access token hook that injects server-owned
-- agency, role and depot claims into every JWT. The hook is owned by the
-- database superuser and executed with SECURITY DEFINER so it can read
-- transit.user_roles / transit.driver_profiles while being callable by
-- supabase_auth_admin.
--
-- Why this exists: roles must live in server-owned tables (§3.1). Never read
-- user_metadata for authorisation, because users can edit it themselves.
--
-- The matching GoTrue environment variables are added in deploy/compose/compose.yaml:
--   GOTRUE_HOOK_CUSTOM_ACCESS_TOKEN_ENABLED=true
--   GOTRUE_HOOK_CUSTOM_ACCESS_TOKEN_URI=pg-functions://postgres/transit/custom_access_token_hook

SET LOCAL search_path TO transit, auth, public;

-- ---------------------------------------------------------------------------
-- Hook function. Called by GoTrue before every access token is issued.
--   event jsonb -> { "claims": { ... } }
-- Returns the modified event with enriched claims.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION transit.custom_access_token_hook(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'transit', 'auth', 'public'
AS $$
DECLARE
    claims jsonb;
    user_id uuid;
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

    user_id := (claims->>'sub')::uuid;
    IF user_id IS NULL THEN
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
    WHERE u.id = user_id;

    IF active_agency IS NULL THEN
        -- No roles assigned yet; issue a token without transit claims.
        RETURN event;
    END IF;

    -- All roles the user holds in the active agency, and pick the highest-
    -- priority one as the top-level "role" claim expected by Phase 1 RLS helpers.
    SELECT array_agg(ur.role ORDER BY ur.role)
    INTO roles
    FROM user_roles ur
    WHERE ur.user_id = user_id AND ur.agency_id = active_agency;

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
        WHERE ur.user_id = user_id
          AND ur.agency_id = active_agency
          AND ur.role = 'dispatcher'
          AND ur.depot_id IS NOT NULL
        LIMIT 1;
    END IF;
    IF depot_id IS NULL AND 'driver' = ANY(roles) THEN
        SELECT dp.depot_id INTO depot_id
        FROM driver_profiles dp
        WHERE dp.user_id = user_id AND dp.agency_id = active_agency;
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
    WHERE id = user_id;

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
    RAISE WARNING 'custom_access_token_hook error for user %: %', user_id, SQLERRM;
    RETURN event;
END;
$$;

-- Grant GoTrue's database role the right to invoke the hook. The function body
-- runs as the owner (SECURITY DEFINER), so this grant is only for call access.
GRANT USAGE ON SCHEMA transit TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION transit.custom_access_token_hook TO supabase_auth_admin;
