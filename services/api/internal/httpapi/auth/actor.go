// Package auth provides HTTP middleware that turns an incoming request into an
// authenticated Actor carrying agency-scoped roles. It supports Supabase-issued
// JWTs and hashed API keys.
package auth

import (
	"context"
	"net"

	"github.com/google/uuid"
)

// Actor represents the authenticated caller. It is zero-valued for anonymous
// requests and may come from a verified JWT or a valid API key.
type Actor struct {
	UserID   uuid.UUID // zero for API keys and anon
	AgencyID uuid.UUID // zero for anon and platform service tokens
	Roles    []string
	DepotID  *uuid.UUID
	IsAPIKey bool
	Scopes   []string // populated for API-key actors
	IP       net.IP
}

// Anonymous returns true when the request carried no credentials.
func (a Actor) Anonymous() bool {
	return a.UserID == uuid.Nil && a.AgencyID == uuid.Nil && !a.IsAPIKey && len(a.Roles) == 0
}

// HasRole reports whether the actor holds any of the supplied roles.
func (a Actor) HasRole(roles ...string) bool {
	for _, want := range roles {
		for _, have := range a.Roles {
			if have == want {
				return true
			}
		}
	}
	return false
}

type actorKey struct{}

// WithActor returns a context carrying an Actor.
func WithActor(ctx context.Context, a Actor) context.Context {
	return context.WithValue(ctx, actorKey{}, a)
}

// FromContext returns the Actor stored by the auth middleware. Missing or
// malformed values return a zero Actor, which behaves as anonymous.
func FromContext(ctx context.Context) Actor {
	v, _ := ctx.Value(actorKey{}).(Actor)
	return v
}
