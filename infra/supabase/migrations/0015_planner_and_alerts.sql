-- Migration 0015_planner_and_alerts
-- Phase 11: service alerts (admin-authored, GTFS-RT ServiceAlerts feed,
-- rider-app banners) and a bulk stop_times read the RAPTOR planner needs to
-- build an in-memory timetable without one query per trip.

SET LOCAL search_path TO transit, public, extensions, auth;

-- ---------------------------------------------------------------------------
-- Service alerts. header_text/description_text/url are jsonb locale maps
-- ({"en": "...", "ta": "..."}), the same shape as agencies.name — the
-- GTFS-RT feed builder converts a locale map into a TranslatedString with
-- one Translation entry per key. An alert with empty informed_routes AND
-- informed_stops applies agency-wide (GTFS-RT allows an EntitySelector with
-- just agency_id set).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_alerts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    cause text NOT NULL DEFAULT 'unknown_cause' CHECK (cause IN (
        'unknown_cause', 'other_cause', 'technical_problem', 'strike',
        'demonstration', 'accident', 'holiday', 'weather', 'maintenance',
        'construction', 'police_activity', 'medical_emergency'
    )),
    effect text NOT NULL DEFAULT 'unknown_effect' CHECK (effect IN (
        'no_service', 'reduced_service', 'significant_delays', 'detour',
        'additional_service', 'modified_service', 'other_effect',
        'unknown_effect', 'stop_moved', 'no_effect', 'accessibility_issue'
    )),
    header_text jsonb NOT NULL,
    description_text jsonb NOT NULL DEFAULT '{}'::jsonb,
    url jsonb,
    informed_routes text[] NOT NULL DEFAULT '{}',
    informed_stops text[] NOT NULL DEFAULT '{}',
    active_from timestamptz NOT NULL DEFAULT now(),
    active_until timestamptz,
    created_by uuid,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_service_alerts_agency_active
    ON service_alerts (agency_id, active_from, active_until);

ALTER TABLE service_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_alerts FORCE ROW LEVEL SECURITY;

-- Read is broad (riders, drivers, dispatchers, everyone in the agency) —
-- alerts are also served publicly and unauthenticated via /v0, through the
-- SECURITY DEFINER list_service_alerts function below, same as every other
-- public read in this codebase (RLS here is defense-in-depth, not the
-- actual authorization boundary — see internal/httpapi/rbac).
CREATE POLICY service_alerts_select ON service_alerts FOR SELECT USING (
    current_user_role() = 'super_admin' OR current_agency_id() = agency_id
);
CREATE POLICY service_alerts_write ON service_alerts FOR INSERT WITH CHECK (
    current_user_role() = 'super_admin' OR (
        current_agency_id() = agency_id
        AND current_user_role() IN ('agency_admin', 'fleet_manager', 'dispatcher')
    )
);
CREATE POLICY service_alerts_update ON service_alerts FOR UPDATE USING (
    current_user_role() = 'super_admin' OR (
        current_agency_id() = agency_id
        AND current_user_role() IN ('agency_admin', 'fleet_manager', 'dispatcher')
    )
);
CREATE POLICY service_alerts_delete ON service_alerts FOR DELETE USING (
    current_user_role() = 'super_admin' OR (
        current_agency_id() = agency_id
        AND current_user_role() IN ('agency_admin', 'fleet_manager', 'dispatcher')
    )
);

CREATE OR REPLACE FUNCTION upsert_service_alert(
    _agency_id uuid,
    _id uuid,
    _cause text,
    _effect text,
    _header_text jsonb,
    _description_text jsonb,
    _url jsonb,
    _informed_routes text[],
    _informed_stops text[],
    _active_from timestamptz,
    _active_until timestamptz,
    _created_by uuid
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO service_alerts (
        id, agency_id, cause, effect, header_text, description_text, url,
        informed_routes, informed_stops, active_from, active_until, created_by
    )
    VALUES (
        COALESCE(_id, gen_random_uuid()), _agency_id, _cause, _effect,
        _header_text, _description_text, _url, _informed_routes,
        _informed_stops, _active_from, _active_until, _created_by
    )
    ON CONFLICT (id) DO UPDATE SET
        cause = EXCLUDED.cause,
        effect = EXCLUDED.effect,
        header_text = EXCLUDED.header_text,
        description_text = EXCLUDED.description_text,
        url = EXCLUDED.url,
        informed_routes = EXCLUDED.informed_routes,
        informed_stops = EXCLUDED.informed_stops,
        active_from = EXCLUDED.active_from,
        active_until = EXCLUDED.active_until,
        updated_at = now()
    WHERE service_alerts.agency_id = _agency_id
    RETURNING id;
$$;

-- _active_only additionally excludes resolved alerts and ones outside their
-- active window — used by both the public feed/banner reads and the
-- exporter's GTFS-RT builder; the admin queue passes _active_only = false to
-- see everything including resolved history.
CREATE OR REPLACE FUNCTION list_service_alerts(_agency_id uuid, _active_only boolean)
RETURNS TABLE (
    id uuid, cause text, effect text, header_text jsonb, description_text jsonb,
    url jsonb, informed_routes text[], informed_stops text[],
    active_from timestamptz, active_until timestamptz, created_by uuid,
    created_at timestamptz, updated_at timestamptz, resolved_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT id, cause, effect, header_text, description_text, url,
           informed_routes, informed_stops, active_from, active_until,
           created_by, created_at, updated_at, resolved_at
    FROM service_alerts
    WHERE agency_id = _agency_id
      AND (NOT _active_only OR (
          resolved_at IS NULL
          AND active_from <= now()
          AND (active_until IS NULL OR active_until >= now())
      ))
    ORDER BY active_from DESC;
$$;

CREATE OR REPLACE FUNCTION resolve_service_alert(_agency_id uuid, _id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    UPDATE service_alerts SET resolved_at = now(), updated_at = now()
    WHERE agency_id = _agency_id AND id = _id;
$$;

CREATE OR REPLACE FUNCTION delete_service_alert(_agency_id uuid, _id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    DELETE FROM service_alerts WHERE agency_id = _agency_id AND id = _id;
$$;

-- ---------------------------------------------------------------------------
-- Bulk stop_times read for the RAPTOR planner's in-memory timetable build.
-- list_trip_stop_times (0008) is per-trip — fine for the public API and the
-- exporter's per-trip loop, but a planner needs every stop_time for the
-- agency in one query rather than one round-trip per trip.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION list_all_stop_times(_agency_id uuid)
RETURNS TABLE (
    trip_id text, stop_id text, arrival_time interval, departure_time interval,
    stop_sequence integer, pickup_type integer, drop_off_type integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT trip_id, stop_id, arrival_time, departure_time, stop_sequence,
           pickup_type, drop_off_type
    FROM stop_times
    WHERE agency_id = _agency_id
    ORDER BY trip_id, stop_sequence;
$$;

GRANT EXECUTE ON FUNCTION upsert_service_alert TO transit_app;
GRANT EXECUTE ON FUNCTION list_service_alerts TO transit_app;
GRANT EXECUTE ON FUNCTION resolve_service_alert TO transit_app;
GRANT EXECUTE ON FUNCTION delete_service_alert TO transit_app;
GRANT EXECUTE ON FUNCTION list_all_stop_times TO transit_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
