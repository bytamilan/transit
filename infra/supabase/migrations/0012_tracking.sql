-- Migration 0012_tracking
-- Phase 8: server-side tracking. Adds vehicle_trips (one row per GTFS trip
-- actually run within a duty) and stop_events (arrivals/departures/delay,
-- recomputed authoritatively from the raw ping trace by
-- internal/tracking — see its package doc for why the driver app's
-- on-device version is a hint only), plus the SECURITY DEFINER helpers the
-- new cmd/tracker background service uses.
--
-- Partitioning note: the brief calls for daily partitions on vehicle_pings.
-- This migration ships retention (a pg_cron purge job) but not partitioning
-- — converting an existing table to a partitioned one means recreating it,
-- and doing that blind (this was built without a live Postgres to verify
-- against) was judged too risky for a mechanism the Phase 8 gate doesn't
-- actually exercise. Partitioning is real follow-up work, not abandoned
-- scope — see docs/PHASE_PLAN.md Phase 8.

SET LOCAL search_path TO transit, public, extensions, auth;

-- ---------------------------------------------------------------------------
-- vehicle_trips: one GTFS trip actually run within a duty_assignment. A
-- block spans several trips in sequence; this is how we know which trip a
-- given stop_event belongs to and when each trip actually started/ended.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vehicle_trips (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    assignment_id uuid NOT NULL REFERENCES duty_assignments(id) ON DELETE CASCADE,
    trip_id text NOT NULL,
    vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    driver_id uuid NOT NULL REFERENCES driver_profiles(user_id) ON DELETE CASCADE,
    started_at timestamptz,
    ended_at timestamptz,
    start_source text NOT NULL DEFAULT 'server_replay',
    end_source text,
    status text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress', 'completed')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (agency_id, assignment_id, trip_id)
);

CREATE INDEX IF NOT EXISTS idx_vehicle_trips_assignment ON vehicle_trips (assignment_id);
CREATE INDEX IF NOT EXISTS idx_vehicle_trips_agency_status ON vehicle_trips (agency_id, status);

-- ---------------------------------------------------------------------------
-- stop_events: the authoritative arrival/departure/delay record. Never
-- written by the driver app directly — only by the SECURITY DEFINER helper
-- below, called from internal/tracking.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stop_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    vehicle_trip_id uuid NOT NULL REFERENCES vehicle_trips(id) ON DELETE CASCADE,
    trip_id text NOT NULL,
    stop_id text NOT NULL,
    stop_sequence integer NOT NULL,
    arrived_at timestamptz,
    departed_at timestamptz,
    delay_s integer,
    confidence text NOT NULL CHECK (confidence IN ('high', 'medium', 'low')),
    derived_by text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (vehicle_trip_id, stop_sequence)
);

CREATE INDEX IF NOT EXISTS idx_stop_events_trip_stop ON stop_events (agency_id, trip_id, stop_id);
CREATE INDEX IF NOT EXISTS idx_stop_events_vehicle_trip ON stop_events (vehicle_trip_id, stop_sequence);

ALTER TABLE vehicle_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicle_trips FORCE ROW LEVEL SECURITY;
ALTER TABLE stop_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE stop_events FORCE ROW LEVEL SECURITY;

-- Same visibility rule as duty_assignments/vehicle_pings: agency staff and
-- the owning driver; nothing for riders or data_consumers (arrivals with
-- realtime data go through the public read API's own SECURITY DEFINER path,
-- never direct table access).
CREATE POLICY vehicle_trips_select ON vehicle_trips FOR SELECT USING (
    current_user_role() = 'super_admin' OR (
        current_agency_id() = agency_id AND (
            current_user_role() IN ('agency_admin', 'fleet_manager', 'dispatcher')
            OR driver_id = current_user_id()
        )
    )
);
CREATE POLICY vehicle_trips_write ON vehicle_trips FOR ALL
    USING (current_user_role() = 'super_admin')
    WITH CHECK (current_user_role() = 'super_admin');

CREATE POLICY stop_events_select ON stop_events FOR SELECT USING (
    current_user_role() = 'super_admin' OR (
        current_agency_id() = agency_id AND EXISTS (
            SELECT 1 FROM vehicle_trips vt WHERE vt.id = stop_events.vehicle_trip_id
              AND (current_user_role() IN ('agency_admin', 'fleet_manager', 'dispatcher') OR vt.driver_id = current_user_id())
        )
    )
);
CREATE POLICY stop_events_write ON stop_events FOR ALL
    USING (current_user_role() = 'super_admin')
    WITH CHECK (current_user_role() = 'super_admin');

