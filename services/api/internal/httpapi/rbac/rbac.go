// Package rbac implements a centralised, table-driven role/permission matrix.
// Handlers consult this package instead of scattering role checks across the
// codebase.
package rbac

import (
	"slices"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
)

// Permission is a capability required by an endpoint or operation.
type Permission string

const (
	PermHealthRead   Permission = "health:read"
	PermAgencyRead   Permission = "agency:read"
	PermAgencyWrite  Permission = "agency:write"
	PermFleetRead    Permission = "fleet:read"
	PermFleetWrite   Permission = "fleet:write"
	PermDispatchRead Permission = "dispatch:read"
	PermDispatchAct  Permission = "dispatch:act"
	PermDriverRead   Permission = "driver:read"
	PermDriverWrite  Permission = "driver:write"
	PermAuditRead    Permission = "audit:read"
	PermAuditExport  Permission = "audit:export"
	PermDataRead     Permission = "data:read" // data_consumer / API-key scope
	PermAdminRead    Permission = "admin:read"
	PermAdminWrite   Permission = "admin:write"
)

var allPermissions = []Permission{
	PermHealthRead, PermAgencyRead, PermAgencyWrite,
	PermFleetRead, PermFleetWrite, PermDispatchRead, PermDispatchAct,
	PermDriverRead, PermDriverWrite, PermAuditRead, PermAuditExport,
	PermDataRead, PermAdminRead, PermAdminWrite,
}

// roleOrder defines a seniority ranking used by IsAtLeast. Higher is more
// privileged.
var roleOrder = map[string]int{
	"anon":          0,
	"rider":         1,
	"data_consumer": 2,
	"driver":        3,
	"dispatcher":    4,
	"fleet_manager": 5,
	"agency_admin":  6,
	"super_admin":   7,
}

// matrix maps each role to the permissions it grants.
var matrix = map[string]map[Permission]struct{}{
	"super_admin": func() map[Permission]struct{} {
		m := make(map[Permission]struct{}, len(allPermissions))
		for _, p := range allPermissions {
			m[p] = struct{}{}
		}
		return m
	}(),
	"agency_admin": {
		PermHealthRead:   {},
		PermAgencyRead:   {},
		PermAgencyWrite:  {},
		PermFleetRead:    {},
		PermFleetWrite:   {},
		PermDispatchRead: {},
		PermDispatchAct:  {},
		PermDriverRead:   {},
		PermDriverWrite:  {},
		PermAuditRead:    {},
		PermAuditExport:  {},
		PermDataRead:     {},
		PermAdminRead:    {},
		PermAdminWrite:   {},
	},
	"fleet_manager": {
		PermHealthRead:   {},
		PermAgencyRead:   {},
		PermFleetRead:    {},
		PermFleetWrite:   {},
		PermDriverRead:   {},
		PermDriverWrite:  {},
		PermAuditRead:    {},
		PermDataRead:     {},
		PermAdminRead:    {},
	},
	"dispatcher": {
		PermHealthRead:   {},
		PermAgencyRead:   {},
		PermDispatchRead: {},
		PermDispatchAct:  {},
		PermDriverRead:   {},
		PermDataRead:     {},
	},
	"driver": {
		PermHealthRead: {},
		PermDriverRead: {},
		PermDriverWrite: {},
		PermDataRead:   {},
	},
	"data_consumer": {
		PermDataRead: {},
	},
	"rider": {
		PermHealthRead: {},
		PermAgencyRead: {},
		PermDataRead:   {},
	},
	"anon": {
		PermAgencyRead: {},
	},
}

// HasPermission reports whether a single role grants a permission.
func HasPermission(role string, p Permission) bool {
	perms, ok := matrix[role]
	if !ok {
		return false
	}
	_, ok = perms[p]
	return ok
}

// ActorHas reports whether any of the actor's roles grants the permission.
func ActorHas(a auth.Actor, p Permission) bool {
	if a.IsAPIKey {
		// API keys carry scopes, not roles. A scope named like a permission
		// directly grants that permission.
		for _, s := range a.Scopes {
			if Permission(s) == p {
				return true
			}
		}
	}
	for _, role := range a.Roles {
		if HasPermission(role, p) {
			return true
		}
	}
	return false
}

// IsAtLeast reports whether the actor's highest role is at least minRole.
func IsAtLeast(a auth.Actor, minRole string) bool {
	minRank, ok := roleOrder[minRole]
	if !ok {
		return false
	}
	for _, r := range a.Roles {
		rank, ok := roleOrder[r]
		if ok && rank >= minRank {
			return true
		}
	}
	return false
}

// HighestRole returns the most senior role held by the actor, or "" if none.
func HighestRole(a auth.Actor) string {
	var best string
	var bestRank int = -1
	for _, r := range a.Roles {
		if rank, ok := roleOrder[r]; ok && rank > bestRank {
			bestRank = rank
			best = r
		}
	}
	return best
}

// Roles returns the list of known role names (useful for tests and config).
func Roles() []string {
	out := make([]string, 0, len(matrix))
	for role := range matrix {
		out = append(out, role)
	}
	slices.Sort(out)
	return out
}
