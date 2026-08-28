-- Migration 0018_osm_stop_import
-- Helpers for the admin OSM bus-stop import (preview + confirm). Imported
-- stop_ids are namespaced as "osm:node:<id>" so re-imports upsert the same
-- canonical GTFS stop row from 0003_gtfs_core. upsert_stops does the bulk
-- write; find_stops_near backs the preview's duplicate detection. The audit
-- trail is written by the API caller, same as the 0010 route editor helpers.

SET LOCAL search_path TO transit, public, extensions, auth;

-- _stops is a JSON array of {stop_id, stop_name, stop_code?, stop_lat?,
-- stop_lon?, wheelchair_boarding?, platform_code?}. stop_loc is derived from
-- the coordinates; a row without coordinates lands with NULL stop_loc, same
-- as a GTFS import of a stop without lat/lon.
CREATE OR REPLACE FUNCTION upsert_stops(_agency_id uuid, _stops jsonb)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
DECLARE
    _count integer;
BEGIN
    WITH upserted AS (
        INSERT INTO stops (agency_id, stop_id, stop_code, stop_name, stop_lat, stop_lon,
                            stop_loc, wheelchair_boarding, platform_code)
        SELECT _agency_id, x.stop_id, x.stop_code, x.stop_name, x.stop_lat, x.stop_lon,
               CASE WHEN x.stop_lat IS NULL OR x.stop_lon IS NULL THEN NULL
                    ELSE ST_SetSRID(ST_MakePoint(x.stop_lon, x.stop_lat), 4326)::geography
               END,
               x.wheelchair_boarding, x.platform_code
        FROM jsonb_to_recordset(_stops) AS x(
            stop_id text, stop_name text, stop_code text,
            stop_lat double precision, stop_lon double precision,
            wheelchair_boarding integer, platform_code text
        )
        ON CONFLICT (agency_id, stop_id) DO UPDATE SET
            stop_code = EXCLUDED.stop_code,
            stop_name = EXCLUDED.stop_name,
            stop_lat = EXCLUDED.stop_lat,
            stop_lon = EXCLUDED.stop_lon,
            stop_loc = EXCLUDED.stop_loc,
            wheelchair_boarding = EXCLUDED.wheelchair_boarding,
            platform_code = EXCLUDED.platform_code,
            updated_at = now()
        RETURNING 1
    )
    SELECT count(*) INTO _count FROM upserted;
    RETURN _count;
END;
$$;

-- Returns stops within _radius_m of a point, nearest first.
CREATE OR REPLACE FUNCTION find_stops_near(
    _agency_id uuid,
    _lat double precision,
    _lon double precision,
    _radius_m double precision
)
RETURNS TABLE (
    stop_id text,
    stop_name text,
    distance_m double precision
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT s.stop_id, s.stop_name,
           ST_Distance(s.stop_loc, ST_SetSRID(ST_MakePoint(_lon, _lat), 4326)::geography) AS distance_m
    FROM stops s
    WHERE s.agency_id = _agency_id
      AND s.stop_loc IS NOT NULL
      AND ST_DWithin(s.stop_loc, ST_SetSRID(ST_MakePoint(_lon, _lat), 4326)::geography, _radius_m)
    ORDER BY distance_m;
$$;

GRANT EXECUTE ON FUNCTION upsert_stops TO transit_app;
GRANT EXECUTE ON FUNCTION find_stops_near TO transit_app;
