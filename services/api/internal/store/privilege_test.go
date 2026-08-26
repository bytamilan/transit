//go:build integration

package store

import (
	"context"
	"fmt"
	"testing"

	"github.com/bytamilan/transit/services/api/internal/testutil"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// TestPrivilegeEscalation proves the Phase 2 security gates:
//   1. A user cannot escalate by writing their own user_metadata.
//   2. A driver token cannot write agency data.
//   3. A depot-scoped dispatcher cannot read driver profiles in another depot.
func TestPrivilegeEscalation(t *testing.T) {
	ctx := context.Background()
	pool := testutil.MustPool(t)

	agencies, err := listAgencies(ctx, pool)
	if err != nil {
		t.Fatalf("list agencies: %v", err)
	}
	if len(agencies) != 2 {
		t.Fatalf("expected 2 seeded agencies, got %d", len(agencies))
	}
	var agencyA string
	for _, a := range agencies {
		if a.Slug == "demo-metro" {
			agencyA = a.ID
			break
		}
	}
	if agencyA == "" {
		t.Fatalf("demo-metro not found in %+v", agencies)
	}

	t.Run("user_metadata_role_spoof_does_not_grant_write", func(t *testing.T) {
		claims := fmt.Sprintf(
			`{"role": "driver", "agency_id": %q, "user_metadata": {"role": "agency_admin"}}`,
			agencyA,
		)
		tx := testutil.WithClaims(ctx, t, pool, claims)
		defer func() { _ = tx.Rollback(ctx) }()

		_, err := tx.Exec(ctx, `
			INSERT INTO stops (agency_id, stop_id, stop_name, stop_lat, stop_lon, location_type)
			VALUES ($1, 'spoof_stop', 'Spoof Stop', 0, 0, 0)
		`, agencyA)
		if err == nil {
			t.Fatal("expected driver insert denied despite user_metadata spoof, but it succeeded")
		}
	})

	t.Run("driver_cannot_read_other_agency_stops", func(t *testing.T) {
		// Find agency B.
		var agencyB string
		for _, a := range agencies {
			if a.Slug == "demo-transit" {
				agencyB = a.ID
				break
			}
		}
		tx := testutil.WithClaims(ctx, t, pool, testutil.ClaimsJSON("driver", agencyA))
		defer func() { _ = tx.Rollback(ctx) }()

		var n int
		err := tx.QueryRow(ctx, "SELECT COUNT(*) FROM stops WHERE agency_id = $1", agencyB).Scan(&n)
		if err != nil {
			t.Fatalf("count stops: %v", err)
		}
		if n != 0 {
			t.Fatalf("expected 0 stops for cross-agency driver, got %d", n)
		}
	})

	t.Run("depot_dispatcher_cannot_read_other_depot_profiles", func(t *testing.T) {
		d1, _, _, driverD1, driverD2 := setupDepotScenario(ctx, t, pool, agencyA)

		// Act as a dispatcher scoped to depot d1.
		claims := fmt.Sprintf(
			`{"role": "dispatcher", "agency_id": %q, "depot_id": %q}`,
			agencyA, d1,
		)
		tx := testutil.WithClaims(ctx, t, pool, claims)
		defer func() { _ = tx.Rollback(ctx) }()

		rows, err := tx.Query(ctx, `
			SELECT user_id::text FROM driver_profiles
			WHERE agency_id = $1
			ORDER BY user_id
		`, agencyA)
		if err != nil {
			t.Fatalf("query driver_profiles: %v", err)
		}
		defer rows.Close()

		var seen []string
		for rows.Next() {
			var uid string
			if err := rows.Scan(&uid); err != nil {
				t.Fatalf("scan driver user_id: %v", err)
			}
			seen = append(seen, uid)
		}
		if err := rows.Err(); err != nil {
			t.Fatalf("rows err: %v", err)
		}

		if len(seen) != 1 || seen[0] != driverD1 {
			t.Fatalf("expected exactly driver %s (depot %s), got %v", driverD1, d1, seen)
		}

		// A dispatcher from d1 must also not be able to write a driver profile
		// in d2. RLS means the UPDATE affects zero rows rather than raising an
		// error, so we assert on the row count.
		tag, err := tx.Exec(ctx, `
			UPDATE driver_profiles
			SET status = 'suspended'
			WHERE agency_id = $1 AND user_id = $2::uuid
		`, agencyA, driverD2)
		if err != nil {
			t.Fatalf("unexpected update error: %v", err)
		}
		if tag.RowsAffected() != 0 {
			t.Fatalf("expected dispatcher update to affect 0 rows, got %d", tag.RowsAffected())
		}
	})
}

// setupDepotScenario creates two depots, two drivers (one per depot), and a
// dispatcher scoped to the first depot. It commits the setup so the RLS test
// can run in a fresh transaction. Cleanup is registered with t.Cleanup so
// partial failures do not leave rows behind.
func setupDepotScenario(ctx context.Context, t *testing.T, pool *pgxpool.Pool, agencyID string) (d1, d2, dispatcher, driverD1, driverD2 string) {
	t.Helper()

	d1 = uuid.New().String()
	d2 = uuid.New().String()
	dispatcher = uuid.New().String()
	driverD1 = uuid.New().String()
	driverD2 = uuid.New().String()
	depotNameA := "North " + d1[:8]
	depotNameB := "South " + d2[:8]

	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin setup tx: %v", err)
	}
	defer func() {
		if err != nil {
			_ = tx.Rollback(ctx)
		}
	}()

	if _, err := tx.Exec(ctx, "SET LOCAL request.jwt.claims = '{\"role\": \"super_admin\"}'"); err != nil {
		t.Fatalf("set super_admin claims: %v", err)
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO depots (id, agency_id, name)
		VALUES ($1::uuid, $2::uuid, $3),
		       ($4::uuid, $2::uuid, $5)
	`, d1, agencyID, depotNameA, d2, depotNameB); err != nil {
		t.Fatalf("insert depots: %v", err)
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO user_roles (user_id, agency_id, role, depot_id)
		VALUES ($1::uuid, $2::uuid, 'dispatcher', $3::uuid),
		       ($4::uuid, $2::uuid, 'driver', $3::uuid),
		       ($5::uuid, $2::uuid, 'driver', $6::uuid)
	`, dispatcher, agencyID, d1, driverD1, driverD2, d2); err != nil {
		t.Fatalf("insert user_roles: %v", err)
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO driver_profiles (user_id, agency_id, depot_id, status)
		VALUES ($1::uuid, $2::uuid, $3::uuid, 'active'),
		       ($4::uuid, $2::uuid, $5::uuid, 'active')
	`, driverD1, agencyID, d1, driverD2, d2); err != nil {
		t.Fatalf("insert driver_profiles: %v", err)
	}

	if err := tx.Commit(ctx); err != nil {
		t.Fatalf("commit setup: %v", err)
	}

	t.Cleanup(func() { cleanupDepotScenario(ctx, t, pool, agencyID, dispatcher, driverD1, driverD2) })
	return
}

func cleanupDepotScenario(ctx context.Context, t *testing.T, pool *pgxpool.Pool, agencyID, dispatcher, driverD1, driverD2 string) {
	t.Helper()
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin cleanup tx: %v", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx, "SET LOCAL request.jwt.claims = '{\"role\": \"super_admin\"}'"); err != nil {
		t.Fatalf("set super_admin claims: %v", err)
	}

	for _, uid := range []string{dispatcher, driverD1, driverD2} {
		if _, err := tx.Exec(ctx, `DELETE FROM user_roles WHERE user_id = $1::uuid`, uid); err != nil {
			t.Fatalf("delete user_roles: %v", err)
		}
	}
	if _, err := tx.Exec(ctx, `DELETE FROM driver_profiles WHERE agency_id = $1::uuid`, agencyID); err != nil {
		t.Fatalf("delete driver_profiles: %v", err)
	}
	if _, err := tx.Exec(ctx, `DELETE FROM depots WHERE agency_id = $1::uuid`, agencyID); err != nil {
		t.Fatalf("delete depots: %v", err)
	}
	if err := tx.Commit(ctx); err != nil {
		t.Fatalf("commit cleanup: %v", err)
	}
}