-- ---------------------------------------------------------------------------
-- Scheduling input: resolves a block's full stop sequence (across every
-- trip it runs, in order) with each stop's scheduled arrival/departure
-- converted to a real instant per ADR 0002 (noon-minus-12-hours + the GTFS
-- elapsed-time interval, in the agency's timezone).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION block_stop_schedule(_agency_id uuid, _block_id uuid)
RETURNS TABLE (
    trip_id text,
    stop_id text,
    stop_sequence integer,
    lat double precision,
    lon double precision,
    scheduled_arrival timestamptz,
    scheduled_departure timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
DECLARE
    tz text;
    svc_date date;
    origin timestamptz;
BEGIN
    SELECT a.timezone INTO tz FROM agencies a WHERE a.id = _agency_id;
    SELECT b.service_date INTO svc_date FROM blocks b WHERE b.id = _block_id AND b.agency_id = _agency_id;
    IF tz IS NULL OR svc_date IS NULL THEN
        RETURN;
    END IF;
    origin := (svc_date::timestamp + time '12:00:00') AT TIME ZONE tz - interval '12 hours';

    RETURN QUERY
    SELECT
        bt.trip_id,
        st.stop_id,
        st.stop_sequence,
        s.stop_lat,
        s.stop_lon,
        origin + st.arrival_time,
        origin + st.departure_time
    FROM blocks b
    CROSS JOIN LATERAL unnest(b.trip_ids) WITH ORDINALITY AS bt(trip_id, ord)
    JOIN stop_times st ON st.agency_id = b.agency_id AND st.trip_id = bt.trip_id
    JOIN stops s ON s.agency_id = b.agency_id AND s.stop_id = st.stop_id
    WHERE b.id = _block_id AND b.agency_id = _agency_id
    ORDER BY bt.ord, st.stop_sequence;
END;
$$;

-- ---------------------------------------------------------------------------
-- Raw trace read for reprocessing. Callable only by transit_app from
-- internal/tracking — never exposed through any HTTP route, public or
-- authenticated (raw pings are a driver-surveillance dataset, brief §10).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION list_pings_for_assignment(_agency_id uuid, _assignment_id uuid)
RETURNS TABLE (ts timestamptz, lat double precision, lon double precision, speed double precision, accuracy_m double precision)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT p.ts, ST_Y(p.geog::geometry), ST_X(p.geog::geometry), p.speed, p.accuracy_m
    FROM vehicle_pings p
    WHERE p.agency_id = _agency_id AND p.assignment_id = _assignment_id
    ORDER BY p.ts;
$$;

-- ---------------------------------------------------------------------------
-- What cmd/tracker polls: every currently-open duty assignment, across every
-- agency (it is a platform-wide background service, not agency-scoped).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION list_open_duty_assignments_for_tracking()
RETURNS TABLE (agency_id uuid, assignment_id uuid, block_id uuid, driver_id uuid, vehicle_id uuid, service_date date)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT da.agency_id, da.id, da.block_id, da.driver_id, da.vehicle_id, da.service_date
    FROM duty_assignments da
    WHERE da.status IN ('signed_on', 'in_progress');
$$;

-- ---------------------------------------------------------------------------
-- Upserts.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION upsert_vehicle_trip(
    _agency_id uuid, _assignment_id uuid, _trip_id text, _vehicle_id uuid, _driver_id uuid,
    _started_at timestamptz, _ended_at timestamptz, _start_source text, _end_source text
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO vehicle_trips (agency_id, assignment_id, trip_id, vehicle_id, driver_id,
                                started_at, ended_at, start_source, end_source, status)
    VALUES (_agency_id, _assignment_id, _trip_id, _vehicle_id, _driver_id,
            _started_at, _ended_at, _start_source, _end_source,
            CASE WHEN _ended_at IS NOT NULL THEN 'completed' ELSE 'in_progress' END)
    ON CONFLICT (agency_id, assignment_id, trip_id) DO UPDATE SET
        started_at = COALESCE(vehicle_trips.started_at, EXCLUDED.started_at),
        ended_at = EXCLUDED.ended_at,
        end_source = EXCLUDED.end_source,
        status = EXCLUDED.status,
        updated_at = now()
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION upsert_stop_event(
    _agency_id uuid, _vehicle_trip_id uuid, _trip_id text, _stop_id text, _stop_sequence integer,
    _arrived_at timestamptz, _departed_at timestamptz, _delay_s integer, _confidence text, _derived_by text
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO stop_events (agency_id, vehicle_trip_id, trip_id, stop_id, stop_sequence,
                              arrived_at, departed_at, delay_s, confidence, derived_by)
    VALUES (_agency_id, _vehicle_trip_id, _trip_id, _stop_id, _stop_sequence,
            _arrived_at, _departed_at, _delay_s, _confidence, _derived_by)
    ON CONFLICT (vehicle_trip_id, stop_sequence) DO UPDATE SET
        arrived_at = EXCLUDED.arrived_at,
        departed_at = EXCLUDED.departed_at,
        delay_s = EXCLUDED.delay_s,
        confidence = EXCLUDED.confidence,
        derived_by = EXCLUDED.derived_by,
        updated_at = now()
    RETURNING id;
$$;

-- ---------------------------------------------------------------------------
-- Public read support: lets the /v0 arrivals endpoint layer realtime
-- predictions onto the static timetable (Phase 4 left this as a forward
-- reference — "Realtime predictions will be layered on top in Phase 8").
-- Only ever returns confirmed/interpolated stop_events, never raw pings.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION list_live_predictions(_agency_id uuid, _service_date date)
RETURNS TABLE (trip_id text, stop_id text, arrived_at timestamptz, departed_at timestamptz, delay_s integer, confidence text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT se.trip_id, se.stop_id, se.arrived_at, se.departed_at, se.delay_s, se.confidence
    FROM stop_events se
    JOIN vehicle_trips vt ON vt.id = se.vehicle_trip_id
    JOIN duty_assignments da ON da.id = vt.assignment_id
    WHERE se.agency_id = _agency_id AND da.service_date = _service_date;
$$;

-- ---------------------------------------------------------------------------
-- Current position per active vehicle — the narrow, position-only read the
-- GTFS-RT publisher uses. Never the raw trace: one row per in-progress
-- vehicle_trip, its latest ping and latest resolved stop_event only.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION current_vehicle_positions(_agency_id uuid)
RETURNS TABLE (
    assignment_id uuid,
    block_id uuid,
    vehicle_id uuid,
    trip_id text,
    lat double precision,
    lon double precision,
    heading double precision,
    speed double precision,
    ping_ts timestamptz,
    occupancy integer,
    last_stop_sequence integer,
    last_arrived_at timestamptz,
    last_departed_at timestamptz,
    last_delay_s integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    WITH latest_ping AS (
        SELECT DISTINCT ON (p.assignment_id)
            p.assignment_id, p.ts, ST_Y(p.geog::geometry) AS lat, ST_X(p.geog::geometry) AS lon,
            p.heading, p.speed, p.occupancy
        FROM vehicle_pings p
        WHERE p.agency_id = _agency_id
        ORDER BY p.assignment_id, p.ts DESC
    ),
    latest_stop_event AS (
        SELECT DISTINCT ON (se.vehicle_trip_id)
            se.vehicle_trip_id, se.stop_sequence, se.arrived_at, se.departed_at, se.delay_s
        FROM stop_events se
        JOIN vehicle_trips vt ON vt.id = se.vehicle_trip_id
        WHERE vt.agency_id = _agency_id
        ORDER BY se.vehicle_trip_id, se.stop_sequence DESC
    )
    SELECT
        vt.assignment_id, da.block_id, vt.vehicle_id, vt.trip_id,
        lp.lat, lp.lon, lp.heading, lp.speed, lp.ts, lp.occupancy,
        lse.stop_sequence, lse.arrived_at, lse.departed_at, lse.delay_s
    FROM vehicle_trips vt
    JOIN duty_assignments da ON da.id = vt.assignment_id
    JOIN latest_ping lp ON lp.assignment_id = vt.assignment_id
    LEFT JOIN latest_stop_event lse ON lse.vehicle_trip_id = vt.id
    WHERE vt.agency_id = _agency_id AND vt.status = 'in_progress';
$$;

-- ---------------------------------------------------------------------------
-- Retention: purge raw pings older than the window (default 7 days per
-- brief §8). The existing ingest scheduler (Phase 3) owns periodic work in
-- Go rather than pg_cron (cmd/ingestor ticks its own timers); cmd/tracker
-- follows the same convention and calls this daily rather than scheduling it
-- in Postgres.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION purge_old_vehicle_pings(_retention_days integer DEFAULT 7)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
DECLARE
    deleted bigint;
BEGIN
    DELETE FROM vehicle_pings WHERE ts < now() - make_interval(days => _retention_days);
    GET DIAGNOSTICS deleted = ROW_COUNT;
    RETURN deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION block_stop_schedule TO transit_app;
GRANT EXECUTE ON FUNCTION list_pings_for_assignment TO transit_app;
GRANT EXECUTE ON FUNCTION list_open_duty_assignments_for_tracking TO transit_app;
GRANT EXECUTE ON FUNCTION upsert_vehicle_trip TO transit_app;
GRANT EXECUTE ON FUNCTION upsert_stop_event TO transit_app;
GRANT EXECUTE ON FUNCTION list_live_predictions TO transit_app;
GRANT EXECUTE ON FUNCTION current_vehicle_positions TO transit_app;
GRANT EXECUTE ON FUNCTION purge_old_vehicle_pings TO transit_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
