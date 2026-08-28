// Package osm fetches bus-stop candidates from the OpenStreetMap Overpass
// API for the admin stop-import flow. It is fetch-and-parse only: candidates
// are handed to the caller, which decides what to persist into the canonical
// GTFS stops table.
package osm

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"time"

	"github.com/bytamilan/transit/services/api/internal/adapters"
)

// DefaultOverpassURL is the public Overpass interpreter endpoint.
const DefaultOverpassURL = "https://overpass-api.de/api/interpreter"

// Client queries an Overpass API endpoint.
type Client struct {
	// BaseURL overrides the Overpass endpoint; empty means DefaultOverpassURL.
	BaseURL string
	Fetcher adapters.Fetcher
	// RetryBackoff is the initial delay between retries on Overpass
	// rate-limit responses; zero means a sane default. Tests set it tiny.
	RetryBackoff time.Duration
}

// NewClient returns a Client using OSM_OVERPASS_URL (or the public default).
func NewClient(fetcher adapters.Fetcher) *Client {
	return &Client{BaseURL: os.Getenv("OSM_OVERPASS_URL"), Fetcher: fetcher}
}

func (c *Client) baseURL() string {
	if c.BaseURL == "" {
		return DefaultOverpassURL
	}
	return c.BaseURL
}

// FetchBusStops runs an Overpass QL query and parses the response into stop
// candidates. Overpass answers 429 (rate limited) and 504 (upstream timeout)
// under load; both are transient, so they are retried with backoff before a
// clean error is surfaced.
func (c *Client) FetchBusStops(ctx context.Context, query string) ([]StopCandidate, error) {
	if c.Fetcher == nil {
		return nil, errors.New("osm: no fetcher configured")
	}
	u := c.baseURL() + "?data=" + url.QueryEscape(query)

	backoff := c.RetryBackoff
	if backoff <= 0 {
		backoff = time.Second
	}
	const maxAttempts = 3
	for attempt := 1; ; attempt++ {
		resp, err := adapters.FetchWithBackoff(ctx, c.Fetcher, u, nil, nil)
		if err != nil {
			return nil, fmt.Errorf("osm: overpass request failed: %w", err)
		}
		body, readErr := io.ReadAll(io.LimitReader(resp.Body, 32<<20))
		_ = resp.Body.Close()
		if readErr != nil {
			return nil, fmt.Errorf("osm: read overpass response: %w", readErr)
		}

		if resp.StatusCode == http.StatusOK {
			return ParseOverpassJSON(body)
		}
		if resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode == http.StatusGatewayTimeout {
			if attempt == maxAttempts {
				return nil, fmt.Errorf("osm: overpass still unavailable after %d attempts (last status %s)", maxAttempts, resp.Status)
			}
			select {
			case <-ctx.Done():
				return nil, ctx.Err()
			case <-time.After(backoff):
			}
			backoff *= 2
			continue
		}
		return nil, fmt.Errorf("osm: overpass returned %s: %s", resp.Status, truncate(string(body), 200))
	}
}

func truncate(s string, n int) string {
	if len(s) > n {
		return s[:n]
	}
	return s
}
