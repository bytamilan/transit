-- Migration 0003_gtfs_core
-- Canonical GTFS tables, all scoped by agency_id.
--
-- Notes:
--   * Every table carries agency_id and is part of a composite primary key or
--     has a unique natural-key constraint scoped by agency_id.
--   * All "timestamp" columns use timestamptz.
--   * stop_times.arrival_time/departure_time use interval so after-midnight
--     values like "25:30:00" are preserved exactly. Conversion to a wall-clock
--     time in the agency's timezone is done by application code.
--   * Geography columns use PostGIS geography(POINT,4326).
--   * RLS policies are added at the end of this file.

SET LOCAL search_path TO transit, public, extensions, auth;

-- ---------------------------------------------------------------------------
-- Service calendars
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS calendar (
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    service_id text NOT NULL,
    monday boolean NOT NULL,
    tuesday boolean NOT NULL,
    wednesday boolean NOT NULL,
    thursday boolean NOT NULL,
    friday boolean NOT NULL,
    saturday boolean NOT NULL,
    sunday boolean NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (agency_id, service_id)
);

CREATE INDEX IF NOT EXISTS idx_calendar_service_date
    ON calendar (agency_id, service_id, start_date, end_date);

-- ---------------------------------------------------------------------------
-- Calendar exceptions. We do NOT enforce a foreign key to calendar because
-- GTFS allows service_id values that exist only in calendar_dates.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS calendar_dates (
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    service_id text NOT NULL,
    date date NOT NULL,
    exception_type integer NOT NULL CHECK (exception_type IN (1, 2)),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (agency_id, service_id, date)
);

CREATE INDEX IF NOT EXISTS idx_calendar_dates_service
    ON calendar_dates (agency_id, service_id);
CREATE INDEX IF NOT EXISTS idx_calendar_dates_date
    ON calendar_dates (agency_id, date);

-- ---------------------------------------------------------------------------
-- Stops
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stops (
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    stop_id text NOT NULL,
    stop_code text,
    stop_name text NOT NULL,
    stop_desc text,
    stop_lat double precision,
    stop_lon double precision,
    stop_loc geography(POINT,4326),
    zone_id text,
    stop_url text,
    location_type integer DEFAULT 0 CHECK (location_type IN (0, 1, 2, 3, 4)),
    parent_station text,
    stop_timezone text,
    wheelchair_boarding integer CHECK (wheelchair_boarding IN (0, 1, 2)),
    level_id text,
    platform_code text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (agency_id, stop_id)
);

CREATE INDEX IF NOT EXISTS idx_stops_name
    ON stops (agency_id, stop_name);
CREATE INDEX IF NOT EXISTS idx_stops_loc
    ON stops USING GIST (stop_loc);

-- ---------------------------------------------------------------------------
-- Shapes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS shapes (
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    shape_id text NOT NULL,
    shape_pt_sequence integer NOT NULL,
    shape_pt_lat double precision NOT NULL,
    shape_pt_lon double precision NOT NULL,
    shape_pt_loc geography(POINT,4326),
    shape_dist_traveled double precision,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (agency_id, shape_id, shape_pt_sequence)
);

CREATE INDEX IF NOT EXISTS idx_shapes_loc
    ON shapes USING GIST (shape_pt_loc);
CREATE INDEX IF NOT EXISTS idx_shapes_id_seq
    ON shapes (agency_id, shape_id, shape_pt_sequence);

-- ---------------------------------------------------------------------------
-- Routes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS routes (
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    route_id text NOT NULL,
    agency_id_text text, -- GTFS agency_id field; optional when one agency per feed.
    route_short_name text,
    route_long_name text,
    route_desc text,
    route_type integer NOT NULL,
    route_url text,
    route_color text,
    route_text_color text,
    route_sort_order integer,
    continuous_pickup integer CHECK (continuous_pickup IN (0, 1, 2, 3)),
    continuous_drop_off integer CHECK (continuous_drop_off IN (0, 1, 2, 3)),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (agency_id, route_id)
);

CREATE INDEX IF NOT EXISTS idx_routes_short_name
    ON routes (agency_id, route_short_name);
CREATE INDEX IF NOT EXISTS idx_routes_type
    ON routes (agency_id, route_type);

