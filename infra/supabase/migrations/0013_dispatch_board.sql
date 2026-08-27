-- Migration 0013_dispatch_board
-- Phase 9: the live dispatch board. Adds off_route tracking onto
-- vehicle_trips, driver<->dispatcher messages, and incident resolution —
-- everything /admin/dispatch and /admin/incidents need beyond what Phases
-- 6/8 already built (reassignment/handover, vehicle_trips, stop_events).

SET LOCAL search_path TO transit, public, extensions, auth;

ALTER TABLE vehicle_trips ADD COLUMN IF NOT EXISTS off_route boolean NOT NULL DEFAULT false;

-- ---------------------------------------------------------------------------
-- Dispatcher <-> driver messages. Polled, not pushed (no FCM/APNs plumbing
-- in this codebase yet) — the driver app checks alongside its existing ping
-- flush tick. See docs/PHASE_PLAN.md Phase 9 for that scope note.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dispatch_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    assignment_id uuid NOT NULL REFERENCES duty_assignments(id) ON DELETE CASCADE,
    sender_id uuid NOT NULL,
    body text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    read_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_dispatch_messages_assignment ON dispatch_messages (assignment_id, created_at);

ALTER TABLE dispatch_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispatch_messages FORCE ROW LEVEL SECURITY;

CREATE POLICY dispatch_messages_select ON dispatch_messages FOR SELECT USING (
    current_user_role() = 'super_admin' OR (
        current_agency_id() = agency_id AND (
            current_user_role() IN ('agency_admin', 'fleet_manager', 'dispatcher')
            OR EXISTS (SELECT 1 FROM duty_assignments da WHERE da.id = dispatch_messages.assignment_id AND da.driver_id = current_user_id())
        )
    )
);
CREATE POLICY dispatch_messages_insert ON dispatch_messages FOR INSERT WITH CHECK (
    current_user_role() = 'super_admin' OR (
        current_agency_id() = agency_id AND current_user_role() IN ('agency_admin', 'fleet_manager', 'dispatcher')
    )
);
CREATE POLICY dispatch_messages_update_read ON dispatch_messages FOR UPDATE USING (
    current_agency_id() = agency_id AND EXISTS (
        SELECT 1 FROM duty_assignments da WHERE da.id = dispatch_messages.assignment_id AND da.driver_id = current_user_id()
    )
);

-- ---------------------------------------------------------------------------
-- Go-facing helpers.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_vehicle_trip_off_route(_agency_id uuid, _vehicle_trip_id uuid, _off_route boolean)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    UPDATE vehicle_trips SET off_route = _off_route, updated_at = now()
    WHERE agency_id = _agency_id AND id = _vehicle_trip_id;
$$;

CREATE OR REPLACE FUNCTION send_dispatch_message(_agency_id uuid, _assignment_id uuid, _sender_id uuid, _body text)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO dispatch_messages (agency_id, assignment_id, sender_id, body)
    VALUES (_agency_id, _assignment_id, _sender_id, _body)
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION list_dispatch_messages(_agency_id uuid, _assignment_id uuid, _unread_only boolean)
RETURNS TABLE (id uuid, sender_id uuid, body text, created_at timestamptz, read_at timestamptz)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT m.id, m.sender_id, m.body, m.created_at, m.read_at
    FROM dispatch_messages m
    WHERE m.agency_id = _agency_id AND m.assignment_id = _assignment_id
      AND (NOT _unread_only OR m.read_at IS NULL)
    ORDER BY m.created_at;
$$;

CREATE OR REPLACE FUNCTION mark_dispatch_messages_read(_agency_id uuid, _assignment_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    UPDATE dispatch_messages SET read_at = now()
    WHERE agency_id = _agency_id AND assignment_id = _assignment_id AND read_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION list_incidents(_agency_id uuid, _open_only boolean)
RETURNS TABLE (
    id uuid, assignment_id uuid, kind text, note text,
    lat double precision, lon double precision, ts timestamptz, resolved_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT ir.id, ir.assignment_id, ir.kind, ir.note,
           ST_Y(ir.geog::geometry), ST_X(ir.geog::geometry), ir.ts, ir.resolved_at
    FROM incident_reports ir
    WHERE ir.agency_id = _agency_id AND (NOT _open_only OR ir.resolved_at IS NULL)
    ORDER BY ir.ts DESC;
$$;

CREATE OR REPLACE FUNCTION resolve_incident(_agency_id uuid, _id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    UPDATE incident_reports SET resolved_at = now()
    WHERE agency_id = _agency_id AND id = _id;
$$;

-- current_vehicle_positions gains off_route (0012 created it without the
-- column this migration adds) — CREATE OR REPLACE can't add a column to an
-- existing RETURNS TABLE signature, so the function is dropped and redefined.
DROP FUNCTION IF EXISTS current_vehicle_positions(uuid);

CREATE FUNCTION current_vehicle_positions(_agency_id uuid)
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
    last_delay_s integer,
    off_route boolean
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
        lse.stop_sequence, lse.arrived_at, lse.departed_at, lse.delay_s,
        vt.off_route
    FROM vehicle_trips vt
    JOIN duty_assignments da ON da.id = vt.assignment_id
    JOIN latest_ping lp ON lp.assignment_id = vt.assignment_id
    LEFT JOIN latest_stop_event lse ON lse.vehicle_trip_id = vt.id
    WHERE vt.agency_id = _agency_id AND vt.status = 'in_progress';
$$;

GRANT EXECUTE ON FUNCTION set_vehicle_trip_off_route TO transit_app;
GRANT EXECUTE ON FUNCTION send_dispatch_message TO transit_app;
GRANT EXECUTE ON FUNCTION list_dispatch_messages TO transit_app;
GRANT EXECUTE ON FUNCTION mark_dispatch_messages_read TO transit_app;
GRANT EXECUTE ON FUNCTION list_incidents TO transit_app;
GRANT EXECUTE ON FUNCTION resolve_incident TO transit_app;
GRANT EXECUTE ON FUNCTION current_vehicle_positions TO transit_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
