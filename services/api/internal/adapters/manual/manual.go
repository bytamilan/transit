// Package manual implements the Adapter interface for agencies with zero
// prior digital data (brief §5, §9). It matters more than it looks: for
// minibuses, jeepneys, matatus and marshrutkas with no published schedule in
// any format, the admin console (Phase 6) plus the driver app (Phase 7) are
// the entire data pipeline, and this adapter is what turns that into a
// standards-compliant GTFS/GTFS-RT output.
//
// Unlike every other adapter, "upstream" here is the canonical GTFS tables
// themselves — an agency builds its network directly in /admin (Phase 6),
// so there is nothing to fetch or parse. SyncStatic and Validate just check
// that a usable network actually exists yet, so a fleet_manager activating
// manual mode with an empty database gets an actionable diagnostic instead
// of a silently-empty export. Realtime is even more hands-off: driver-app
// telemetry already flows into stop_events/vehicle_trips independently via
// internal/tracking (Phase 8) and the exporter reads that directly — this
// adapter's PollRealtime has nothing of its own to poll.
package manual

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/bytamilan/transit/services/api/internal/adapters"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
)

const Name = "manual"

// Adapter validates that an agency's admin-console-built network is usable.
type Adapter struct {
	Stops  *stops.Reader
	Routes *routes.Reader
	Trips  *trips.Reader
}

// Name returns the adapter identifier.
func (a *Adapter) Name() string { return Name }

// Capabilities declares static (via the admin console) and realtime (via
// driver-app telemetry, ping-age confidence) support, redistributable since
// the agency authored the data itself.
func (a *Adapter) Capabilities() adapters.Capabilities {
	return adapters.Capabilities{Static: true, Realtime: true, Redistributable: true}
}

// RateStrategy is on-demand — there is no upstream to poll on a schedule;
// static data changes whenever an admin edits it, and realtime already
// flows continuously through internal/tracking regardless of this adapter.
func (a *Adapter) RateStrategy() adapters.RateStrategy {
	return adapters.RateStrategy{Kind: adapters.OnDemand}
}

// SyncStatic reports what's already in the canonical tables rather than
// writing anything — there's nothing to upsert since the admin console
// already wrote it. Kept as a real (non-trivial) call so a sync_runs row
// still records a meaningful check each time it's invoked.
func (a *Adapter) SyncStatic(ctx context.Context, feed adapters.AgencyFeed) (adapters.StaticResult, error) {
	started := time.Now()
	counts, diags, err := a.checkNetwork(ctx, feed.AgencyID)
	if err != nil {
		return adapters.StaticResult{}, err
	}
	return adapters.StaticResult{
		Upserted:    0,
		Unchanged:   counts,
		Diagnostics: diags,
		StartedAt:   started,
		FinishedAt:  time.Now(),
	}, nil
}

// PollRealtime returns an already-closed channel: this adapter emits
// nothing of its own. Realtime for a manual-sourced agency comes from
// driver-app telemetry, independently reprocessed by internal/tracking
// (Phase 8) and read directly by the exporter (Phase 10) — there is no
// separate realtime feed for this adapter to poll or normalise.
func (a *Adapter) PollRealtime(ctx context.Context, feed adapters.AgencyFeed) (<-chan adapters.RTMessage, error) {
	ch := make(chan adapters.RTMessage)
	close(ch)
	return ch, nil
}

// Validate checks the network without recording a sync run.
func (a *Adapter) Validate(ctx context.Context, feed adapters.AgencyFeed) []adapters.Diagnostic {
	_, diags, err := a.checkNetwork(ctx, feed.AgencyID)
	if err != nil {
		return []adapters.Diagnostic{{Severity: adapters.SeverityFatal, Entity: "agency", Message: err.Error()}}
	}
	return diags
}

func (a *Adapter) checkNetwork(ctx context.Context, agencyIDStr string) (int, []adapters.Diagnostic, error) {
	agencyID, err := uuid.Parse(agencyIDStr)
	if err != nil {
		return 0, nil, fmt.Errorf("invalid agency id %q: %w", agencyIDStr, err)
	}

	stopCount, err := a.Stops.Count(ctx, agencyID)
	if err != nil {
		return 0, nil, fmt.Errorf("count stops: %w", err)
	}
	routeCount, err := a.Routes.Count(ctx, agencyID)
	if err != nil {
		return 0, nil, fmt.Errorf("count routes: %w", err)
	}
	tripCount, err := a.Trips.Count(ctx, agencyID, "", "")
	if err != nil {
		return 0, nil, fmt.Errorf("count trips: %w", err)
	}

	var diags []adapters.Diagnostic
	if stopCount == 0 {
		diags = append(diags, adapters.Diagnostic{Severity: adapters.SeverityError, Entity: "stops", Message: "no stops defined yet — build the network in /admin before exporting"})
	}
	if routeCount == 0 {
		diags = append(diags, adapters.Diagnostic{Severity: adapters.SeverityError, Entity: "routes", Message: "no routes defined yet — build the network in /admin before exporting"})
	}
	if tripCount == 0 {
		diags = append(diags, adapters.Diagnostic{Severity: adapters.SeverityError, Entity: "trips", Message: "no trips defined yet — build the network in /admin before exporting"})
	}
	if len(diags) == 0 {
		diags = append(diags, adapters.Diagnostic{
			Severity: adapters.SeverityInfo,
			Entity:   "network",
			Message:  fmt.Sprintf("%d stops, %d routes, %d trips ready to export", stopCount, routeCount, tripCount),
		})
	}

	return stopCount + routeCount + tripCount, diags, nil
}
