-- Migration 0016_api_key_management_and_quotas
-- Phase 12: finishes what 0004/0008 started. api_keys and usage_events
-- already existed (Phase 4's metering groundwork), but nothing could
-- create/list/revoke a key, and nothing ever counted usage against
-- quota_daily or aggregated it for a portal chart — this migration adds
-- exactly those three things.

SET LOCAL search_path TO transit, public, extensions, auth;

-- Must run before any function below is created: CREATE FUNCTION ...
-- LANGUAGE sql validates the body against the catalog at creation time
-- (unlike plpgsql, which defers name resolution to first call), so
-- api_keys.label/revoked_at need to exist before create_api_key/
-- list_api_keys/revoke_api_key/api_key_lookup are defined.
ALTER TABLE api_keys ADD COLUMN IF NOT EXISTS label text;
ALTER TABLE api_keys ADD COLUMN IF NOT EXISTS revoked_at timestamptz;

CREATE OR REPLACE FUNCTION create_api_key(
    _agency_id uuid,
    _key_hash text,
    _scopes text[],
    _rate_limit_rpm integer,
    _quota_daily integer,
    _label text
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO api_keys (agency_id, key_hash, scopes, rate_limit_rpm, quota_daily, label)
    VALUES (_agency_id, _key_hash, _scopes, _rate_limit_rpm, _quota_daily, _label)
    RETURNING id;
$$;

-- Never returns key_hash — the raw key is shown to the caller exactly once
-- at creation time (standard API-key UX) and is unrecoverable after that;
-- key_hash existing at all is an internal lookup detail, not something any
-- read path should expose.
CREATE OR REPLACE FUNCTION list_api_keys(_agency_id uuid)
RETURNS TABLE (
    id uuid, label text, scopes text[], rate_limit_rpm integer, quota_daily integer,
    created_at timestamptz, revoked_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT id, label, scopes, rate_limit_rpm, quota_daily, created_at, revoked_at
    FROM api_keys
    WHERE agency_id = _agency_id
    ORDER BY created_at DESC;
$$;

CREATE OR REPLACE FUNCTION revoke_api_key(_agency_id uuid, _id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    UPDATE api_keys SET revoked_at = now(), updated_at = now()
    WHERE agency_id = _agency_id AND id = _id AND revoked_at IS NULL;
$$;

-- api_key_lookup (0008) predates revocation and quota_daily enforcement —
-- redefined to exclude revoked keys and add label for the response shown
-- to the caller (audit trail readability, not authorization).
DROP FUNCTION IF EXISTS api_key_lookup(text);

CREATE FUNCTION api_key_lookup(_key_hash text)
RETURNS TABLE (
    id uuid, agency_id uuid, scopes text[], rate_limit_rpm integer, quota_daily integer, label text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT id, agency_id, scopes, rate_limit_rpm, quota_daily, label
    FROM api_keys
    WHERE key_hash = _key_hash AND revoked_at IS NULL
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION usage_event_count_since(_api_key_id uuid, _since timestamptz)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT count(*)::integer FROM usage_events WHERE api_key_id = _api_key_id AND ts >= _since;
$$;

-- Daily usage rollup for the portal's usage chart (brief §12 / Phase 12
-- task 1: "portal charts against usage_events"). Aggregated across every
-- key in the agency, not per-key — a per-key breakdown is a reasonable
-- follow-up, not needed for a first chart.
CREATE OR REPLACE FUNCTION usage_summary_by_day(_agency_id uuid, _since date)
RETURNS TABLE (day date, requests integer, error_count integer, avg_latency_ms numeric)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT
        date_trunc('day', u.ts)::date AS day,
        count(*)::integer AS requests,
        count(*) FILTER (WHERE u.status >= 400)::integer AS error_count,
        avg(u.latency_ms)::numeric AS avg_latency_ms
    FROM usage_events u
    JOIN api_keys k ON k.id = u.api_key_id
    WHERE k.agency_id = _agency_id AND u.ts >= _since
    GROUP BY 1
    ORDER BY 1;
$$;

GRANT EXECUTE ON FUNCTION create_api_key TO transit_app;
GRANT EXECUTE ON FUNCTION list_api_keys TO transit_app;
GRANT EXECUTE ON FUNCTION revoke_api_key TO transit_app;
GRANT EXECUTE ON FUNCTION api_key_lookup TO transit_app;
GRANT EXECUTE ON FUNCTION usage_event_count_since TO transit_app;
GRANT EXECUTE ON FUNCTION usage_summary_by_day TO transit_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
