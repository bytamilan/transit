package osm

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

const fixtureOverpassJSON = `{
  "version": 0.6,
  "generator": "Overpass API 0.7.62",
  "elements": [
    {"type": "node", "id": 123, "lat": 1.3500, "lon": 103.8000,
     "tags": {"highway": "bus_stop", "name": "Main St", "ref": "A1", "wheelchair": "yes", "platform_code": "1"}},
    {"type": "node", "id": 456, "lat": 1.3600, "lon": 103.8100,
     "tags": {"public_transport": "platform", "local_ref": "B2", "wheelchair": "no"}},
    {"type": "node", "id": 789, "lat": 1.3700, "lon": 103.8200,
     "tags": {"highway": "bus_stop", "wheelchair": "limited"}},
    {"type": "way", "id": 999, "tags": {"name": "not a stop node"}}
  ]
}`

func TestParseOverpassJSON(t *testing.T) {
	got, err := ParseOverpassJSON([]byte(fixtureOverpassJSON))
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if len(got) != 3 {
		t.Fatalf("expected 3 candidates (way element skipped), got %d", len(got))
	}

	if got[0].StopID != "osm:node:123" {
		t.Errorf("expected namespaced stop id, got %q", got[0].StopID)
	}
	if got[0].Name != "Main St" || got[0].Ref != "A1" || got[0].PlatformCode != "1" {
		t.Errorf("unexpected first candidate: %+v", got[0])
	}
	if got[0].WheelchairBoarding != 1 {
		t.Errorf("wheelchair=yes should map to 1, got %d", got[0].WheelchairBoarding)
	}

	// name falls back through ref → local_ref.
	if got[1].Name != "B2" || got[1].Ref != "B2" || got[1].PlatformCode != "B2" {
		t.Errorf("expected local_ref fallbacks, got %+v", got[1])
	}
	if got[1].WheelchairBoarding != 2 {
		t.Errorf("wheelchair=no should map to 2, got %d", got[1].WheelchairBoarding)
	}

	// No name tags at all → generated name (stop_name is NOT NULL), and
	// wheelchair=limited maps to 1.
	if got[2].Name != "Unnamed stop 789" {
		t.Errorf("expected generated fallback name, got %q", got[2].Name)
	}
	if got[2].WheelchairBoarding != 1 {
		t.Errorf("wheelchair=limited should map to 1, got %d", got[2].WheelchairBoarding)
	}
	if got[2].Ref != "" || got[2].PlatformCode != "" {
		t.Errorf("expected empty ref/platform_code, got %+v", got[2])
	}
}

func TestParseOverpassJSON_Invalid(t *testing.T) {
	if _, err := ParseOverpassJSON([]byte(`not json`)); err == nil {
		t.Fatal("expected error for invalid JSON")
	}
}

func TestBuildBusStopQuery(t *testing.T) {
	q, err := BuildBusStopQuery(1.2, 103.7, 1.4, 103.9)
	if err != nil {
		t.Fatalf("build query: %v", err)
	}
	want := `[out:json][timeout:25];(node["highway"="bus_stop"](1.2,103.7,1.4,103.9);node["public_transport"="platform"](1.2,103.7,1.4,103.9););out body;`
	if q != want {
		t.Errorf("unexpected query:\n got %s\nwant %s", q, want)
	}
}

func TestBuildBusStopQuery_Validation(t *testing.T) {
	cases := map[string][4]float64{
		"zero area":   {1.2, 103.7, 1.2, 103.9},
		"inverted":    {1.4, 103.7, 1.2, 103.9},
		"too tall":    {1.2, 103.7, 1.2 + MaxBBoxSpanDegrees + 0.01, 103.9},
		"too wide":    {1.2, 103.7, 1.4, 103.7 + MaxBBoxSpanDegrees + 0.01},
	}
	for name, c := range cases {
		if _, err := BuildBusStopQuery(c[0], c[1], c[2], c[3]); err == nil {
			t.Errorf("%s: expected BBoxError", name)
		} else {
			var bboxErr *BBoxError
			if !errors.As(err, &bboxErr) {
				t.Errorf("%s: expected *BBoxError, got %T", name, err)
			}
		}
	}
	// A box exactly at the max span is allowed.
	if _, err := BuildBusStopQuery(1.2, 103.7, 1.2+MaxBBoxSpanDegrees, 103.7+MaxBBoxSpanDegrees); err != nil {
		t.Errorf("max-span box should be accepted: %v", err)
	}
}

