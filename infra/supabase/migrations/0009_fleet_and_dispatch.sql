-- Migration 0009_fleet_and_dispatch
-- Phase 6: admin console data model. depots and driver_profiles already exist
-- (0004_roles_and_audit); this migration adds vehicles, blocks, duty
-- assignment/handover tracking, plus the SECURITY DEFINER helper functions
-- the Go admin API calls (the Go layer enforces RBAC; these functions filter
-- explicitly by agency_id the same way the Phase 4 read helpers do).

SET LOCAL search_path TO transit, public, extensions, auth;

-- ---------------------------------------------------------------------------
-- Driver profile additions: identity fields captured at invite time. We do
-- not join auth.users for these — the API already knows them when it calls
-- GoTrue's admin invite endpoint, so we store our own copy.
-- ---------------------------------------------------------------------------
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS display_name text;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS invite_email text;
ALTER TABLE driver_profiles ADD COLUMN IF NOT EXISTS invite_phone text;

-- ---------------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vehicles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    depot_id uuid REFERENCES depots(id) ON DELETE SET NULL,
    fleet_no text NOT NULL,
    registration text NOT NULL,
    capacity_class text,
    accessibility jsonb NOT NULL DEFAULT '{}'::jsonb,
    propulsion text,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'out_of_service', 'retired')),
    maintenance_hold boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (agency_id, fleet_no)
);

CREATE INDEX IF NOT EXISTS idx_vehicles_agency ON vehicles (agency_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_depot ON vehicles (agency_id, depot_id);
CREATE INDEX IF NOT EXISTS idx_vehicles_status ON vehicles (agency_id, status);

-- ---------------------------------------------------------------------------
-- Blocks: a GTFS block_id realised for one service date, with the ordered
-- trip_ids that make it up. block_ref matches trips.block_id.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS blocks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    block_ref text NOT NULL,
    service_date date NOT NULL,
    trip_ids text[] NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (agency_id, block_ref, service_date)
);

CREATE INDEX IF NOT EXISTS idx_blocks_agency_date ON blocks (agency_id, service_date);

-- ---------------------------------------------------------------------------
-- Duty assignments: driver + vehicle assigned to a block for a service date.
-- Only one *live* (non-terminal) assignment may exist per block/date; a
-- handover ends the old row (status -> completed) and inserts a new one
-- linked via handover_from_id, so history is never overwritten.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS duty_assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    block_id uuid NOT NULL REFERENCES blocks(id) ON DELETE CASCADE,
    driver_id uuid NOT NULL REFERENCES driver_profiles(user_id) ON DELETE CASCADE,
    vehicle_id uuid NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    service_date date NOT NULL,
    status text NOT NULL DEFAULT 'scheduled'
        CHECK (status IN ('scheduled', 'signed_on', 'in_progress', 'completed', 'cancelled')),
    assigned_by uuid NOT NULL,
    handover_from_id uuid REFERENCES duty_assignments(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

-- Only one live assignment per block per service date at a time.
CREATE UNIQUE INDEX IF NOT EXISTS uq_duty_assignments_live_block
    ON duty_assignments (agency_id, block_id, service_date)
    WHERE status IN ('scheduled', 'signed_on', 'in_progress');

CREATE INDEX IF NOT EXISTS idx_duty_assignments_driver_date
    ON duty_assignments (agency_id, driver_id, service_date);
CREATE INDEX IF NOT EXISTS idx_duty_assignments_vehicle_date
    ON duty_assignments (agency_id, vehicle_id, service_date);
CREATE INDEX IF NOT EXISTS idx_duty_assignments_block_date
    ON duty_assignments (agency_id, block_id, service_date);

-- ---------------------------------------------------------------------------
-- Duty events: append-style log of what happened to an assignment.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS duty_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    assignment_id uuid NOT NULL REFERENCES duty_assignments(id) ON DELETE CASCADE,
    kind text NOT NULL CHECK (kind IN ('signed_on', 'reassigned', 'handover', 'ended', 'cancelled')),
    ts timestamptz NOT NULL DEFAULT now(),
    actor uuid NOT NULL,
    note text
);

