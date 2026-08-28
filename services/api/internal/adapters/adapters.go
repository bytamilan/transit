// Package adapters defines the common interface and types for every upstream
// adapter. Each adapter normalises its upstream format into the canonical GTFS
// tables and the internal realtime model.
package adapters

import (
	"context"
	"fmt"
	"net/http"
	"time"
)

// Adapter is implemented by every upstream adapter (gtfs_static, gtfs_rt,
// siri, etc.). It matches the interface in docs/BUILD_PROMPT.md §5.
type Adapter interface {
	Name() string
	Capabilities() Capabilities
	RateStrategy() RateStrategy
	SyncStatic(ctx context.Context, feed AgencyFeed) (StaticResult, error)
	PollRealtime(ctx context.Context, feed AgencyFeed) (<-chan RTMessage, error)
	Validate(ctx context.Context, feed AgencyFeed) []Diagnostic
}

// Capabilities describes what an adapter can provide.
type Capabilities struct {
	Static          bool
	Realtime        bool
	Fares           bool
	Redistributable bool
}

// RateStrategy tells the scheduler how often to invoke a realtime/periodic
// adapter. Static adapters usually declare OnDemand and are triggered manually
// or by an external schedule.
type RateStrategy struct {
	Kind            RateStrategyKind
	IntervalSeconds int // used when Kind == FixedInterval
}

// RateStrategyKind enumerates the scheduler strategies an adapter can declare.
type RateStrategyKind string

const (
	OnDemand      RateStrategyKind = "on_demand"
	FixedInterval RateStrategyKind = "fixed_interval"
	ReadThroughTTL RateStrategyKind = "read_through_ttl"
)

// AgencyFeed is the configuration for a single feed instance.
type AgencyFeed struct {
	ID            string
	AgencyID      string
	Adapter       string
	Name          string
	StaticURL     string
	RealtimeURL   string
	Config        map[string]any
	RateStrategy  RateStrategy
}

// StaticResult is returned by SyncStatic.
type StaticResult struct {
	Upserted        int
	Unchanged       int
	FeedVersion     string
	Diagnostics     []Diagnostic
	StartedAt       time.Time
	FinishedAt      time.Time
}

// RTMessage is the normalised realtime message type emitted by PollRealtime.
type RTMessage struct {
	Kind      RTMessageKind
	AgencyID  string
	FeedID    string
	Timestamp time.Time
	TripUpdate *TripUpdate
	Vehicle    *VehiclePosition
	Alert      *ServiceAlert
}

// RTMessageKind identifies which realtime entity a message carries.
type RTMessageKind string

const (
	RTTripUpdate      RTMessageKind = "trip_update"
	RTVehiclePosition RTMessageKind = "vehicle_position"
	RTServiceAlert    RTMessageKind = "service_alert"
)

// TripUpdate is a normalised GTFS-RT trip update.
type TripUpdate struct {
	TripID        string
	RouteID       string
	StartTime     string
	StartDate     string
	ScheduleRel   string
	StopTimeUpdates []StopTimeUpdate
}

// StopTimeUpdate is a normalised prediction for one stop.
type StopTimeUpdate struct {
	StopSequence  *int
	StopID        string
	ArrivalDelay  *int
	DepartureDelay *int
	ArrivalTime   *time.Time
	DepartureTime *time.Time
}

// VehiclePosition is a normalised GTFS-RT vehicle position.
type VehiclePosition struct {
	VehicleID     string
	TripID        string
	RouteID       string
	Latitude      float64
	Longitude     float64
	Bearing       float64
	Speed         float64
	Occupancy     string
	CurrentStatus string
	StopID        string
	StopSequence  *int
}

// ServiceAlert is a normalised GTFS-RT service alert.
type ServiceAlert struct {
	AlertID       string
	Cause         string
	Effect        string
	HeaderText    map[string]string
	DescriptionText map[string]string
}

// Diagnostic is a single validation/run issue.
type Diagnostic struct {
	Severity Severity
	Entity   string
	Message  string
}

// Severity levels for diagnostics.
type Severity string

const (
	SeverityFatal   Severity = "fatal"
	SeverityError   Severity = "error"
	SeverityWarning Severity = "warning"
	SeverityInfo    Severity = "info"
)

// Fetcher abstracts HTTP fetching so tests can inject fake responses.
type Fetcher interface {
	Fetch(ctx context.Context, url string, headers map[string]string) (*http.Response, error)
}

// DefaultFetcher is the production HTTP client with timeout and redirect handling.
type DefaultFetcher struct {
	Client *http.Client
}

// Fetch performs an HTTP GET with optional headers.
func (d *DefaultFetcher) Fetch(ctx context.Context, url string, headers map[string]string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	return d.Client.Do(req)
}

// FetchWithBackoff wraps Fetch with exponential backoff and a simple circuit
// breaker. It returns the final HTTP response or error.
func FetchWithBackoff(ctx context.Context, f Fetcher, url string, headers map[string]string, breaker *CircuitBreaker) (*http.Response, error) {
	if breaker != nil && breaker.IsOpen() {
		return nil, fmt.Errorf("circuit breaker open for %s", url)
	}

	const maxRetries = 4
	backoff := 500 * time.Millisecond
	var lastErr error
	for i := 0; i < maxRetries; i++ {
		start := time.Now()
		resp, err := f.Fetch(ctx, url, headers)
		latency := time.Since(start)
		if err == nil {
			if breaker != nil {
				breaker.RecordSuccess()
			}
			_ = latency
			return resp, nil
		}
		lastErr = err
		if breaker != nil {
			breaker.RecordFailure()
		}
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(backoff):
		}
		backoff *= 2
		if backoff > 30*time.Second {
			backoff = 30 * time.Second
		}
	}
	return nil, fmt.Errorf("fetch failed after %d retries: %w", maxRetries, lastErr)
}

// CircuitBreaker is a minimal failure-count circuit breaker.
type CircuitBreaker struct {
	threshold   int
	resetAfter  time.Duration
	failures    int
	lastFailure time.Time
}

// NewCircuitBreaker creates a breaker that opens after threshold consecutive
// failures and tries to close again after resetAfter.
func NewCircuitBreaker(threshold int, resetAfter time.Duration) *CircuitBreaker {
	return &CircuitBreaker{threshold: threshold, resetAfter: resetAfter}
}

// IsOpen reports whether the breaker is currently open.
func (cb *CircuitBreaker) IsOpen() bool {
	if cb == nil {
		return false
	}
	if cb.failures >= cb.threshold {
		if time.Since(cb.lastFailure) > cb.resetAfter {
			cb.failures = 0
			return false
		}
		return true
	}
	return false
}

// RecordFailure increments the failure count.
func (cb *CircuitBreaker) RecordFailure() {
	if cb == nil {
		return
	}
	cb.failures++
	cb.lastFailure = time.Now()
}

// RecordSuccess resets the failure count.
func (cb *CircuitBreaker) RecordSuccess() {
	if cb == nil {
		return
	}
	cb.failures = 0
}
