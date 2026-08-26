-- RLS policies for the agencies (tenant root) table.
-- These are applied automatically by migration 0002_tenancy and reproduced here
-- for documentation and manual re-application.

SET LOCAL search_path TO transit, public, extensions, auth;

ALTER TABLE agencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE agencies FORCE ROW LEVEL SECURITY;

CREATE POLICY agencies_select_own
    ON agencies
    FOR SELECT
    USING (
        current_user_role() = 'super_admin'
        OR current_agency_id() = id
    );

CREATE POLICY agencies_update_own
    ON agencies
    FOR UPDATE
    USING (
        current_user_role() = 'super_admin'
        OR (current_user_role() = 'agency_admin' AND current_agency_id() = id)
    )
    WITH CHECK (
        current_user_role() = 'super_admin'
        OR (current_user_role() = 'agency_admin' AND current_agency_id() = id)
    );

CREATE POLICY agencies_insert_super
    ON agencies
    FOR INSERT
    WITH CHECK (current_user_role() = 'super_admin');

CREATE POLICY agencies_delete_super
    ON agencies
    FOR DELETE
    USING (current_user_role() = 'super_admin');