CREATE INDEX IF NOT EXISTS idx_duty_events_assignment ON duty_events (assignment_id, ts);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles FORCE ROW LEVEL SECURITY;
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocks FORCE ROW LEVEL SECURITY;
ALTER TABLE duty_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE duty_assignments FORCE ROW LEVEL SECURITY;
ALTER TABLE duty_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE duty_events FORCE ROW LEVEL SECURITY;

-- Write helper: fleet_manager and above may write fleet/roster data.
CREATE OR REPLACE FUNCTION fleet_write_policy(agency_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    RETURN current_user_role() = 'super_admin'
        OR (current_user_role() IN ('agency_admin', 'fleet_manager') AND current_agency_id() = agency_uuid);
END;
$$;

-- Write helper: dispatchers may additionally act on duty assignments/events
-- (reassignment, handover) but not on vehicles/blocks directly.
CREATE OR REPLACE FUNCTION dispatch_write_policy(agency_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    RETURN fleet_write_policy(agency_uuid)
        OR (current_user_role() = 'dispatcher' AND current_agency_id() = agency_uuid);
END;
$$;

-- Read helper for duty assignments/events: depot-scoped via the assigned
-- driver's depot, and a driver may only see their own duties.
CREATE OR REPLACE FUNCTION duty_visible(agency_uuid uuid, driver_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    IF current_user_role() = 'super_admin' THEN
        RETURN true;
    END IF;
    IF current_agency_id() IS NULL OR current_agency_id() <> agency_uuid THEN
        RETURN false;
    END IF;
    IF current_user_role() = 'driver' THEN
        RETURN driver_uuid = current_user_id();
    END IF;
    IF current_user_role() = 'dispatcher' THEN
        RETURN (current_setting('request.jwt.claims', true)::jsonb->>'depot_id') IS NULL
            OR ((current_setting('request.jwt.claims', true)::jsonb->>'depot_id')::uuid =
                (SELECT depot_id FROM driver_profiles WHERE user_id = driver_uuid));
    END IF;
    RETURN current_user_role() IN ('agency_admin', 'fleet_manager');
END;
$$;

CREATE POLICY vehicles_select_own ON vehicles FOR SELECT USING (own_or_dept_scoped(agency_id, depot_id));
CREATE POLICY vehicles_write_own ON vehicles FOR ALL
    USING (fleet_write_policy(agency_id)) WITH CHECK (fleet_write_policy(agency_id));

CREATE POLICY blocks_select_own ON blocks FOR SELECT USING (
    current_user_role() = 'super_admin' OR current_agency_id() = agency_id
);
CREATE POLICY blocks_write_own ON blocks FOR ALL
    USING (fleet_write_policy(agency_id)) WITH CHECK (fleet_write_policy(agency_id));

CREATE POLICY duty_assignments_select_own ON duty_assignments FOR SELECT USING (duty_visible(agency_id, driver_id));
CREATE POLICY duty_assignments_write_own ON duty_assignments FOR ALL
    USING (dispatch_write_policy(agency_id)) WITH CHECK (dispatch_write_policy(agency_id));

CREATE POLICY duty_events_select_own ON duty_events FOR SELECT USING (
    current_user_role() = 'super_admin' OR (
        current_agency_id() = agency_id AND EXISTS (
            SELECT 1 FROM duty_assignments da
            WHERE da.id = duty_events.assignment_id AND duty_visible(da.agency_id, da.driver_id)
        )
    )
);
CREATE POLICY duty_events_write_own ON duty_events FOR ALL
    USING (dispatch_write_policy(agency_id)) WITH CHECK (dispatch_write_policy(agency_id));

-- ---------------------------------------------------------------------------
-- SECURITY DEFINER helpers for the Go admin API (transit_app). RBAC and
-- agency scoping are enforced in Go before these are called; every function
-- still takes an explicit _agency_id to keep tenancy impossible to bypass by
-- omission.
-- ---------------------------------------------------------------------------

-- Vehicles ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION upsert_vehicle(
    _agency_id uuid,
    _fleet_no text,
    _registration text,
    _depot_id uuid,
    _capacity_class text,
    _accessibility jsonb,
    _propulsion text,
    _status text,
    _maintenance_hold boolean
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO vehicles (agency_id, fleet_no, registration, depot_id, capacity_class,
                           accessibility, propulsion, status, maintenance_hold)
    VALUES (_agency_id, _fleet_no, _registration, _depot_id, _capacity_class,
            COALESCE(_accessibility, '{}'::jsonb), _propulsion,
            COALESCE(_status, 'active'), COALESCE(_maintenance_hold, false))
    ON CONFLICT (agency_id, fleet_no) DO UPDATE SET
        registration = EXCLUDED.registration,
        depot_id = EXCLUDED.depot_id,
        capacity_class = EXCLUDED.capacity_class,
        accessibility = EXCLUDED.accessibility,
        propulsion = EXCLUDED.propulsion,
        status = EXCLUDED.status,
        maintenance_hold = EXCLUDED.maintenance_hold,
        updated_at = now()
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION list_vehicles(_agency_id uuid, _depot_id uuid, _status text, _limit integer, _offset integer)
RETURNS TABLE (
    id uuid, depot_id uuid, fleet_no text, registration text, capacity_class text,
    accessibility jsonb, propulsion text, status text, maintenance_hold boolean,
    created_at timestamptz, updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT v.id, v.depot_id, v.fleet_no, v.registration, v.capacity_class,
           v.accessibility, v.propulsion, v.status, v.maintenance_hold,
           v.created_at, v.updated_at
    FROM vehicles v
    WHERE v.agency_id = _agency_id
      AND (_depot_id IS NULL OR v.depot_id = _depot_id)
      AND (_status IS NULL OR v.status = _status)
    ORDER BY v.fleet_no
    LIMIT _limit OFFSET _offset;
$$;

CREATE OR REPLACE FUNCTION get_vehicle(_agency_id uuid, _id uuid)
RETURNS TABLE (
    id uuid, depot_id uuid, fleet_no text, registration text, capacity_class text,
    accessibility jsonb, propulsion text, status text, maintenance_hold boolean,
    created_at timestamptz, updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT v.id, v.depot_id, v.fleet_no, v.registration, v.capacity_class,
           v.accessibility, v.propulsion, v.status, v.maintenance_hold,
           v.created_at, v.updated_at
    FROM vehicles v
    WHERE v.agency_id = _agency_id AND v.id = _id;
$$;

CREATE OR REPLACE FUNCTION delete_vehicle(_agency_id uuid, _id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    DELETE FROM vehicles WHERE agency_id = _agency_id AND id = _id;
$$;

CREATE OR REPLACE FUNCTION count_vehicles(_agency_id uuid, _depot_id uuid, _status text)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT count(*)::integer FROM vehicles
    WHERE agency_id = _agency_id
      AND (_depot_id IS NULL OR depot_id = _depot_id)
      AND (_status IS NULL OR status = _status);
$$;

-- Driver profiles ----------------------------------------------------------

CREATE OR REPLACE FUNCTION upsert_driver_profile(
    _agency_id uuid,
    _user_id uuid,
    _depot_id uuid,
    _display_name text,
    _invite_email text,
    _invite_phone text,
    _licence_ref_hash text,
    _licence_expires_on date,
    _status text
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO driver_profiles (user_id, agency_id, depot_id, display_name, invite_email,
                                  invite_phone, licence_ref_hash, licence_expires_on, status)
    VALUES (_user_id, _agency_id, _depot_id, _display_name, _invite_email,
            _invite_phone, _licence_ref_hash, _licence_expires_on, COALESCE(_status, 'active'))
    ON CONFLICT (user_id) DO UPDATE SET
        depot_id = EXCLUDED.depot_id,
        display_name = EXCLUDED.display_name,
        invite_email = EXCLUDED.invite_email,
        invite_phone = EXCLUDED.invite_phone,
        licence_ref_hash = EXCLUDED.licence_ref_hash,
        licence_expires_on = EXCLUDED.licence_expires_on,
        status = EXCLUDED.status,
        updated_at = now()
    RETURNING user_id;
$$;

CREATE OR REPLACE FUNCTION list_driver_profiles(_agency_id uuid, _depot_id uuid, _status text, _limit integer, _offset integer)
RETURNS TABLE (
    user_id uuid, depot_id uuid, display_name text, invite_email text, invite_phone text,
    licence_ref_hash text, licence_expires_on date, status text,
    created_at timestamptz, updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT d.user_id, d.depot_id, d.display_name, d.invite_email, d.invite_phone,
           d.licence_ref_hash, d.licence_expires_on, d.status, d.created_at, d.updated_at
    FROM driver_profiles d
    WHERE d.agency_id = _agency_id
      AND (_depot_id IS NULL OR d.depot_id = _depot_id)
      AND (_status IS NULL OR d.status = _status)
    ORDER BY d.display_name NULLS LAST, d.user_id
    LIMIT _limit OFFSET _offset;
$$;

CREATE OR REPLACE FUNCTION get_driver_profile(_agency_id uuid, _user_id uuid)
RETURNS TABLE (
    user_id uuid, depot_id uuid, display_name text, invite_email text, invite_phone text,
    licence_ref_hash text, licence_expires_on date, status text,
    created_at timestamptz, updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT d.user_id, d.depot_id, d.display_name, d.invite_email, d.invite_phone,
           d.licence_ref_hash, d.licence_expires_on, d.status, d.created_at, d.updated_at
    FROM driver_profiles d
    WHERE d.agency_id = _agency_id AND d.user_id = _user_id;
$$;

CREATE OR REPLACE FUNCTION count_driver_profiles(_agency_id uuid, _depot_id uuid, _status text)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT count(*)::integer FROM driver_profiles
    WHERE agency_id = _agency_id
      AND (_depot_id IS NULL OR depot_id = _depot_id)
      AND (_status IS NULL OR status = _status);
$$;

CREATE OR REPLACE FUNCTION insert_user_role(_user_id uuid, _agency_id uuid, _role text, _depot_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO user_roles (user_id, agency_id, role, depot_id)
    VALUES (_user_id, _agency_id, _role, _depot_id)
    ON CONFLICT (user_id, agency_id, role) DO UPDATE SET depot_id = EXCLUDED.depot_id;
$$;

-- Blocks ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION upsert_block(_agency_id uuid, _block_ref text, _service_date date, _trip_ids text[])
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO blocks (agency_id, block_ref, service_date, trip_ids)
    VALUES (_agency_id, _block_ref, _service_date, COALESCE(_trip_ids, '{}'))
    ON CONFLICT (agency_id, block_ref, service_date) DO UPDATE SET
        trip_ids = EXCLUDED.trip_ids,
        updated_at = now()
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION list_blocks(_agency_id uuid, _service_date date, _limit integer, _offset integer)
RETURNS TABLE (id uuid, block_ref text, service_date date, trip_ids text[], created_at timestamptz, updated_at timestamptz)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT b.id, b.block_ref, b.service_date, b.trip_ids, b.created_at, b.updated_at
    FROM blocks b
    WHERE b.agency_id = _agency_id
      AND (_service_date IS NULL OR b.service_date = _service_date)
    ORDER BY b.service_date, b.block_ref
    LIMIT _limit OFFSET _offset;
$$;

CREATE OR REPLACE FUNCTION get_block(_agency_id uuid, _id uuid)
RETURNS TABLE (id uuid, block_ref text, service_date date, trip_ids text[], created_at timestamptz, updated_at timestamptz)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT b.id, b.block_ref, b.service_date, b.trip_ids, b.created_at, b.updated_at
    FROM blocks b
    WHERE b.agency_id = _agency_id AND b.id = _id;
$$;

CREATE OR REPLACE FUNCTION count_blocks(_agency_id uuid, _service_date date)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT count(*)::integer FROM blocks
    WHERE agency_id = _agency_id AND (_service_date IS NULL OR service_date = _service_date);
$$;

CREATE OR REPLACE FUNCTION list_unassigned_blocks(_agency_id uuid, _service_date date)
RETURNS TABLE (id uuid, block_ref text, service_date date, trip_ids text[])
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT b.id, b.block_ref, b.service_date, b.trip_ids
    FROM blocks b
    WHERE b.agency_id = _agency_id
      AND b.service_date = _service_date
      AND NOT EXISTS (
          SELECT 1 FROM duty_assignments da
          WHERE da.block_id = b.id
            AND da.service_date = b.service_date
            AND da.status IN ('scheduled', 'signed_on', 'in_progress')
      )
    ORDER BY b.block_ref;
$$;

-- Computes a block's scheduled start/end instants from its trips' stop_times,
-- localised to the agency's IANA timezone per ADR 0002 (noon-minus-12 origin,
-- so after-midnight intervals like 25:30:00 land on the next calendar day).
CREATE OR REPLACE FUNCTION block_time_span(_agency_id uuid, _block_id uuid)
RETURNS TABLE (starts_at timestamptz, ends_at timestamptz)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
DECLARE
    tz text;
    svc_date date;
    start_iv interval;
    end_iv interval;
    origin timestamptz;
BEGIN
    SELECT a.timezone INTO tz FROM agencies a WHERE a.id = _agency_id;
    SELECT b.service_date INTO svc_date FROM blocks b WHERE b.id = _block_id AND b.agency_id = _agency_id;
    IF tz IS NULL OR svc_date IS NULL THEN
        RETURN;
    END IF;

    SELECT min(st.departure_time), max(st.arrival_time)
      INTO start_iv, end_iv
      FROM blocks b
      JOIN stop_times st ON st.agency_id = b.agency_id AND st.trip_id = ANY(b.trip_ids)
      WHERE b.id = _block_id AND b.agency_id = _agency_id;

    IF start_iv IS NULL OR end_iv IS NULL THEN
        RETURN;
    END IF;

    origin := (svc_date::timestamp + time '12:00:00') AT TIME ZONE tz - interval '12 hours';
    starts_at := origin + start_iv;
    ends_at := origin + end_iv;
    RETURN NEXT;
END;
$$;

-- Duty assignments ---------------------------------------------------------

CREATE OR REPLACE FUNCTION create_duty_assignment(
    _agency_id uuid, _block_id uuid, _driver_id uuid, _vehicle_id uuid,
    _service_date date, _assigned_by uuid
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO duty_assignments (agency_id, block_id, driver_id, vehicle_id, service_date, assigned_by)
    VALUES (_agency_id, _block_id, _driver_id, _vehicle_id, _service_date, _assigned_by)
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION reassign_duty_assignment(
    _agency_id uuid, _id uuid, _driver_id uuid, _vehicle_id uuid, _assigned_by uuid
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    UPDATE duty_assignments
    SET driver_id = _driver_id, vehicle_id = _vehicle_id, assigned_by = _assigned_by, updated_at = now()
    WHERE agency_id = _agency_id AND id = _id;
$$;

-- Ends the current assignment (status -> completed) and creates the
-- continuation row for a mid-duty vehicle/driver swap, linked by
-- handover_from_id. Both rows keep the same block/service_date.
CREATE OR REPLACE FUNCTION handover_duty_assignment(
    _agency_id uuid, _id uuid, _new_driver_id uuid, _new_vehicle_id uuid, _assigned_by uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
DECLARE
    new_id uuid;
    old_block_id uuid;
    old_service_date date;
BEGIN
    SELECT block_id, service_date INTO old_block_id, old_service_date
    FROM duty_assignments WHERE agency_id = _agency_id AND id = _id
    FOR UPDATE;

    IF old_block_id IS NULL THEN
        RAISE EXCEPTION 'duty assignment % not found for agency %', _id, _agency_id;
    END IF;

    UPDATE duty_assignments SET status = 'completed', updated_at = now()
    WHERE agency_id = _agency_id AND id = _id;

    INSERT INTO duty_assignments (agency_id, block_id, driver_id, vehicle_id, service_date, status, assigned_by, handover_from_id)
    VALUES (_agency_id, old_block_id, _new_driver_id, _new_vehicle_id, old_service_date, 'in_progress', _assigned_by, _id)
    RETURNING id INTO new_id;

    RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION update_duty_assignment_status(_agency_id uuid, _id uuid, _status text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    UPDATE duty_assignments SET status = _status, updated_at = now()
    WHERE agency_id = _agency_id AND id = _id;
$$;

CREATE OR REPLACE FUNCTION list_duty_assignments(
    _agency_id uuid, _service_date date, _driver_id uuid, _vehicle_id uuid, _block_id uuid,
    _limit integer, _offset integer
)
RETURNS TABLE (
    id uuid, block_id uuid, driver_id uuid, vehicle_id uuid, service_date date,
    status text, assigned_by uuid, handover_from_id uuid, created_at timestamptz, updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT da.id, da.block_id, da.driver_id, da.vehicle_id, da.service_date,
           da.status, da.assigned_by, da.handover_from_id, da.created_at, da.updated_at
    FROM duty_assignments da
    WHERE da.agency_id = _agency_id
      AND (_service_date IS NULL OR da.service_date = _service_date)
      AND (_driver_id IS NULL OR da.driver_id = _driver_id)
      AND (_vehicle_id IS NULL OR da.vehicle_id = _vehicle_id)
      AND (_block_id IS NULL OR da.block_id = _block_id)
    ORDER BY da.service_date, da.created_at
    LIMIT _limit OFFSET _offset;
$$;

CREATE OR REPLACE FUNCTION get_duty_assignment(_agency_id uuid, _id uuid)
RETURNS TABLE (
    id uuid, block_id uuid, driver_id uuid, vehicle_id uuid, service_date date,
    status text, assigned_by uuid, handover_from_id uuid, created_at timestamptz, updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT da.id, da.block_id, da.driver_id, da.vehicle_id, da.service_date,
           da.status, da.assigned_by, da.handover_from_id, da.created_at, da.updated_at
    FROM duty_assignments da
    WHERE da.agency_id = _agency_id AND da.id = _id;
$$;

CREATE OR REPLACE FUNCTION count_duty_assignments(_agency_id uuid, _service_date date)
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT count(*)::integer FROM duty_assignments
    WHERE agency_id = _agency_id AND (_service_date IS NULL OR service_date = _service_date);
$$;

-- Conflict-detection context: live (non-cancelled) assignments for a driver
-- or vehicle across a date range, for the Go dispatch package to evaluate
-- double-booking and rest-gap rules against.
CREATE OR REPLACE FUNCTION driver_assignments_in_range(_agency_id uuid, _driver_id uuid, _from date, _to date)
RETURNS TABLE (id uuid, block_id uuid, service_date date, status text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT da.id, da.block_id, da.service_date, da.status
    FROM duty_assignments da
    WHERE da.agency_id = _agency_id AND da.driver_id = _driver_id
      AND da.service_date BETWEEN _from AND _to
      AND da.status <> 'cancelled'
    ORDER BY da.service_date;
$$;

CREATE OR REPLACE FUNCTION vehicle_assignments_in_range(_agency_id uuid, _vehicle_id uuid, _from date, _to date)
RETURNS TABLE (id uuid, block_id uuid, service_date date, status text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT da.id, da.block_id, da.service_date, da.status
    FROM duty_assignments da
    WHERE da.agency_id = _agency_id AND da.vehicle_id = _vehicle_id
      AND da.service_date BETWEEN _from AND _to
      AND da.status <> 'cancelled'
    ORDER BY da.service_date;
$$;

-- Duty events ---------------------------------------------------------

CREATE OR REPLACE FUNCTION insert_duty_event(_agency_id uuid, _assignment_id uuid, _kind text, _actor uuid, _note text)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO duty_events (agency_id, assignment_id, kind, actor, note)
    VALUES (_agency_id, _assignment_id, _kind, _actor, _note)
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION list_duty_events(_agency_id uuid, _assignment_id uuid)
RETURNS TABLE (id uuid, kind text, ts timestamptz, actor uuid, note text)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT e.id, e.kind, e.ts, e.actor, e.note
    FROM duty_events e
    WHERE e.agency_id = _agency_id AND e.assignment_id = _assignment_id
    ORDER BY e.ts;
$$;

-- Depots: read/write helpers for the admin API (depots table itself was
-- created in 0004_roles_and_audit).
CREATE OR REPLACE FUNCTION upsert_depot(_agency_id uuid, _id uuid, _name text)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO depots (id, agency_id, name)
    VALUES (COALESCE(_id, gen_random_uuid()), _agency_id, _name)
    ON CONFLICT (agency_id, name) DO UPDATE SET updated_at = now()
    RETURNING id;
$$;

CREATE OR REPLACE FUNCTION list_depots(_agency_id uuid)
RETURNS TABLE (id uuid, name text, created_at timestamptz, updated_at timestamptz)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT d.id, d.name, d.created_at, d.updated_at
    FROM depots d
    WHERE d.agency_id = _agency_id
    ORDER BY d.name;
$$;

-- Agency lookup by id: the dispatch package needs the agency's timezone and
-- driver_ops config (min_rest_gap_hours, licence_expiry_warning_days) and
-- only has agency_id, not slug, once a JWT is verified.
CREATE OR REPLACE FUNCTION get_agency_by_id(_id uuid)
RETURNS TABLE (id uuid, slug text, name jsonb, timezone text, config jsonb)
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    SELECT id, slug, name, timezone, config
    FROM agencies
    WHERE agencies.id = _id
    LIMIT 1;
$$;

-- ---------------------------------------------------------------------------
-- Grants.
-- ---------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION upsert_depot TO transit_app;
GRANT EXECUTE ON FUNCTION list_depots TO transit_app;
GRANT EXECUTE ON FUNCTION get_agency_by_id TO transit_app;
GRANT EXECUTE ON FUNCTION upsert_vehicle TO transit_app;
GRANT EXECUTE ON FUNCTION list_vehicles TO transit_app;
GRANT EXECUTE ON FUNCTION get_vehicle TO transit_app;
GRANT EXECUTE ON FUNCTION delete_vehicle TO transit_app;
GRANT EXECUTE ON FUNCTION count_vehicles TO transit_app;
GRANT EXECUTE ON FUNCTION upsert_driver_profile TO transit_app;
GRANT EXECUTE ON FUNCTION list_driver_profiles TO transit_app;
GRANT EXECUTE ON FUNCTION get_driver_profile TO transit_app;
GRANT EXECUTE ON FUNCTION count_driver_profiles TO transit_app;
GRANT EXECUTE ON FUNCTION insert_user_role TO transit_app;
GRANT EXECUTE ON FUNCTION upsert_block TO transit_app;
GRANT EXECUTE ON FUNCTION list_blocks TO transit_app;
GRANT EXECUTE ON FUNCTION get_block TO transit_app;
GRANT EXECUTE ON FUNCTION count_blocks TO transit_app;
GRANT EXECUTE ON FUNCTION list_unassigned_blocks TO transit_app;
GRANT EXECUTE ON FUNCTION block_time_span TO transit_app;
GRANT EXECUTE ON FUNCTION create_duty_assignment TO transit_app;
GRANT EXECUTE ON FUNCTION reassign_duty_assignment TO transit_app;
GRANT EXECUTE ON FUNCTION handover_duty_assignment TO transit_app;
GRANT EXECUTE ON FUNCTION update_duty_assignment_status TO transit_app;
GRANT EXECUTE ON FUNCTION list_duty_assignments TO transit_app;
GRANT EXECUTE ON FUNCTION get_duty_assignment TO transit_app;
GRANT EXECUTE ON FUNCTION count_duty_assignments TO transit_app;
GRANT EXECUTE ON FUNCTION driver_assignments_in_range TO transit_app;
GRANT EXECUTE ON FUNCTION vehicle_assignments_in_range TO transit_app;
GRANT EXECUTE ON FUNCTION insert_duty_event TO transit_app;
GRANT EXECUTE ON FUNCTION list_duty_events TO transit_app;
GRANT EXECUTE ON FUNCTION fleet_write_policy TO transit_app;
GRANT EXECUTE ON FUNCTION dispatch_write_policy TO transit_app;
GRANT EXECUTE ON FUNCTION duty_visible TO transit_app;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
