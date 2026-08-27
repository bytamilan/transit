//go:build integration

package manual_test

import (
	"context"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/adapters"
	"github.com/bytamilan/transit/services/api/internal/adapters/manual"
	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
	"github.com/bytamilan/transit/services/api/internal/testutil"
)

func TestManualAdapter_ValidateReportsSeededNetworkAsReady(t *testing.T) {
	pool := testutil.MustPool(t)
	ag, err := agencies.New(pool).LookupBySlug(context.Background(), "demo-metro")
	if err != nil || ag == nil {
		t.Fatalf("lookup demo-metro: %v", err)
	}

	a := &manual.Adapter{Stops: stops.New(pool), Routes: routes.New(pool), Trips: trips.New(pool)}
	diags := a.Validate(context.Background(), adapters.AgencyFeed{AgencyID: ag.ID.String()})

	for _, d := range diags {
		if d.Severity == adapters.SeverityError || d.Severity == adapters.SeverityFatal {
			t.Errorf("expected the seeded demo-metro network to validate cleanly, got %s: %s", d.Severity, d.Message)
		}
	}
	if len(diags) == 0 {
		t.Error("expected at least one info diagnostic confirming the network is ready")
	}
}

func TestManualAdapter_ValidateFlagsAnEmptyNetwork(t *testing.T) {
	pool := testutil.MustPool(t)
	a := &manual.Adapter{Stops: stops.New(pool), Routes: routes.New(pool), Trips: trips.New(pool)}

	// A brand-new, never-seeded agency id has no routes/stops/trips.
	diags := a.Validate(context.Background(), adapters.AgencyFeed{AgencyID: "00000000-0000-0000-0000-000000000000"})

	var sawError bool
	for _, d := range diags {
		if d.Severity == adapters.SeverityError {
			sawError = true
		}
	}
	if !sawError {
		t.Errorf("expected an error diagnostic for an empty network, got %+v", diags)
	}
}

func TestManualAdapter_SyncStaticNeverWrites(t *testing.T) {
	pool := testutil.MustPool(t)
	ag, err := agencies.New(pool).LookupBySlug(context.Background(), "demo-metro")
	if err != nil || ag == nil {
		t.Fatalf("lookup demo-metro: %v", err)
	}

	a := &manual.Adapter{Stops: stops.New(pool), Routes: routes.New(pool), Trips: trips.New(pool)}
	result, err := a.SyncStatic(context.Background(), adapters.AgencyFeed{AgencyID: ag.ID.String()})
	if err != nil {
		t.Fatalf("sync static: %v", err)
	}
	if result.Upserted != 0 {
		t.Errorf("expected Upserted to always be 0 — this adapter never writes, got %d", result.Upserted)
	}
	if result.Unchanged == 0 {
		t.Error("expected Unchanged to report the existing network size")
	}
}

func TestManualAdapter_PollRealtimeReturnsAClosedChannel(t *testing.T) {
	a := &manual.Adapter{}
	ch, err := a.PollRealtime(context.Background(), adapters.AgencyFeed{})
	if err != nil {
		t.Fatalf("poll realtime: %v", err)
	}
	if _, ok := <-ch; ok {
		t.Error("expected an already-closed channel with no messages")
	}
}
