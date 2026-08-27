package auth

import (
	"context"
	"testing"
	"time"

	"github.com/bytamilan/transit/services/api/internal/store/apikeys"
	"github.com/google/uuid"
)

// fakeKeyLookup is a DB-free stand-in for *apikeys.Store, so
// apiKeyActor's rate-limit and daily-quota logic can be exercised without
// a live database — the same store-independence discipline this codebase
// uses for internal/planner and internal/tracking's pure-logic tests.
type fakeKeyLookup struct {
	key       *apikeys.Key
	lookupErr error
	usedToday int
	usageErr  error
}

func (f *fakeKeyLookup) Lookup(ctx context.Context, hash string) (*apikeys.Key, error) {
	if f.lookupErr != nil {
		return nil, f.lookupErr
	}
	return f.key, nil
}

func (f *fakeKeyLookup) CountUsageSince(ctx context.Context, keyID uuid.UUID, since time.Time) (int, error) {
	if f.usageErr != nil {
		return 0, f.usageErr
	}
	return f.usedToday, nil
}

func TestApiKeyActor_AllowsWithinQuota(t *testing.T) {
	keyID := uuid.New()
	m := &Middleware{keys: &fakeKeyLookup{
		key:       &apikeys.Key{ID: keyID, QuotaDaily: 100},
		usedToday: 50,
	}}

	actor, ok := m.apiKeyActor(context.Background(), "raw-key")
	if !ok {
		t.Fatal("expected the actor to be allowed when usage is under quota")
	}
	if actor.UserID != keyID || !actor.IsAPIKey {
		t.Errorf("actor = %+v, want IsAPIKey with UserID=%v", actor, keyID)
	}
}

func TestApiKeyActor_RejectsWhenQuotaExceeded(t *testing.T) {
	m := &Middleware{keys: &fakeKeyLookup{
		key:       &apikeys.Key{ID: uuid.New(), QuotaDaily: 100},
		usedToday: 100,
	}}

	_, ok := m.apiKeyActor(context.Background(), "raw-key")
	if ok {
		t.Error("expected the actor to be rejected once usage reaches quota_daily")
	}
}

func TestApiKeyActor_NoQuotaConfiguredMeansUnlimited(t *testing.T) {
	m := &Middleware{keys: &fakeKeyLookup{
		key:       &apikeys.Key{ID: uuid.New(), QuotaDaily: 0},
		usedToday: 1_000_000,
	}}

	_, ok := m.apiKeyActor(context.Background(), "raw-key")
	if !ok {
		t.Error("expected quota_daily=0 to mean no quota enforcement")
	}
}

func TestApiKeyActor_AllowsOnQuotaCheckErrorFailOpen(t *testing.T) {
	// A transient DB error checking usage shouldn't take down every
	// API-key caller for a feature whose job is limiting overuse, not
	// availability.
	m := &Middleware{keys: &fakeKeyLookup{
		key:      &apikeys.Key{ID: uuid.New(), QuotaDaily: 100},
		usageErr: context.DeadlineExceeded,
	}}

	_, ok := m.apiKeyActor(context.Background(), "raw-key")
	if !ok {
		t.Error("expected the request to be allowed (fail-open) when the quota check errors")
	}
}

func TestApiKeyActor_RejectsUnknownKey(t *testing.T) {
	m := &Middleware{keys: &fakeKeyLookup{lookupErr: errNotFound}}

	_, ok := m.apiKeyActor(context.Background(), "raw-key")
	if ok {
		t.Error("expected an unrecognised key to be rejected")
	}
}

func TestApiKeyActor_UsesPerKeyRateLimit(t *testing.T) {
	keyID := uuid.New()
	limiter := NewTokenBucket(1000, 1000) // generous default — should not matter
	m := &Middleware{
		keys:    &fakeKeyLookup{key: &apikeys.Key{ID: keyID, RateLimitRPM: 60}}, // 1/sec, burst 60
		limiter: limiter,
	}

	// Drain the per-key bucket (burst of 60) — the 61st call should be denied.
	for i := 0; i < 60; i++ {
		if _, ok := m.apiKeyActor(context.Background(), "raw-key"); !ok {
			t.Fatalf("request %d: expected allow within the 60rpm burst", i)
		}
	}
	if _, ok := m.apiKeyActor(context.Background(), "raw-key"); ok {
		t.Error("expected the 61st immediate request to be denied by the key's own 60rpm limit")
	}
}

var errNotFound = context.Canceled // any non-nil error stands in for pgx.ErrNoRows here
