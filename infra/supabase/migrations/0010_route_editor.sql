-- Migration 0010_route_editor
-- Phase 6.4: write helpers for the admin routes & timetables editor. Edits
-- land directly on the canonical GTFS tables from 0003_gtfs_core (no
-- separate draft/publish layer) — the audit log is the edit history.

SET LOCAL search_path TO transit, public, extensions, auth;

CREATE OR REPLACE FUNCTION upsert_route(
    _agency_id uuid, _route_id text, _route_short_name text, _route_long_name text,
    _route_desc text, _route_type integer, _route_url text, _route_color text,
    _route_text_color text, _route_sort_order integer
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO routes (agency_id, route_id, route_short_name, route_long_name, route_desc,
                         route_type, route_url, route_color, route_text_color, route_sort_order)
    VALUES (_agency_id, _route_id, _route_short_name, _route_long_name, _route_desc,
            _route_type, _route_url, _route_color, _route_text_color, _route_sort_order)
    ON CONFLICT (agency_id, route_id) DO UPDATE SET
        route_short_name = EXCLUDED.route_short_name,
        route_long_name = EXCLUDED.route_long_name,
        route_desc = EXCLUDED.route_desc,
        route_type = EXCLUDED.route_type,
        route_url = EXCLUDED.route_url,
        route_color = EXCLUDED.route_color,
        route_text_color = EXCLUDED.route_text_color,
        route_sort_order = EXCLUDED.route_sort_order,
        updated_at = now();
$$;

CREATE OR REPLACE FUNCTION delete_route(_agency_id uuid, _route_id text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    DELETE FROM routes WHERE agency_id = _agency_id AND route_id = _route_id;
$$;

CREATE OR REPLACE FUNCTION upsert_calendar(
    _agency_id uuid, _service_id text, _monday boolean, _tuesday boolean, _wednesday boolean,
    _thursday boolean, _friday boolean, _saturday boolean, _sunday boolean,
    _start_date date, _end_date date
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO calendar (agency_id, service_id, monday, tuesday, wednesday, thursday, friday,
                           saturday, sunday, start_date, end_date)
    VALUES (_agency_id, _service_id, _monday, _tuesday, _wednesday, _thursday, _friday,
            _saturday, _sunday, _start_date, _end_date)
    ON CONFLICT (agency_id, service_id) DO UPDATE SET
        monday = EXCLUDED.monday, tuesday = EXCLUDED.tuesday, wednesday = EXCLUDED.wednesday,
        thursday = EXCLUDED.thursday, friday = EXCLUDED.friday, saturday = EXCLUDED.saturday,
        sunday = EXCLUDED.sunday, start_date = EXCLUDED.start_date, end_date = EXCLUDED.end_date,
        updated_at = now();
$$;

CREATE OR REPLACE FUNCTION list_calendars(_agency_id uuid)
RETURNS TABLE (
    service_id text, monday boolean, tuesday boolean, wednesday boolean, thursday boolean,
    friday boolean, saturday boolean, sunday boolean, start_date date, end_date date
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date
    FROM calendar
    WHERE agency_id = _agency_id
    ORDER BY service_id;
$$;

CREATE OR REPLACE FUNCTION upsert_trip(
    _agency_id uuid, _trip_id text, _route_id text, _service_id text, _trip_headsign text,
    _trip_short_name text, _direction_id integer, _block_id text, _shape_id text,
    _wheelchair_accessible integer, _bikes_allowed integer
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO trips (agency_id, trip_id, route_id, service_id, trip_headsign, trip_short_name,
                        direction_id, block_id, shape_id, wheelchair_accessible, bikes_allowed)
    VALUES (_agency_id, _trip_id, _route_id, _service_id, _trip_headsign, _trip_short_name,
            _direction_id, _block_id, _shape_id, _wheelchair_accessible, _bikes_allowed)
    ON CONFLICT (agency_id, trip_id) DO UPDATE SET
        route_id = EXCLUDED.route_id,
        service_id = EXCLUDED.service_id,
        trip_headsign = EXCLUDED.trip_headsign,
        trip_short_name = EXCLUDED.trip_short_name,
        direction_id = EXCLUDED.direction_id,
        block_id = EXCLUDED.block_id,
        shape_id = EXCLUDED.shape_id,
        wheelchair_accessible = EXCLUDED.wheelchair_accessible,
        bikes_allowed = EXCLUDED.bikes_allowed,
        updated_at = now();
$$;

CREATE OR REPLACE FUNCTION delete_trip(_agency_id uuid, _trip_id text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    DELETE FROM trips WHERE agency_id = _agency_id AND trip_id = _trip_id;
$$;

-- Replaces every stop_times row for a trip in one transaction, so a
-- reordered stop sequence never leaves stale rows behind. _stop_times is a
-- JSON array of {stop_id, arrival_time, departure_time, stop_sequence,
-- stop_headsign?, pickup_type?, drop_off_type?, timepoint?}. arrival_time /
-- departure_time are GTFS "HH:MM:SS" strings (may exceed 24:00:00 — see ADR
-- 0002); Postgres interval input accepts that format directly.
CREATE OR REPLACE FUNCTION replace_stop_times(_agency_id uuid, _trip_id text, _stop_times jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
BEGIN
    DELETE FROM stop_times WHERE agency_id = _agency_id AND trip_id = _trip_id;

    INSERT INTO stop_times (agency_id, trip_id, stop_id, arrival_time, departure_time,
                             stop_sequence, stop_headsign, pickup_type, drop_off_type, timepoint)
    SELECT _agency_id, _trip_id, x.stop_id, x.arrival_time::interval, x.departure_time::interval,
           x.stop_sequence, x.stop_headsign, x.pickup_type, x.drop_off_type, x.timepoint
    FROM jsonb_to_recordset(_stop_times) AS x(
        stop_id text, arrival_time text, departure_time text, stop_sequence integer,
        stop_headsign text, pickup_type integer, drop_off_type integer, timepoint integer
    );
END;
$$;

GRANT EXECUTE ON FUNCTION upsert_route TO transit_app;
GRANT EXECUTE ON FUNCTION delete_route TO transit_app;
GRANT EXECUTE ON FUNCTION upsert_calendar TO transit_app;
GRANT EXECUTE ON FUNCTION list_calendars TO transit_app;
GRANT EXECUTE ON FUNCTION upsert_trip TO transit_app;
GRANT EXECUTE ON FUNCTION delete_trip TO transit_app;
GRANT EXECUTE ON FUNCTION replace_stop_times TO transit_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
