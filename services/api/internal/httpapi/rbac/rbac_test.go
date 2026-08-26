package rbac

import (
	"testing"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/google/uuid"
)

func TestHasPermission(t *testing.T) {
	if !HasPermission("super_admin", PermAgencyWrite) {
		t.Error("super_admin should have PermAgencyWrite")
	}
	if !HasPermission("agency_admin", PermAgencyWrite) {
		t.Error("agency_admin should have PermAgencyWrite")
	}
	if HasPermission("driver", PermAgencyWrite) {
		t.Error("driver should not have PermAgencyWrite")
	}
	if HasPermission("anon", PermHealthRead) {
		t.Error("anon should not have PermHealthRead")
	}
}

func TestActorHas(t *testing.T) {
	a := auth.Actor{Roles: []string{"driver"}}
	if !ActorHas(a, PermDriverRead) {
		t.Error("driver should have PermDriverRead")
	}
	if ActorHas(a, PermAgencyWrite) {
		t.Error("driver should not have PermAgencyWrite")
	}
}

func TestAPIKeyActorScopes(t *testing.T) {
	agency := uuid.MustParse("11111111-1111-1111-1111-111111111111")
	a := auth.Actor{AgencyID: agency, IsAPIKey: true, Scopes: []string{"data:read"}}
	if !ActorHas(a, PermDataRead) {
		t.Error("API key with data:read scope should have PermDataRead")
	}
	if ActorHas(a, PermAgencyRead) {
		t.Error("API key should not inherit role permissions")
	}
}

func TestIsAtLeast(t *testing.T) {
	if !IsAtLeast(auth.Actor{Roles: []string{"agency_admin"}}, "dispatcher") {
		t.Error("agency_admin is at least dispatcher")
	}
	if IsAtLeast(auth.Actor{Roles: []string{"driver"}}, "fleet_manager") {
		t.Error("driver is not at least fleet_manager")
	}
}
