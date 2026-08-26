-- Migration 0002_tenancy
-- Tenant root, agency configuration, and RLS claim helpers.
--
-- The JSON Schema for agency.config lives at:
--   infra/supabase/schemas/agency_config.json
-- The PL/pgSQL validation below mirrors that schema so that the database can
-- enforce the contract without reading files at runtime.

SET LOCAL search_path TO transit, public, extensions, auth;

-- ---------------------------------------------------------------------------
-- Helper: extract the agency_id JWT claim set by PostgREST / Go middleware.
-- This MUST be the only source of tenancy in RLS policies.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION current_agency_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    claims jsonb;
    raw text;
BEGIN
    raw := current_setting('request.jwt.claims', true);
    IF raw IS NULL OR raw = '' THEN
        RETURN NULL;
    END IF;
    claims := raw::jsonb;
    IF claims IS NULL OR claims->>'agency_id' IS NULL OR claims->>'agency_id' = '' THEN
        RETURN NULL;
    END IF;
    RETURN (claims->>'agency_id')::uuid;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- Helper: extract the role claim from the JWT. We read the top-level claim
-- injected by the Supabase custom access token hook. We never read
-- user_metadata for authorisation.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION current_user_role()
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    claims jsonb;
    raw text;
BEGIN
    raw := current_setting('request.jwt.claims', true);
    IF raw IS NULL OR raw = '' THEN
        RETURN NULL;
    END IF;
    claims := raw::jsonb;
    RETURN claims->>'role';
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- Helper: true when the request is unauthenticated or has no JWT claims.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION auth_is_anon()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    RETURN current_setting('request.jwt.claims', true) IS NULL
        OR current_setting('request.jwt.claims', true) = '';
END;
$$;

-- ---------------------------------------------------------------------------
-- Agency configuration validation.
-- Kept in one function so the rules are explicit and reviewable.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_agency_config()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    _name jsonb;
    _key text;
    _allowed_distance_units text[] := ARRAY['metric', 'imperial'];
    _allowed_map_providers text[] := ARRAY['google', 'maplibre', 'protomaps'];
    _allowed_modes text[] := ARRAY[
        'bus', 'rail', 'ferry', 'tram', 'paratransit',
        'metro', 'subway', 'trolleybus', 'cable_car', 'gondola', 'funicular', 'taxi'
    ];
    _mode text;
    _ops jsonb;
