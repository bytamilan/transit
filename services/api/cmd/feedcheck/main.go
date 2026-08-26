// Command feedcheck validates a single feed and prints diagnostics.
//
// Usage:
//
//	go run ./cmd/feedcheck -adapter gtfs_static -url https://example.com/gtfs.zip
//	go run ./cmd/feedcheck -adapter gtfs_rt -url https://example.com/trip-updates.pb
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"time"

	"github.com/bytamilan/transit/services/api/internal/adapters"
	"github.com/bytamilan/transit/services/api/internal/ingest"
)

func main() {
	adapterName := flag.String("adapter", "", "adapter name (gtfs_static, gtfs_rt)")
	url := flag.String("url", "", "feed URL to validate")
	name := flag.String("name", "feedcheck", "feed name for diagnostics")
	agencyID := flag.String("agency-id", "00000000-0000-0000-0000-000000000000", "agency id for diagnostics")
	flag.Parse()

	if *adapterName == "" || *url == "" {
		flag.Usage()
		os.Exit(2)
	}

	reg := ingest.NewRegistry(&adapters.DefaultFetcher{Client: http.DefaultClient})
	adapter, err := reg.Get(*adapterName)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}

	feed := adapters.AgencyFeed{
		ID:          "feedcheck",
		AgencyID:    *agencyID,
		Adapter:     *adapterName,
		Name:        *name,
		StaticURL:   *url,
		RealtimeURL: *url,
		Config:      map[string]any{},
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	diags := adapter.Validate(ctx, feed)
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	_ = enc.Encode(diags)

	for _, d := range diags {
		if d.Severity == adapters.SeverityFatal || d.Severity == adapters.SeverityError {
			os.Exit(1)
		}
	}
}