// fakeFetcher replays canned responses in order.
type fakeFetcher struct {
	responses []*http.Response
	calls     int
	lastURL   string
}

func (f *fakeFetcher) Fetch(ctx context.Context, url string, headers map[string]string) (*http.Response, error) {
	f.calls++
	f.lastURL = url
	resp := f.responses[0]
	f.responses = f.responses[1:]
	return resp, nil
}

func statusResponse(status int, body string) *http.Response {
	return &http.Response{
		StatusCode: status,
		Status:     http.StatusText(status),
		Body:       io.NopCloser(strings.NewReader(body)),
		Header:     make(http.Header),
	}
}

func TestFetchBusStops_HappyPath(t *testing.T) {
	f := &fakeFetcher{responses: []*http.Response{statusResponse(http.StatusOK, fixtureOverpassJSON)}}
	c := &Client{BaseURL: "https://overpass.example/api", Fetcher: f}

	got, err := c.FetchBusStops(context.Background(), `SOME QUERY`)
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if len(got) != 3 {
		t.Fatalf("expected 3 candidates, got %d", len(got))
	}
	if !strings.HasPrefix(f.lastURL, "https://overpass.example/api?data=") {
		t.Errorf("unexpected request URL %q", f.lastURL)
	}
	if !strings.Contains(f.lastURL, "SOME+QUERY") && !strings.Contains(f.lastURL, "SOME%20QUERY") {
		t.Errorf("query not passed as data parameter: %q", f.lastURL)
	}
}

func TestFetchBusStops_RetriesRateLimit(t *testing.T) {
	f := &fakeFetcher{responses: []*http.Response{
		statusResponse(http.StatusTooManyRequests, "rate limited"),
		statusResponse(http.StatusGatewayTimeout, "timeout"),
		statusResponse(http.StatusOK, fixtureOverpassJSON),
	}}
	c := &Client{BaseURL: "https://overpass.example/api", Fetcher: f, RetryBackoff: time.Millisecond}

	got, err := c.FetchBusStops(context.Background(), "q")
	if err != nil {
		t.Fatalf("fetch: %v", err)
	}
	if len(got) != 3 || f.calls != 3 {
		t.Errorf("expected 3 candidates after 3 attempts, got %d candidates / %d calls", len(got), f.calls)
	}
}

func TestFetchBusStops_RateLimitExhausted(t *testing.T) {
	f := &fakeFetcher{responses: []*http.Response{
		statusResponse(http.StatusTooManyRequests, "rate limited"),
		statusResponse(http.StatusTooManyRequests, "rate limited"),
		statusResponse(http.StatusTooManyRequests, "rate limited"),
	}}
	c := &Client{BaseURL: "https://overpass.example/api", Fetcher: f, RetryBackoff: time.Millisecond}

	_, err := c.FetchBusStops(context.Background(), "q")
	if err == nil || !strings.Contains(err.Error(), "still unavailable") {
		t.Fatalf("expected clean exhaustion error, got %v", err)
	}
}

func TestFetchBusStops_NonRetryableStatus(t *testing.T) {
	f := &fakeFetcher{responses: []*http.Response{statusResponse(http.StatusBadRequest, "syntax error in query")}}
	c := &Client{BaseURL: "https://overpass.example/api", Fetcher: f, RetryBackoff: time.Millisecond}

	_, err := c.FetchBusStops(context.Background(), "q")
	if err == nil || !strings.Contains(err.Error(), "syntax error in query") {
		t.Fatalf("expected status error with body snippet, got %v", err)
	}
	if f.calls != 1 {
		t.Errorf("400 should not be retried, got %d calls", f.calls)
	}
}
