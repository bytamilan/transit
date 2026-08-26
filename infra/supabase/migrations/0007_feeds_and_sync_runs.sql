-- Migration 0007_feeds_and_sync_runs
-- Adds feed configuration, sync-run audit rows, and a quarantine table for
-- malformed feeds. These tables drive the Phase 3 adapter architecture.

SET LOCAL search_path TO transit, public, extensions, auth;

-- ---------------------------------------------------------------------------
-- Feed configuration: one row per upstream feed for an agency.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS feeds (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    adapter text NOT NULL,
    name text NOT NULL,
    config jsonb NOT NULL DEFAULT '{}',
    static_url text,
    realtime_url text,
    rate_strategy jsonb NOT NULL DEFAULT '{"kind": "fixed_interval", "interval_seconds": 300}',
    enabled boolean NOT NULL DEFAULT true,
    last_sync_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (agency_id, adapter, name)
);

CREATE INDEX IF NOT EXISTS idx_feeds_agency ON feeds (agency_id);
CREATE INDEX IF NOT EXISTS idx_feeds_enabled ON feeds (agency_id, enabled);

-- ---------------------------------------------------------------------------
-- Sync runs: an audit row for every adapter invocation, static or realtime.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    feed_id uuid REFERENCES feeds(id) ON DELETE SET NULL,
    adapter text NOT NULL,
    kind text NOT NULL CHECK (kind IN ('static', 'realtime', 'validate')),
    started_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    status text NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'success', 'partial', 'failed')),
    diagnostics jsonb[] NOT NULL DEFAULT '{}',
    records_upserted integer,
    records_unchanged integer,
    feed_version text,
    actor_id uuid,
    ip inet
);

CREATE INDEX IF NOT EXISTS idx_sync_runs_agency_ts ON sync_runs (agency_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_sync_runs_feed ON sync_runs (feed_id, started_at DESC);

-- ---------------------------------------------------------------------------
-- Feed quarantine: malformed payloads and diagnostics. Fails the feed, not the
-- worker, so a single bad agency does not stop the scheduler.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS feed_quarantine (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    feed_id uuid REFERENCES feeds(id) ON DELETE SET NULL,
    raw_payload_path text,
    error text NOT NULL,
    diagnostics jsonb NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feed_quarantine_agency ON feed_quarantine (agency_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Helpers: SECURITY DEFINER inserts for the Go API (transit_app role).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION sync_run_insert(
    _agency_id uuid,
    _feed_id uuid,
    _adapter text,
    _kind text,
    _started_at timestamptz,
    _finished_at timestamptz,
    _status text,
    _diagnostics jsonb[],
    _records_upserted integer,
    _records_unchanged integer,
    _feed_version text,
    _actor_id uuid,
    _ip inet
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO sync_runs (
        agency_id, feed_id, adapter, kind, started_at, finished_at, status,
        diagnostics, records_upserted, records_unchanged, feed_version, actor_id, ip
    )
    VALUES (
        _agency_id, _feed_id, _adapter, _kind, _started_at, _finished_at, _status,
        COALESCE(_diagnostics, '{}'), _records_upserted, _records_unchanged,
        _feed_version, _actor_id, _ip
    )
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION feed_quarantine_insert(
    _agency_id uuid,
    _feed_id uuid,
    _raw_payload_path text,
    _error text,
    _diagnostics jsonb
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO feed_quarantine (agency_id, feed_id, raw_payload_path, error, diagnostics)
    VALUES (_agency_id, _feed_id, _raw_payload_path, _error, COALESCE(_diagnostics, '{}'))
    RETURNING id;
$$;

GRANT EXECUTE ON FUNCTION sync_run_insert TO transit_app;
GRANT EXECUTE ON FUNCTION feed_quarantine_insert TO transit_app;

-- ---------------------------------------------------------------------------
-- RLS policies.
-- ---------------------------------------------------------------------------
ALTER TABLE feeds ENABLE ROW LEVEL SECURITY;
ALTER TABLE feeds FORCE ROW LEVEL SECURITY;
ALTER TABLE sync_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_runs FORCE ROW LEVEL SECURITY;
ALTER TABLE feed_quarantine ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_quarantine FORCE ROW LEVEL SECURITY;

-- feeds: read/write limited to agency_admin / super_admin for the agency.
CREATE POLICY feeds_select_own ON feeds FOR SELECT USING (admin_write_policy(agency_id));
CREATE POLICY feeds_write_own ON feeds FOR ALL USING (admin_write_policy(agency_id)) WITH CHECK (admin_write_policy(agency_id));

-- sync_runs: readable within the agency; inserted via the helper above.
CREATE POLICY sync_runs_select_own ON sync_runs FOR SELECT USING (
    current_user_role() = 'super_admin' OR current_agency_id() = agency_id
);

-- feed_quarantine: readable by agency_admin/dispatcher/super_admin for the agency.
CREATE POLICY feed_quarantine_select_own ON feed_quarantine FOR SELECT USING (
    current_user_role() IN ('super_admin', 'agency_admin', 'fleet_manager', 'dispatcher')
    AND current_agency_id() = agency_id
);

-- Grant app role access to the new objects.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;

-- ---------------------------------------------------------------------------
-- Patch Phase 1 RLS helpers so super_admin can read canonical GTFS tables.
-- This is required for the ingestor and for admin-wide analytics.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION gtfs_read_policy(agency_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    RETURN current_user_role() = 'super_admin' OR agency_uuid = current_agency_id();
END;
$$;