BEGIN
    IF NEW.config IS NULL OR NEW.config = '{}'::jsonb THEN
        RAISE EXCEPTION 'agency.config is required';
    END IF;

    -- name: non-empty object of locale -> string
    _name := NEW.config->'name';
    IF _name IS NULL OR jsonb_typeof(_name) <> 'object' OR _name = '{}'::jsonb THEN
        RAISE EXCEPTION 'agency.config.name must be a non-empty object of locale strings';
    END IF;
    FOR _key IN SELECT jsonb_object_keys(_name) LOOP
        IF jsonb_typeof(_name->_key) <> 'string' THEN
            RAISE EXCEPTION 'agency.config.name.% must be a string', _key;
        END IF;
    END LOOP;

    -- timezone
    IF NEW.config->>'timezone' IS NULL OR NEW.config->>'timezone' = '' THEN
        RAISE EXCEPTION 'agency.config.timezone is required';
    END IF;

    -- locales
    IF jsonb_typeof(NEW.config->'locales') <> 'array' OR jsonb_array_length(NEW.config->'locales') = 0 THEN
        RAISE EXCEPTION 'agency.config.locales must be a non-empty array';
    END IF;

    -- currency
    IF NEW.config->>'currency' IS NULL OR length(NEW.config->>'currency') <> 3 THEN
        RAISE EXCEPTION 'agency.config.currency must be a 3-letter ISO 4217 code';
    END IF;

    -- distance_unit
    IF NEW.config->>'distance_unit' IS NULL OR NOT (NEW.config->>'distance_unit' = ANY (_allowed_distance_units)) THEN
        RAISE EXCEPTION 'agency.config.distance_unit must be one of %', _allowed_distance_units;
    END IF;

    -- modes
    IF jsonb_typeof(NEW.config->'modes') <> 'array' OR jsonb_array_length(NEW.config->'modes') = 0 THEN
        RAISE EXCEPTION 'agency.config.modes must be a non-empty array';
    END IF;
    FOR _mode IN SELECT jsonb_array_elements_text(NEW.config->'modes') LOOP
        IF NOT (_mode = ANY (_allowed_modes)) THEN
            RAISE EXCEPTION 'agency.config.modes contains invalid mode %', _mode;
        END IF;
    END LOOP;

    -- map_provider
    IF NEW.config->>'map_provider' IS NULL OR NOT (NEW.config->>'map_provider' = ANY (_allowed_map_providers)) THEN
        RAISE EXCEPTION 'agency.config.map_provider must be one of %', _allowed_map_providers;
    END IF;

    -- license
    IF NEW.config->'license' IS NULL OR jsonb_typeof(NEW.config->'license') <> 'object' THEN
        RAISE EXCEPTION 'agency.config.license must be an object';
    END IF;
    IF NEW.config->'license'->>'spdx' IS NULL OR NEW.config->'license'->>'spdx' = '' THEN
        RAISE EXCEPTION 'agency.config.license.spdx is required';
    END IF;
    IF NEW.config->'license'->>'attribution' IS NULL OR NEW.config->'license'->>'attribution' = '' THEN
        RAISE EXCEPTION 'agency.config.license.attribution is required';
    END IF;

    -- branding
    IF NEW.config->'branding' IS NULL OR jsonb_typeof(NEW.config->'branding') <> 'object' THEN
        RAISE EXCEPTION 'agency.config.branding must be an object';
    END IF;
    IF NEW.config->'branding'->>'primary' IS NULL OR NEW.config->'branding'->>'primary' = '' THEN
        RAISE EXCEPTION 'agency.config.branding.primary is required';
    END IF;

    -- driver_ops
    _ops := NEW.config->'driver_ops';
    IF _ops IS NULL OR jsonb_typeof(_ops) <> 'object' THEN
        RAISE EXCEPTION 'agency.config.driver_ops must be an object';
    END IF;
    IF jsonb_typeof(_ops->'stop_geofence_m') <> 'number' THEN
        RAISE EXCEPTION 'agency.config.driver_ops.stop_geofence_m must be a number';
    END IF;
    IF jsonb_typeof(_ops->'ping_interval_moving_s') <> 'number' THEN
        RAISE EXCEPTION 'agency.config.driver_ops.ping_interval_moving_s must be a number';
    END IF;
    IF jsonb_typeof(_ops->'ping_interval_idle_s') <> 'number' THEN
        RAISE EXCEPTION 'agency.config.driver_ops.ping_interval_idle_s must be a number';
    END IF;
    IF jsonb_typeof(_ops->'auto_start_trip') <> 'boolean' THEN
        RAISE EXCEPTION 'agency.config.driver_ops.auto_start_trip must be a boolean';
    END IF;
    IF jsonb_typeof(_ops->'lock_ui_above_kmh') <> 'number' THEN
        RAISE EXCEPTION 'agency.config.driver_ops.lock_ui_above_kmh must be a number';
    END IF;

    RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- Agencies table: the tenant root. Every other table carries agency_id.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agencies (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    slug text UNIQUE NOT NULL,
    name jsonb NOT NULL,
    timezone text NOT NULL,
    config jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_agencies_config_validate
    BEFORE INSERT OR UPDATE ON agencies
    FOR EACH ROW
    EXECUTE FUNCTION validate_agency_config();

CREATE INDEX IF NOT EXISTS idx_agencies_slug ON agencies(slug);

-- ---------------------------------------------------------------------------
-- Row Level Security on the tenant root.
--
-- Read policy: a request with an agency_id claim sees only that agency.
--              super_admin sees all agencies.
-- Write policy: agency_admin for the matching agency, or super_admin.
-- ---------------------------------------------------------------------------
ALTER TABLE agencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE agencies FORCE ROW LEVEL SECURITY;

CREATE POLICY agencies_select_own
    ON agencies
    FOR SELECT
    USING (
        current_user_role() = 'super_admin'
        OR current_agency_id() = id
    );

CREATE POLICY agencies_update_own
    ON agencies
    FOR UPDATE
    USING (
        current_user_role() = 'super_admin'
        OR (current_user_role() = 'agency_admin' AND current_agency_id() = id)
    )
    WITH CHECK (
        current_user_role() = 'super_admin'
        OR (current_user_role() = 'agency_admin' AND current_agency_id() = id)
    );

CREATE POLICY agencies_insert_super
    ON agencies
    FOR INSERT
    WITH CHECK (current_user_role() = 'super_admin');

CREATE POLICY agencies_delete_super
    ON agencies
    FOR DELETE
    USING (current_user_role() = 'super_admin');