-- ---------------------------------------------------------------------------
-- Trips
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS trips (
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    route_id text NOT NULL,
    service_id text NOT NULL,
    trip_id text NOT NULL,
    trip_headsign text,
    trip_short_name text,
    direction_id integer CHECK (direction_id IN (0, 1)),
    block_id text,
    shape_id text,
    wheelchair_accessible integer CHECK (wheelchair_accessible IN (0, 1, 2)),
    bikes_allowed integer CHECK (bikes_allowed IN (0, 1, 2)),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (agency_id, trip_id),
    FOREIGN KEY (agency_id, route_id) REFERENCES routes(agency_id, route_id) ON DELETE CASCADE,
    FOREIGN KEY (agency_id, service_id) REFERENCES calendar(agency_id, service_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_trips_route_service
    ON trips (agency_id, route_id, service_id);
CREATE INDEX IF NOT EXISTS idx_trips_block
    ON trips (agency_id, block_id);
CREATE INDEX IF NOT EXISTS idx_trips_shape
    ON trips (agency_id, shape_id);

-- ---------------------------------------------------------------------------
-- Stop times
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stop_times (
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    trip_id text NOT NULL,
    stop_id text NOT NULL,
    arrival_time interval,
    departure_time interval,
    stop_sequence integer NOT NULL,
    stop_headsign text,
    pickup_type integer CHECK (pickup_type IN (0, 1, 2, 3)),
    drop_off_type integer CHECK (drop_off_type IN (0, 1, 2, 3)),
    continuous_pickup integer CHECK (continuous_pickup IN (0, 1, 2, 3)),
    continuous_drop_off integer CHECK (continuous_drop_off IN (0, 1, 2, 3)),
    shape_dist_traveled double precision,
    timepoint integer CHECK (timepoint IN (0, 1)),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (agency_id, trip_id, stop_sequence),
    FOREIGN KEY (agency_id, trip_id) REFERENCES trips(agency_id, trip_id) ON DELETE CASCADE,
    FOREIGN KEY (agency_id, stop_id) REFERENCES stops(agency_id, stop_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_stop_times_trip_seq
    ON stop_times (agency_id, trip_id, stop_sequence);
CREATE INDEX IF NOT EXISTS idx_stop_times_stop
    ON stop_times (agency_id, stop_id);
CREATE INDEX IF NOT EXISTS idx_stop_times_arrival
    ON stop_times (agency_id, trip_id, arrival_time);

-- ---------------------------------------------------------------------------
-- Fare products
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fare_products (
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    fare_product_id text NOT NULL,
    fare_product_name text NOT NULL,
    fare_media_id text,
    amount numeric(10,2) NOT NULL,
    currency text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (agency_id, fare_product_id)
);

CREATE INDEX IF NOT EXISTS idx_fare_products_currency
    ON fare_products (agency_id, currency);

-- ---------------------------------------------------------------------------
-- RLS helpers for GTFS tables.
-- Every GTFS table is read/write-scoped to the current_agency_id() claim.
-- ---------------------------------------------------------------------------

-- Helper to apply a common read policy to all GTFS tables.
CREATE OR REPLACE FUNCTION gtfs_read_policy(agency_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    RETURN agency_uuid = current_agency_id();
END;
$$;

-- Helper to apply a common write policy to all GTFS tables.
CREATE OR REPLACE FUNCTION gtfs_write_policy(agency_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    RETURN current_user_role() = 'agency_admin'
       AND agency_uuid = current_agency_id();
END;
$$;

-- Enable RLS and create policies for each canonical GTFS table.
DO $$
DECLARE
    tbl text;
BEGIN
    FOR tbl IN
        SELECT unnest(ARRAY[
            'calendar', 'calendar_dates', 'stops', 'shapes',
            'routes', 'trips', 'stop_times', 'fare_products'
        ])
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', tbl);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', tbl);

        EXECUTE format(
            'DROP POLICY IF EXISTS %I_select_own ON %I',
            tbl, tbl
        );
        EXECUTE format(
            'CREATE POLICY %I_select_own ON %I FOR SELECT USING (gtfs_read_policy(agency_id))',
            tbl, tbl
        );

        EXECUTE format(
            'DROP POLICY IF EXISTS %I_write_own ON %I',
            tbl, tbl
        );
        EXECUTE format(
            'CREATE POLICY %I_write_own ON %I FOR ALL TO PUBLIC USING (gtfs_write_policy(agency_id)) WITH CHECK (gtfs_write_policy(agency_id))',
            tbl, tbl
        );
    END LOOP;
END;
$$;
