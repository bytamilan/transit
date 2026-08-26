-- Seed two demo agencies with small GTFS networks.
-- This script is idempotent: it removes existing seed data by slug before
-- inserting, so it can safely be re-run during local development.

SET search_path TO transit, public, extensions, auth;

-- ---------------------------------------------------------------------------
-- Agency A: Demo Metro (metric, SGD, Asia/Singapore)
-- ---------------------------------------------------------------------------
WITH agency_a AS (
    INSERT INTO agencies (slug, name, timezone, config)
    VALUES (
        'demo-metro',
        '{"en": "Demo Metro", "ta": "டெமோ மெட்ரோ", "zh": "示范地铁"}',
        'Asia/Singapore',
        '{
            "name": {"en": "Demo Metro", "ta": "டெமோ மெட்ரோ", "zh": "示范地铁"},
            "timezone": "Asia/Singapore",
            "locales": ["en", "ta", "zh"],
            "currency": "SGD",
            "distance_unit": "metric",
            "modes": ["bus", "rail"],
            "map_provider": "maplibre",
            "license": {
                "spdx": "CC-BY-4.0",
                "attribution": "Demo Metro — open data",
                "terms_url": "https://demo-metro.example/terms"
            },
            "branding": {
                "primary": "#1E40AF",
                "secondary": "#3B82F6",
                "logo_url": "https://demo-metro.example/logo.svg",
                "font": "Inter"
            },
            "driver_ops": {
                "stop_geofence_m": 40,
                "ping_interval_moving_s": 5,
                "ping_interval_idle_s": 60,
                "auto_start_trip": true,
                "lock_ui_above_kmh": 5
            }
        }'::jsonb
    )
    ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name,
        timezone = EXCLUDED.timezone,
        config = EXCLUDED.config,
        updated_at = now()
    RETURNING id
),
cal_a AS (
    INSERT INTO calendar (agency_id, service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date)
    SELECT id, 'weekday', true, true, true, true, true, false, false, '2026-01-01', '2026-12-31'
    FROM agency_a
    ON CONFLICT (agency_id, service_id) DO UPDATE SET
        monday = EXCLUDED.monday, tuesday = EXCLUDED.tuesday, wednesday = EXCLUDED.wednesday,
        thursday = EXCLUDED.thursday, friday = EXCLUDED.friday, saturday = EXCLUDED.saturday, sunday = EXCLUDED.sunday,
        start_date = EXCLUDED.start_date, end_date = EXCLUDED.end_date, updated_at = now()
    RETURNING agency_id, service_id
),
stops_a AS (
    INSERT INTO stops (agency_id, stop_id, stop_name, stop_lat, stop_lon, stop_loc, location_type)
    SELECT id, s.stop_id, s.stop_name, s.stop_lat, s.stop_lon,
           ST_SetSRID(ST_MakePoint(s.stop_lon, s.stop_lat), 4326)::geography,
           0
    FROM agency_a,
    (VALUES
        ('terminal_a', 'Terminal A', 1.2966, 103.7764),
        ('midtown_a',  'Midtown',    1.3000, 103.7800),
        ('airport_a',  'Airport',    1.3040, 103.7840)
    ) AS s(stop_id, stop_name, stop_lat, stop_lon)
    ON CONFLICT (agency_id, stop_id) DO UPDATE SET
        stop_name = EXCLUDED.stop_name,
        stop_lat = EXCLUDED.stop_lat,
        stop_lon = EXCLUDED.stop_lon,
        stop_loc = EXCLUDED.stop_loc,
        updated_at = now()
    RETURNING agency_id, stop_id
),
route_a AS (
    INSERT INTO routes (agency_id, route_id, route_short_name, route_long_name, route_type)
    SELECT id, 'a1', 'A1', 'Terminal A – Airport', 3
    FROM agency_a
    ON CONFLICT (agency_id, route_id) DO UPDATE SET
        route_short_name = EXCLUDED.route_short_name,
        route_long_name = EXCLUDED.route_long_name,
        route_type = EXCLUDED.route_type,
        updated_at = now()
    RETURNING agency_id, route_id
),
trip_a AS (
    INSERT INTO trips (agency_id, route_id, service_id, trip_id, trip_headsign, direction_id, block_id)
    SELECT r.agency_id, r.route_id, 'weekday', 'a1_0600', 'Airport', 0, 'blk_a_1'
    FROM route_a r
    ON CONFLICT (agency_id, trip_id) DO UPDATE SET
        route_id = EXCLUDED.route_id,
        service_id = EXCLUDED.service_id,
        trip_headsign = EXCLUDED.trip_headsign,
        direction_id = EXCLUDED.direction_id,
        block_id = EXCLUDED.block_id,
        updated_at = now()
    RETURNING agency_id, trip_id
)
INSERT INTO stop_times (agency_id, trip_id, stop_id, arrival_time, departure_time, stop_sequence)
SELECT t.agency_id, t.trip_id, s.stop_id,
       s.arrival::interval, s.departure::interval, s.seq
FROM trip_a t,
(VALUES
    ('terminal_a', '06:00:00', '06:02:00', 1),
    ('midtown_a',  '06:10:00', '06:12:00', 2),
    ('airport_a',  '06:25:00', '06:25:00', 3)
) AS s(stop_id, arrival, departure, seq)
ON CONFLICT (agency_id, trip_id, stop_sequence) DO UPDATE SET
    stop_id = EXCLUDED.stop_id,
    arrival_time = EXCLUDED.arrival_time,
    departure_time = EXCLUDED.departure_time,
    updated_at = now();

