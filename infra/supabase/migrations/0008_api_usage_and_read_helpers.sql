-- Migration 0008_api_usage_and_read_helpers
-- Adds usage_events for API-key metering and SECURITY DEFINER read helpers
-- used by the Phase 4 public read API.

SET LOCAL search_path TO transit, public, extensions, auth;

-- ---------------------------------------------------------------------------
-- Usage events: token-bucket metering and per-endpoint telemetry for
-- portal-issued API keys.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usage_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    api_key_id uuid NOT NULL REFERENCES api_keys(id) ON DELETE CASCADE,
    ts timestamptz NOT NULL DEFAULT now(),
    endpoint text NOT NULL,
    status integer NOT NULL,
    latency_ms integer
);

CREATE INDEX IF NOT EXISTS idx_usage_events_api_key_ts ON usage_events (api_key_id, ts DESC);
CREATE INDEX IF NOT EXISTS idx_usage_events_endpoint_ts ON usage_events (endpoint, ts DESC);

-- ---------------------------------------------------------------------------
-- Public read helpers. The Go API calls these as transit_app; they bypass
-- RLS so anonymous consumers and API-key holders can read agency data.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_agency_by_slug(_slug text)
RETURNS TABLE (
    id uuid,
    slug text,
    name jsonb,
    timezone text,
    config jsonb
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT id, slug, name, timezone, config
    FROM agencies
    WHERE agencies.slug = _slug
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION list_stops(
    _agency_id uuid,
    _lat double precision,
    _lon double precision,
    _radius_m double precision,
    _limit integer,
    _offset integer
)
RETURNS TABLE (
    stop_id text,
    stop_code text,
    stop_name text,
    stop_desc text,
    stop_lat double precision,
    stop_lon double precision,
    location_type integer,
    parent_station text,
    wheelchair_boarding integer,
    platform_code text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT
        s.stop_id,
        s.stop_code,
        s.stop_name,
        s.stop_desc,
        s.stop_lat,
        s.stop_lon,
        s.location_type,
        s.parent_station,
        s.wheelchair_boarding,
        s.platform_code
    FROM stops s
    WHERE s.agency_id = _agency_id
      AND (_lat IS NULL OR _lon IS NULL OR _radius_m IS NULL
           OR ST_DWithin(s.stop_loc, ST_MakePoint(_lon, _lat)::geography, _radius_m))
    ORDER BY
        CASE WHEN _lat IS NOT NULL AND _lon IS NOT NULL THEN
            ST_Distance(s.stop_loc, ST_MakePoint(_lon, _lat)::geography)
        ELSE 0 END,
        s.stop_name
    LIMIT _limit OFFSET _offset;
$$;

CREATE OR REPLACE FUNCTION get_stop(_agency_id uuid, _stop_id text)
RETURNS TABLE (
    stop_id text,
    stop_code text,
    stop_name text,
    stop_desc text,
    stop_lat double precision,
    stop_lon double precision,
    location_type integer,
    parent_station text,
    wheelchair_boarding integer,
    platform_code text
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT
        s.stop_id,
        s.stop_code,
        s.stop_name,
        s.stop_desc,
        s.stop_lat,
        s.stop_lon,
        s.location_type,
        s.parent_station,
        s.wheelchair_boarding,
        s.platform_code
    FROM stops s
    WHERE s.agency_id = _agency_id AND s.stop_id = _stop_id;
$$;

CREATE OR REPLACE FUNCTION list_routes(
    _agency_id uuid,
    _limit integer,
    _offset integer
)
RETURNS TABLE (
    route_id text,
    route_short_name text,
    route_long_name text,
    route_desc text,
    route_type integer,
    route_url text,
    route_color text,
    route_text_color text,
    route_sort_order integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT
        r.route_id,
        r.route_short_name,
        r.route_long_name,
        r.route_desc,
        r.route_type,
        r.route_url,
        r.route_color,
        r.route_text_color,
        r.route_sort_order
    FROM routes r
    WHERE r.agency_id = _agency_id
    ORDER BY r.route_sort_order NULLS LAST, r.route_short_name, r.route_id
    LIMIT _limit OFFSET _offset;
$$;

CREATE OR REPLACE FUNCTION get_route(_agency_id uuid, _route_id text)
RETURNS TABLE (
    route_id text,
    route_short_name text,
    route_long_name text,
    route_desc text,
    route_type integer,
    route_url text,
    route_color text,
    route_text_color text,
    route_sort_order integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT
        r.route_id,
        r.route_short_name,
        r.route_long_name,
        r.route_desc,
        r.route_type,
        r.route_url,
        r.route_color,
        r.route_text_color,
        r.route_sort_order
    FROM routes r
    WHERE r.agency_id = _agency_id AND r.route_id = _route_id;
$$;

CREATE OR REPLACE FUNCTION list_trips(
    _agency_id uuid,
    _route_id text,
    _service_id text,
    _limit integer,
    _offset integer
)
RETURNS TABLE (
    trip_id text,
    route_id text,
    service_id text,
    trip_headsign text,
    trip_short_name text,
    direction_id integer,
    block_id text,
    shape_id text,
    wheelchair_accessible integer,
    bikes_allowed integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT
        t.trip_id,
        t.route_id,
        t.service_id,
        t.trip_headsign,
        t.trip_short_name,
        t.direction_id,
        t.block_id,
        t.shape_id,
        t.wheelchair_accessible,
        t.bikes_allowed
    FROM trips t
    WHERE t.agency_id = _agency_id
      AND (_route_id IS NULL OR t.route_id = _route_id)
      AND (_service_id IS NULL OR t.service_id = _service_id)
    ORDER BY t.trip_id
    LIMIT _limit OFFSET _offset;
$$;

CREATE OR REPLACE FUNCTION get_trip(_agency_id uuid, _trip_id text)
RETURNS TABLE (
    trip_id text,
    route_id text,
    service_id text,
    trip_headsign text,
    trip_short_name text,
    direction_id integer,
    block_id text,
    shape_id text,
    wheelchair_accessible integer,
    bikes_allowed integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT
        t.trip_id,
        t.route_id,
        t.service_id,
        t.trip_headsign,
        t.trip_short_name,
        t.direction_id,
        t.block_id,
        t.shape_id,
        t.wheelchair_accessible,
        t.bikes_allowed
    FROM trips t
    WHERE t.agency_id = _agency_id AND t.trip_id = _trip_id;
$$;

CREATE OR REPLACE FUNCTION list_trip_stop_times(_agency_id uuid, _trip_id text)
RETURNS TABLE (
    stop_id text,
    arrival_time interval,
    departure_time interval,
    stop_sequence integer,
    stop_headsign text,
    pickup_type integer,
    drop_off_type integer,
    timepoint integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT
        st.stop_id,
        st.arrival_time,
        st.departure_time,
        st.stop_sequence,
        st.stop_headsign,
        st.pickup_type,
        st.drop_off_type,
        st.timepoint
    FROM stop_times st
    WHERE st.agency_id = _agency_id AND st.trip_id = _trip_id
    ORDER BY st.stop_sequence;
$$;

CREATE OR REPLACE FUNCTION list_arrivals(
    _agency_id uuid,
    _stop_id text,
    _route_id text,
    _service_date date,
    _limit integer,
    _offset integer
)
RETURNS TABLE (
    stop_id text,
    trip_id text,
    route_id text,
    route_short_name text,
    trip_headsign text,
    arrival_time interval,
    departure_time interval,
    stop_sequence integer,
    wheelchair_accessible integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT
        st.stop_id,
        t.trip_id,
        r.route_id,
        r.route_short_name,
        t.trip_headsign,
        st.arrival_time,
        st.departure_time,
        st.stop_sequence,
        t.wheelchair_accessible
    FROM stop_times st
    JOIN trips t ON t.agency_id = st.agency_id AND t.trip_id = st.trip_id
    JOIN routes r ON r.agency_id = st.agency_id AND r.route_id = t.route_id
    JOIN calendar c ON c.agency_id = st.agency_id AND c.service_id = t.service_id
    WHERE st.agency_id = _agency_id
      AND (_stop_id IS NULL OR st.stop_id = _stop_id)
      AND (_route_id IS NULL OR t.route_id = _route_id)
      AND (_service_date IS NULL OR
           (c.start_date <= _service_date AND c.end_date >= _service_date))
    ORDER BY st.arrival_time, st.stop_sequence
    LIMIT _limit OFFSET _offset;
$$;

-- ---------------------------------------------------------------------------
-- API-key lookup helper. Returns the agency_id and rate limit for a key hash.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION api_key_lookup(_key_hash text)
RETURNS TABLE (
    id uuid,
    agency_id uuid,
    scopes text[],
    rate_limit_rpm integer,
    quota_daily integer
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT id, agency_id, scopes, rate_limit_rpm, quota_daily
    FROM api_keys
    WHERE key_hash = _key_hash
    LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- Usage event insert helper.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION usage_event_insert(
    _api_key_id uuid,
    _endpoint text,
    _status integer,
    _latency_ms integer
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO usage_events (api_key_id, endpoint, status, latency_ms)
    VALUES (_api_key_id, _endpoint, _status, _latency_ms)
    RETURNING id;
$$;

-- ---------------------------------------------------------------------------
-- Count helpers for pagination.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION count_stops(_agency_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT count(*)::integer FROM stops WHERE agency_id = _agency_id;
$$;

CREATE OR REPLACE FUNCTION count_routes(_agency_id uuid)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT count(*)::integer FROM routes WHERE agency_id = _agency_id;
$$;

CREATE OR REPLACE FUNCTION count_trips(_agency_id uuid, _route_id text, _service_id text)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT count(*)::integer FROM trips
    WHERE agency_id = _agency_id
      AND (_route_id IS NULL OR route_id = _route_id)
      AND (_service_id IS NULL OR service_id = _service_id);
$$;

CREATE OR REPLACE FUNCTION count_arrivals(
    _agency_id uuid,
    _stop_id text,
    _route_id text,
    _service_date date
)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT count(*)::integer
    FROM stop_times st
    JOIN trips t ON t.agency_id = st.agency_id AND t.trip_id = st.trip_id
    JOIN routes r ON r.agency_id = st.agency_id AND r.route_id = t.route_id
    JOIN calendar c ON c.agency_id = st.agency_id AND c.service_id = t.service_id
    WHERE st.agency_id = _agency_id
      AND (_stop_id IS NULL OR st.stop_id = _stop_id)
      AND (_route_id IS NULL OR t.route_id = _route_id)
      AND (_service_date IS NULL OR
           (c.start_date <= _service_date AND c.end_date >= _service_date));
$$;

-- ---------------------------------------------------------------------------
-- Grants.
-- ---------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION get_agency_by_slug TO transit_app;
GRANT EXECUTE ON FUNCTION list_stops TO transit_app;
GRANT EXECUTE ON FUNCTION get_stop TO transit_app;
GRANT EXECUTE ON FUNCTION list_routes TO transit_app;
GRANT EXECUTE ON FUNCTION get_route TO transit_app;
GRANT EXECUTE ON FUNCTION list_trips TO transit_app;
GRANT EXECUTE ON FUNCTION get_trip TO transit_app;
GRANT EXECUTE ON FUNCTION list_trip_stop_times TO transit_app;
GRANT EXECUTE ON FUNCTION list_arrivals TO transit_app;
GRANT EXECUTE ON FUNCTION api_key_lookup TO transit_app;
GRANT EXECUTE ON FUNCTION usage_event_insert TO transit_app;
GRANT EXECUTE ON FUNCTION count_stops TO transit_app;
GRANT EXECUTE ON FUNCTION count_routes TO transit_app;
GRANT EXECUTE ON FUNCTION count_trips TO transit_app;
GRANT EXECUTE ON FUNCTION count_arrivals TO transit_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
