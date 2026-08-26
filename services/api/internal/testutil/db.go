// Package testutil provides helpers for Go integration tests against Postgres.
package testutil

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// MustPool returns a connection pool using the DATABASE_URL environment variable.
func MustPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	pool, err := pgxpool.New(context.Background(), env("DATABASE_URL"))
	if err != nil {
		t.Fatalf("connect to test database: %v", err)
	}
	t.Cleanup(func() { pool.Close() })
	return pool
}

// WithClaims returns a connection that has the given JWT claims set for the
// duration of a transaction. Callers must commit/rollback the returned Tx.
func WithClaims(ctx context.Context, t *testing.T, pool *pgxpool.Pool, claims string) pgx.Tx {
	t.Helper()
	tx, err := pool.Begin(ctx)
	if err != nil {
		t.Fatalf("begin tx: %v", err)
	}
	escaped := strings.ReplaceAll(claims, "'", "''")
	if _, err := tx.Exec(ctx, fmt.Sprintf("SET LOCAL request.jwt.claims = '%s'", escaped)); err != nil {
		_ = tx.Rollback(ctx)
		t.Fatalf("set jwt claims: %v", err)
	}
	return tx
}

// ClaimsJSON builds a claim payload from role and agency_id.
func ClaimsJSON(role, agencyID string) string {
	return fmt.Sprintf(`{"role": %q, "agency_id": %q}`, role, agencyID)
}

func env(key string) string {
	v := os.Getenv(key)
	if v == "" {
		panic(fmt.Sprintf("%s is required", key))
	}
	return v
}
