//go:build integration

package exporter_test

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/csv"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/exporter"
	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/calendar"
	"github.com/bytamilan/transit/services/api/internal/store/fareproducts"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/shapes"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
	"github.com/bytamilan/transit/services/api/internal/testutil"
)

func TestBuildGTFSZip_SeededAgencyProducesAValidFeed(t *testing.T) {
	pool := testutil.MustPool(t)
	ag, err := agencies.New(pool).LookupBySlug(context.Background(), "demo-metro")
	if err != nil || ag == nil {
		t.Fatalf("lookup demo-metro: %v", err)
	}

	src := exporter.Sources{
		Agencies: agencies.New(pool), Stops: stops.New(pool), Routes: routes.New(pool),
		Trips: trips.New(pool), Calendar: calendar.New(pool), Shapes: shapes.New(pool),
		FareProducts: fareproducts.New(pool),
	}

	data, err := src.BuildGTFSZip(context.Background(), ag.ID)
	if err != nil {
		t.Fatalf("build gtfs zip: %v", err)
	}

	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		t.Fatalf("open zip: %v", err)
	}

	files := map[string]*zip.File{}
	for _, f := range zr.File {
		files[f.Name] = f
	}

	required := []string{"agency.txt", "stops.txt", "routes.txt", "trips.txt", "stop_times.txt", "calendar.txt"}
	for _, name := range required {
		if _, ok := files[name]; !ok {
			t.Errorf("expected required file %s in the export, got %v", name, fileNames(files))
		}
	}

	// The demo seed has no calendar_dates/shapes/fare_products — these
	// optional files should be entirely absent, not present-but-empty.
	optional := []string{"calendar_dates.txt", "shapes.txt", "fare_products.txt"}
	for _, name := range optional {
		if _, ok := files[name]; ok {
			t.Errorf("expected %s to be omitted (no rows), but it was present", name)
		}
	}

	rows := readCSV(t, files["stop_times.txt"])
	if len(rows) < 2 { // header + at least one data row
		t.Errorf("expected stop_times.txt to have data rows, got %d lines", len(rows))
	}
	if rows[0][0] != "trip_id" {
		t.Errorf("expected stop_times.txt header to start with trip_id, got %v", rows[0])
	}

	agencyRows := readCSV(t, files["agency.txt"])
	if len(agencyRows) != 2 {
		t.Fatalf("expected exactly one agency row, got %d lines", len(agencyRows))
	}
	if agencyRows[1][0] != "demo-metro" {
		t.Errorf("expected agency_id demo-metro, got %s", agencyRows[1][0])
	}
}

func fileNames(files map[string]*zip.File) []string {
	out := make([]string, 0, len(files))
	for name := range files {
		out = append(out, name)
	}
	return out
}

func readCSV(t *testing.T, f *zip.File) [][]string {
	t.Helper()
	if f == nil {
		t.Fatal("file not found in zip")
	}
	rc, err := f.Open()
	if err != nil {
		t.Fatalf("open %s: %v", f.Name, err)
	}
	defer rc.Close()
	rows, err := csv.NewReader(rc).ReadAll()
	if err != nil {
		t.Fatalf("read %s: %v", f.Name, err)
	}
	return rows
}
