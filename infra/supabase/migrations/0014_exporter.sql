-- Migration 0014_exporter
-- Phase 10: read helpers for cmd/exporter's GTFS.zip generation. shapes.txt,
-- calendar_dates.txt and fare_products.txt never got a read path anywhere
-- else (the public API doesn't expose them) — this adds the minimum needed
-- to export them when an agency has data for them.

SET LOCAL search_path TO transit, public, extensions, auth;

CREATE OR REPLACE FUNCTION list_shapes(_agency_id uuid)
RETURNS TABLE (shape_id text, shape_pt_lat double precision, shape_pt_lon double precision, shape_pt_sequence integer, shape_dist_traveled double precision)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT shape_id, shape_pt_lat, shape_pt_lon, shape_pt_sequence, shape_dist_traveled
    FROM shapes
    WHERE agency_id = _agency_id
    ORDER BY shape_id, shape_pt_sequence;
$$;

CREATE OR REPLACE FUNCTION list_calendar_dates(_agency_id uuid)
RETURNS TABLE (service_id text, date date, exception_type integer)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT service_id, date, exception_type
    FROM calendar_dates
    WHERE agency_id = _agency_id
    ORDER BY service_id, date;
$$;

CREATE OR REPLACE FUNCTION list_fare_products(_agency_id uuid)
RETURNS TABLE (fare_product_id text, fare_product_name text, fare_media_id text, amount numeric, currency text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT fare_product_id, fare_product_name, fare_media_id, amount, currency
    FROM fare_products
    WHERE agency_id = _agency_id
    ORDER BY fare_product_id;
$$;

-- cmd/exporter iterates every agency on its own schedule — a platform-wide
-- background job, not a per-request agency-scoped read.
CREATE OR REPLACE FUNCTION list_agencies()
RETURNS TABLE (id uuid, slug text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT id, slug FROM agencies ORDER BY slug;
$$;

GRANT EXECUTE ON FUNCTION list_shapes TO transit_app;
GRANT EXECUTE ON FUNCTION list_calendar_dates TO transit_app;
GRANT EXECUTE ON FUNCTION list_fare_products TO transit_app;
GRANT EXECUTE ON FUNCTION list_agencies TO transit_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
