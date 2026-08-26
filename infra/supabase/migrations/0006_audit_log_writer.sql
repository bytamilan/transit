-- Migration 0006_audit_log_writer
-- Provides a SECURITY DEFINER helper so the Go API (connected as transit_app)
-- can append audit rows. RLS on audit_log requires a Postgres role claim, but
-- the API does not authenticate to Postgres via JWT; it authenticates requests
-- in-process and then writes audit rows using this function.

SET LOCAL search_path TO transit, public;

CREATE OR REPLACE FUNCTION transit.audit_log_insert(
    _agency_id uuid,
    _actor_id uuid,
    _action text,
    _entity text,
    _before jsonb,
    _after jsonb,
    _ip inet
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'transit'
AS $$
    INSERT INTO audit_log (agency_id, actor_id, action, entity, before, after, ts, ip)
    VALUES (_agency_id, _actor_id, _action, _entity, _before, _after, now(), _ip);
$$;

GRANT EXECUTE ON FUNCTION transit.audit_log_insert TO transit_app;
