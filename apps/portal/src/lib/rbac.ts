// Mirrors the role groupings the Go API's table-driven RBAC (rbac.go)
// enforces for the Phase 6 admin endpoints. This is a UI convenience only —
// it decides what the portal shows, never what it allows; the Go API
// re-checks every request server-side regardless of what the client sends.
export const FLEET_ROLES = ["fleet_manager", "agency_admin", "super_admin"];
export const DISPATCH_ROLES = ["dispatcher", "fleet_manager", "agency_admin", "super_admin"];
export const ADMIN_ROLES = ["fleet_manager", "agency_admin", "super_admin", "dispatcher"];

export function hasAnyRole(roles: string[], allowed: string[]): boolean {
  return roles.some((r) => allowed.includes(r));
}

// Per ADR 0003, the custom access token hook mirrors {agency_id, roles,
// depot_id} into app_metadata.transit so clients can read them without
// decoding the JWT by hand.
export function rolesFromAppMetadata(appMetadata: Record<string, unknown> | undefined): string[] {
  const transit = appMetadata?.transit as { roles?: string[] } | undefined;
  return transit?.roles ?? [];
}