-- ---------------------------------------------------------------------------
-- Agency B: Demo Transit (imperial, USD, America/Los_Angeles)
-- ---------------------------------------------------------------------------
WITH agency_b AS (
    INSERT INTO agencies (slug, name, timezone, config)
    VALUES (
        'demo-transit',
        '{"en": "Demo Transit", "es": "Tránsito Demo"}',
        'America/Los_Angeles',
        '{
            "name": {"en": "Demo Transit", "es": "Tránsito Demo"},
            "timezone": "America/Los_Angeles",
            "locales": ["en", "es"],
            "currency": "USD",
            "distance_unit": "imperial",
            "modes": ["bus", "tram"],
            "map_provider": "protomaps",
            "license": {
                "spdx": "CC-BY-4.0",
                "attribution": "Demo Transit — open data",
                "terms_url": "https://demo-transit.example/terms"
            },
            "branding": {
                "primary": "#B45309",
                "secondary": "#F59E0B",
                "logo_url": "https://demo-transit.example/logo.svg",
                "font": "Roboto"
            },
            "driver_ops": {
                "stop_geofence_m": 150,
                "ping_interval_moving_s": 10,
                "ping_interval_idle_s": 120,
                "auto_start_trip": true,
                "lock_ui_above_kmh": 5
            }
        }'::jsonb
    )
    ON CONFLICT (slug) DO UPDATE SET
        name = EXCLUDED.name,
        timezone = EXCLUDED.timezone,
        config = EXCLUDED.config,
        updated_at = now()
    RETURNING id
),
cal_b AS (
    INSERT INTO calendar (agency_id, service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date)
    SELECT id, 'weekday', true, true, true, true, true, false, false, '2026-01-01', '2026-12-31'
    FROM agency_b
    ON CONFLICT (agency_id, service_id) DO UPDATE SET
        monday = EXCLUDED.monday, tuesday = EXCLUDED.tuesday, wednesday = EXCLUDED.wednesday,
        thursday = EXCLUDED.thursday, friday = EXCLUDED.friday, saturday = EXCLUDED.saturday, sunday = EXCLUDED.sunday,
        start_date = EXCLUDED.start_date, end_date = EXCLUDED.end_date, updated_at = now()
    RETURNING agency_id, service_id
),
stops_b AS (
    INSERT INTO stops (agency_id, stop_id, stop_name, stop_lat, stop_lon, stop_loc, location_type)
    SELECT id, s.stop_id, s.stop_name, s.stop_lat, s.stop_lon,
           ST_SetSRID(ST_MakePoint(s.stop_lon, s.stop_lat), 4326)::geography,
           0
    FROM agency_b,
    (VALUES
        ('downtown_b', 'Downtown',   34.0522, -118.2437),
        ('eastside_b', 'Eastside',   34.0407, -118.2468),
        ('westend_b',  'West End',   34.0689, -118.2451)
    ) AS s(stop_id, stop_name, stop_lat, stop_lon)
    ON CONFLICT (agency_id, stop_id) DO UPDATE SET
        stop_name = EXCLUDED.stop_name,
        stop_lat = EXCLUDED.stop_lat,
        stop_lon = EXCLUDED.stop_lon,
        stop_loc = EXCLUDED.stop_loc,
        updated_at = now()
    RETURNING agency_id, stop_id
),
route_b AS (
    INSERT INTO routes (agency_id, route_id, route_short_name, route_long_name, route_type)
    SELECT id, 'b10', 'B10', 'Downtown – West End', 3
    FROM agency_b
    ON CONFLICT (agency_id, route_id) DO UPDATE SET
        route_short_name = EXCLUDED.route_short_name,
        route_long_name = EXCLUDED.route_long_name,
        route_type = EXCLUDED.route_type,
        updated_at = now()
    RETURNING agency_id, route_id
),
trip_b AS (
    INSERT INTO trips (agency_id, route_id, service_id, trip_id, trip_headsign, direction_id, block_id)
    SELECT r.agency_id, r.route_id, 'weekday', 'b10_0700', 'West End', 0, 'blk_b_1'
    FROM route_b r
    ON CONFLICT (agency_id, trip_id) DO UPDATE SET
        route_id = EXCLUDED.route_id,
        service_id = EXCLUDED.service_id,
        trip_headsign = EXCLUDED.trip_headsign,
        direction_id = EXCLUDED.direction_id,
        block_id = EXCLUDED.block_id,
        updated_at = now()
    RETURNING agency_id, trip_id
)
INSERT INTO stop_times (agency_id, trip_id, stop_id, arrival_time, departure_time, stop_sequence)
SELECT t.agency_id, t.trip_id, s.stop_id,
       s.arrival::interval, s.departure::interval, s.seq
FROM trip_b t,
(VALUES
    ('downtown_b', '07:00:00', '07:02:00', 1),
    ('eastside_b', '07:12:00', '07:14:00', 2),
    ('westend_b',  '07:30:00', '07:30:00', 3)
) AS s(stop_id, arrival, departure, seq)
ON CONFLICT (agency_id, trip_id, stop_sequence) DO UPDATE SET
    stop_id = EXCLUDED.stop_id,
    arrival_time = EXCLUDED.arrival_time,
    departure_time = EXCLUDED.departure_time,
    updated_at = now();
