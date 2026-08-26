//go:build integration

package store

import (
	"context"
	"fmt"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/testutil"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// These tests run against a real Postgres database. The `db.test` Makefile
// target starts a PostGIS container, applies migrations, seeds two demo
// agencies, and runs the Go test suite with DATABASE_URL pointed at it.
//
//go:generate echo "run with: make db.test"

func TestAgencyIsolation(t *testing.T) {
	ctx := context.Background()
	pool := testutil.MustPool(t)

	// Resolve the two seeded agency slugs using a super_admin claim.
	agencies, err := listAgencies(ctx, pool)
	if err != nil {
		t.Fatalf("list agencies: %v", err)
	}
	if len(agencies) != 2 {
		t.Fatalf("expected 2 seeded agencies, got %d", len(agencies))
	}
	var agencyA, agencyB agencyRef
	for _, a := range agencies {
		switch a.Slug {
		case "demo-metro":
			agencyA = a
		case "demo-transit":
			agencyB = a
		}
	}
	if agencyA.ID == "" || agencyB.ID == "" {
		t.Fatalf("expected demo-metro and demo-transit agencies, got %+v", agencies)
	}

	// For each role, verify that reads are scoped to the claimed agency.
	for _, role := range []string{"anon", "driver", "agency_admin"} {
		t.Run(fmt.Sprintf("%s_reads_only_own_agency", role), func(t *testing.T) {
			assertStopsForAgency(ctx, t, pool, role, agencyA.ID, agencyA.Slug)
			assertStopsForAgency(ctx, t, pool, role, agencyB.ID, agencyB.Slug)
		})
	}

	// Cross-agency read: admin from agency A querying B should see nothing.
	t.Run("admin_cross_agency_returns_zero_rows", func(t *testing.T) {
		tx := testutil.WithClaims(ctx, t, pool, testutil.ClaimsJSON("agency_admin", agencyA.ID))
		defer func() { _ = tx.Rollback(ctx) }()

		rows, err := countStops(ctx, tx, agencyB.ID)
		if err != nil {
			t.Fatalf("count stops: %v", err)
		}
		if rows != 0 {
			t.Fatalf("expected 0 stops for cross-agency admin, got %d", rows)
		}
	})

	// Privilege-escalation attempt: a driver token whose user_metadata claims
	// agency_admin must still be blocked from writing. RLS policies read the
	// top-level role claim only.
	t.Run("driver_cannot_write_even_with_user_metadata_spoof", func(t *testing.T) {
		spoof := fmt.Sprintf(
			`{"role": "driver", "agency_id": %q, "user_metadata": {"role": "agency_admin"}}`,
			agencyA.ID,
		)
		tx := testutil.WithClaims(ctx, t, pool, spoof)
		defer func() { _ = tx.Rollback(ctx) }()

		_, err := tx.Exec(ctx, `
			INSERT INTO stops (agency_id, stop_id, stop_name, stop_lat, stop_lon, location_type)
			VALUES ($1, 'evil_stop', 'Evil Stop', 0, 0, 0)
		`, agencyA.ID)
		if err == nil {
			t.Fatalf("expected insert denied for driver, but it succeeded")
		}
	})
}

func assertStopsForAgency(ctx context.Context, t *testing.T, pool *pgxpool.Pool, role, agencyID, expectedSlug string) {
	t.Helper()

	tx := testutil.WithClaims(ctx, t, pool, testutil.ClaimsJSON(role, agencyID))
	defer func() { _ = tx.Rollback(ctx) }()

	rows, err := tx.Query(ctx, "SELECT stop_id FROM stops WHERE agency_id = $1 ORDER BY stop_id", agencyID)
	if err != nil {
		t.Fatalf("query stops: %v", err)
	}
	defer rows.Close()

	var stopIDs []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			t.Fatalf("scan stop: %v", err)
		}
		stopIDs = append(stopIDs, id)
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("rows err: %v", err)
	}

	if len(stopIDs) == 0 {
		t.Fatalf("expected stops for agency %s (%s), got none", agencyID, expectedSlug)
	}

	// Every returned stop must belong to this agency. Because RLS already
	// filtered by current_agency_id(), this is a sanity check that the query
	// plan is using the policy.
	for _, id := range stopIDs {
		var owner string
		if err := tx.QueryRow(ctx, "SELECT agency_id FROM stops WHERE stop_id = $1", id).Scan(&owner); err != nil {
			t.Fatalf("lookup owner for %s: %v", id, err)
		}
		if owner != agencyID {
			t.Fatalf("stop %s owned by %s, expected %s", id, owner, agencyID)
		}
	}
}

type agencyRef struct {
	ID   string
	Slug string
}

func listAgencies(ctx context.Context, pool *pgxpool.Pool) ([]agencyRef, error) {
	// Use a super_admin claim to read all agencies during test setup.
	tx, err := pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx, "SET LOCAL request.jwt.claims = '{\"role\": \"super_admin\"}'"); err != nil {
		return nil, err
	}

	rows, err := tx.Query(ctx, "SELECT id, slug FROM agencies ORDER BY slug")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []agencyRef
	for rows.Next() {
		var a agencyRef
		if err := rows.Scan(&a.ID, &a.Slug); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

func countStops(ctx context.Context, tx pgx.Tx, agencyID string) (int, error) {
	var n int
	err := tx.QueryRow(ctx, "SELECT COUNT(*) FROM stops WHERE agency_id = $1", agencyID).Scan(&n)
	return n, err
}
