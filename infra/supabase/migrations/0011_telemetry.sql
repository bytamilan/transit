-- Migration 0011_telemetry
-- Phase 7: tables the driver app writes to — raw GPS pings and one-tap
-- incident reports. Phase 8 owns partitioning/retention/rollup for
-- vehicle_pings and the server-side map-matching that makes stop_events
-- authoritative; this migration only adds the ingestion surface.
--
-- vehicle_trips (brief §8) does not exist yet — that arrives with Phase 8's
-- server-side tracking. incident_reports links to duty_assignments instead
-- of a trip for now; Phase 8/9 can add a trip_id column once vehicle_trips
-- exists.

SET LOCAL search_path TO transit, public, extensions, auth;

CREATE TABLE IF NOT EXISTS vehicle_pings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    assignment_id uuid NOT NULL REFERENCES duty_assignments(id) ON DELETE CASCADE,
    ts timestamptz NOT NULL,
    geog geography(POINT,4326) NOT NULL,
    heading double precision,
    speed double precision,
    accuracy_m double precision,
    occupancy integer, -- GTFS-RT OccupancyStatus enum value
    matched_shape_dist double precision,
    source text NOT NULL DEFAULT 'driver_app',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_vehicle_pings_assignment_ts ON vehicle_pings (assignment_id, ts DESC);
CREATE INDEX IF NOT EXISTS idx_vehicle_pings_agency_ts ON vehicle_pings (agency_id, ts DESC);
CREATE INDEX IF NOT EXISTS idx_vehicle_pings_geog ON vehicle_pings USING GIST (geog);

CREATE TABLE IF NOT EXISTS incident_reports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    assignment_id uuid REFERENCES duty_assignments(id) ON DELETE SET NULL,
    kind text NOT NULL,
    note text,
    geog geography(POINT,4326),
    ts timestamptz NOT NULL DEFAULT now(),
    resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_incident_reports_agency_ts ON incident_reports (agency_id, ts DESC);
CREATE INDEX IF NOT EXISTS idx_incident_reports_open ON incident_reports (agency_id, ts DESC) WHERE resolved_at IS NULL;

ALTER TABLE vehicle_pings ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_pings FORCE ROW LEVEL SECURITY;
ALTER TABLE incident_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE incident_reports FORCE ROW LEVEL SECURITY;

-- Raw pings are a driver-surveillance dataset: drivers may insert only for
-- their own currently-open duty, dispatchers/fleet/agency admins may read
-- pings for open duties in their agency (depot-scoped for dispatchers), and
-- no policy exists for rider/data_consumer — RLS defaults to deny.
CREATE OR REPLACE FUNCTION own_open_duty(_assignment_id uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    da record;
BEGIN
    SELECT agency_id, driver_id, status INTO da FROM duty_assignments WHERE id = _assignment_id;
    IF da IS NULL THEN
        RETURN false;
    END IF;
    RETURN da.driver_id = current_user_id()
        AND current_agency_id() = da.agency_id
        AND da.status IN ('signed_on', 'in_progress');
END;
$$;

CREATE POLICY vehicle_pings_insert_own_duty ON vehicle_pings FOR INSERT WITH CHECK (
    current_user_role() = 'driver' AND own_open_duty(assignment_id)
);
CREATE POLICY vehicle_pings_select_dispatch ON vehicle_pings FOR SELECT USING (
    current_user_role() = 'super_admin' OR (
        current_agency_id() = agency_id AND EXISTS (
            SELECT 1 FROM duty_assignments da
            WHERE da.id = vehicle_pings.assignment_id
              AND da.status IN ('signed_on', 'in_progress')
              AND duty_visible(da.agency_id, da.driver_id)
              AND current_user_role() IN ('dispatcher', 'fleet_manager', 'agency_admin')
        )
    )
);

CREATE POLICY incident_reports_insert_own_duty ON incident_reports FOR INSERT WITH CHECK (
    current_user_role() = 'driver' AND (assignment_id IS NULL OR own_open_duty(assignment_id))
    AND current_agency_id() = agency_id
);
CREATE POLICY incident_reports_select_dispatch ON incident_reports FOR SELECT USING (
    current_user_role() = 'super_admin'
    OR (current_agency_id() = agency_id AND current_user_role() IN ('dispatcher', 'fleet_manager', 'agency_admin'))
);
CREATE POLICY incident_reports_update_dispatch ON incident_reports FOR UPDATE USING (
    current_user_role() = 'super_admin'
    OR (current_agency_id() = agency_id AND current_user_role() IN ('dispatcher', 'fleet_manager', 'agency_admin'))
);

-- ---------------------------------------------------------------------------
-- SECURITY DEFINER helpers for the Go driver API. Go re-checks ownership
-- (assignment.driver_id == the caller) before calling these — see
-- internal/httpapi/handlers/driver.go.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION insert_vehicle_ping(
    _agency_id uuid, _assignment_id uuid, _ts timestamptz, _lat double precision, _lon double precision,
    _heading double precision, _speed double precision, _accuracy_m double precision,
    _occupancy integer, _matched_shape_dist double precision, _source text
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO vehicle_pings (agency_id, assignment_id, ts, geog, heading, speed, accuracy_m,
                                occupancy, matched_shape_dist, source)
    VALUES (_agency_id, _assignment_id, _ts, ST_SetSRID(ST_MakePoint(_lon, _lat), 4326)::geography,
            _heading, _speed, _accuracy_m, _occupancy, _matched_shape_dist, COALESCE(_source, 'driver_app'))
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION insert_incident_report(
    _agency_id uuid, _assignment_id uuid, _kind text, _note text, _lat double precision, _lon double precision
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO incident_reports (agency_id, assignment_id, kind, note, geog)
    VALUES (_agency_id, _assignment_id, _kind, _note,
            CASE WHEN _lat IS NULL OR _lon IS NULL THEN NULL
                 ELSE ST_SetSRID(ST_MakePoint(_lon, _lat), 4326)::geography END)
    RETURNING id;
$$;

GRANT EXECUTE ON FUNCTION own_open_duty TO transit_app;
GRANT EXECUTE ON FUNCTION insert_vehicle_ping TO transit_app;
GRANT EXECUTE ON FUNCTION insert_incident_report TO transit_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
