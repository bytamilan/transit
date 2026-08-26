-- Migration 0004_roles_and_audit
-- Adds agency-scoped roles, driver profiles, audit log, API-key stub, and
-- support tables. Enables the security backbone used by the custom access
-- token hook, Go auth middleware, and RBAC.

SET LOCAL search_path TO transit, public, extensions, auth;

-- ---------------------------------------------------------------------------
-- Depots: operational sub-units of an agency. Dispatchers may be depot-scoped.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS depots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    name text NOT NULL,
    geog geography(POINT,4326),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (agency_id, name)
);

CREATE INDEX IF NOT EXISTS idx_depots_agency ON depots (agency_id);
CREATE INDEX IF NOT EXISTS idx_depots_loc ON depots USING GIST (geog);

-- ---------------------------------------------------------------------------
-- User roles: multi-valued, agency-scoped. One person can hold different roles
-- in different agencies (or depots). Never read from user_metadata.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_roles (
    user_id uuid NOT NULL,
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    role text NOT NULL,
    depot_id uuid REFERENCES depots(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, agency_id, role)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user ON user_roles (user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_agency_role ON user_roles (agency_id, role);

-- ---------------------------------------------------------------------------
-- Driver profiles: licence tracking and duty eligibility.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS driver_profiles (
    user_id uuid PRIMARY KEY,
    agency_id uuid NOT NULL REFERENCES agencies(id) ON DELETE CASCADE,
    depot_id uuid REFERENCES depots(id) ON DELETE SET NULL,
    licence_ref_hash text,
    licence_expires_on date,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'expired')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_driver_profiles_agency ON driver_profiles (agency_id);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_licence_expires ON driver_profiles (licence_expires_on);

-- ---------------------------------------------------------------------------
-- Audit log: append-only. Every mutation records actor, action, entity,
-- before/after JSON, timestamp and IP.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid REFERENCES agencies(id) ON DELETE CASCADE,
    actor_id uuid,
    action text NOT NULL,
    entity text NOT NULL,
    before jsonb,
    after jsonb,
    ts timestamptz NOT NULL DEFAULT now(),
    ip inet
);

CREATE INDEX IF NOT EXISTS idx_audit_log_agency_ts ON audit_log (agency_id, ts DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_actor ON audit_log (actor_id, ts DESC);

CREATE OR REPLACE FUNCTION audit_log_block_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'audit_log is append-only: % is not allowed', TG_OP;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_log_block_update ON audit_log;
CREATE TRIGGER trg_audit_log_block_update
    BEFORE UPDATE ON audit_log
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_block_mutation();

DROP TRIGGER IF EXISTS trg_audit_log_block_delete ON audit_log;
CREATE TRIGGER trg_audit_log_block_delete
    BEFORE DELETE ON audit_log
    FOR EACH ROW
    EXECUTE FUNCTION audit_log_block_mutation();

-- ---------------------------------------------------------------------------
-- API keys stub. Full portal lifecycle (request, issue, rotate, revoke)
-- arrives in Phase 4; this table is enough for the auth middleware and tests.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS api_keys (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    agency_id uuid REFERENCES agencies(id) ON DELETE CASCADE,
    org_id uuid,
    key_hash text NOT NULL,
    scopes text[] NOT NULL DEFAULT '{}',
    rate_limit_rpm integer,
    quota_daily integer,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_api_keys_agency ON api_keys (agency_id);

-- ---------------------------------------------------------------------------
-- Helper: extract the user id (sub) from the JWT claims.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    claims jsonb;
    raw text;
BEGIN
    raw := current_setting('request.jwt.claims', true);
    IF raw IS NULL OR raw = '' THEN
        RETURN NULL;
    END IF;
    claims := raw::jsonb;
    IF claims IS NULL OR claims->>'sub' IS NULL OR claims->>'sub' = '' THEN
        RETURN NULL;
    END IF;
    RETURN (claims->>'sub')::uuid;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$;

-- ---------------------------------------------------------------------------
-- RLS policies for the new tables.
-- Read: own agency (or depot-scoped dispatcher sees only matching depot).
-- Write: agency_admin for own agency; super_admin for all.
-- ---------------------------------------------------------------------------
ALTER TABLE depots ENABLE ROW LEVEL SECURITY;
ALTER TABLE depots FORCE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles FORCE ROW LEVEL SECURITY;
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log FORCE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys FORCE ROW LEVEL SECURITY;

-- Depot-scoped read helper: true when the actor has the same agency and either
-- no depot restriction or the same depot.
CREATE OR REPLACE FUNCTION own_or_dept_scoped(agency_uuid uuid, depot_uuid uuid)
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
    IF current_user_role() = 'dispatcher' THEN
        -- Dispatcher depot scope is carried in the JWT depot_id claim.
        RETURN (current_setting('request.jwt.claims', true)::jsonb->>'depot_id')::uuid IS NULL
            OR (current_setting('request.jwt.claims', true)::jsonb->>'depot_id')::uuid = depot_uuid;
    END IF;
    RETURN true;
END;
$$;

-- Generic write helper for agency_admin / super_admin within the current agency.
CREATE OR REPLACE FUNCTION admin_write_policy(agency_uuid uuid)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    RETURN current_user_role() = 'super_admin'
        OR (current_user_role() = 'agency_admin' AND current_agency_id() = agency_uuid);
END;
$$;

CREATE POLICY depots_select_own ON depots FOR SELECT USING (own_or_dept_scoped(agency_id, NULL));
CREATE POLICY depots_write_own ON depots FOR ALL USING (admin_write_policy(agency_id)) WITH CHECK (admin_write_policy(agency_id));

CREATE POLICY user_roles_select_own ON user_roles FOR SELECT USING (own_or_dept_scoped(agency_id, depot_id));
CREATE POLICY user_roles_write_own ON user_roles FOR ALL USING (admin_write_policy(agency_id)) WITH CHECK (admin_write_policy(agency_id));

CREATE POLICY driver_profiles_select_own ON driver_profiles FOR SELECT USING (own_or_dept_scoped(agency_id, depot_id));
CREATE POLICY driver_profiles_write_own ON driver_profiles FOR ALL USING (admin_write_policy(agency_id)) WITH CHECK (admin_write_policy(agency_id));

CREATE POLICY audit_log_select_own ON audit_log FOR SELECT USING (
    current_user_role() = 'super_admin' OR current_agency_id() = agency_id
);
CREATE POLICY audit_log_insert ON audit_log FOR INSERT WITH CHECK (
    current_user_role() IN ('super_admin', 'agency_admin', 'fleet_manager', 'dispatcher', 'driver')
    AND current_agency_id() = agency_id
);

CREATE POLICY api_keys_select_own ON api_keys FOR SELECT USING (admin_write_policy(agency_id));
CREATE POLICY api_keys_write_own ON api_keys FOR ALL USING (admin_write_policy(agency_id)) WITH CHECK (admin_write_policy(agency_id));

-- Grant app role access to the new schema objects.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO transit_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA transit TO transit_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA transit GRANT EXECUTE ON FUNCTIONS TO transit_app;
