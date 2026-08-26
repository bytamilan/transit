//go:build integration

package gtfsrt

import (
	"context"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/bytamilan/transit/services/api/internal/adapters"
)

// TestRealTimeFeed validates a live public GTFS-RT feed. It is skipped if the
// network is unavailable or the upstream feed changes, so it is safe to run
// as part of the integration suite.
func TestRealTimeFeed(t *testing.T) {
	url := realTimeFeedURL()
	if url == "" {
		t.Skip("REALTIME_TEST_URL not set")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	adapter := &Adapter{
		Fetcher: &adapters.DefaultFetcher{Client: &http.Client{Timeout: 20 * time.Second}},
	}
	feed := adapters.AgencyFeed{
		ID:          "realtime-integration",
		AgencyID:    "00000000-0000-0000-0000-000000000000",
		Adapter:     Name,
		Name:        "integration-test",
		RealtimeURL: url,
		Config:      map[string]any{},
	}

	diags := adapter.Validate(ctx, feed)
	for _, d := range diags {
		if d.Severity == adapters.SeverityFatal || d.Severity == adapters.SeverityError {
			t.Fatalf("unexpected error diagnostic: %+v", d)
		}
	}

	ch, err := adapter.PollRealtime(ctx, feed)
	if err != nil {
		// Network or upstream flakiness is not a test failure.
		t.Skipf("poll realtime skipped: %v", err)
	}
	count := 0
	for range ch {
		count++
		if count > 1000 {
			break
		}
	}
	t.Logf("received %d realtime messages from %s", count, url)
}

func realTimeFeedURL() string {
	if u := os.Getenv("REALTIME_TEST_URL"); u != "" {
		return u
	}
	// No default public feed is hard-coded here. Point REALTIME_TEST_URL at a
	// stable agency mirror before relying on this test in CI.
	return ""
}
