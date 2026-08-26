-- RLS policies for canonical GTFS tables.
-- These are applied automatically by migration 0003_gtfs_core and reproduced here
-- for documentation and manual re-application.
--
-- Read policy: any authenticated request that carries the matching agency_id
--   claim in its JWT. Anon, driver, agency_admin, and dispatcher roles all
--   flow through the same read gate.
-- Write policy: agency_admin for the matching agency only.

SET LOCAL search_path TO transit, public, extensions, auth;

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
