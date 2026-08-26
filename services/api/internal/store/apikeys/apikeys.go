// Package apikeys provides API-key authentication and usage-event recording.
package apikeys

import (
	"context"
	"crypto/sha256"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store loads keys and records usage.
type Store struct {
	pool *pgxpool.Pool
}

// New returns an api-key store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// Key is a looked-up API key.
type Key struct {
	ID           uuid.UUID
	AgencyID     uuid.UUID
	Scopes       []string
	RateLimitRPM int
	QuotaDaily   int
}

// Lookup returns a key by its hash, or nil if not found.
func (s *Store) Lookup(ctx context.Context, hash string) (*Key, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("api key store not connected to a database")
	}
	var k Key
	err := s.pool.QueryRow(ctx,
		`SELECT id, agency_id, scopes, rate_limit_rpm, quota_daily FROM transit.api_key_lookup($1)`,
		hash,
	).Scan(&k.ID, &k.AgencyID, &k.Scopes, &k.RateLimitRPM, &k.QuotaDaily)
	if err != nil {
		return nil, err
	}
	return &k, nil
}

// RecordUsage inserts a usage event.
func (s *Store) RecordUsage(ctx context.Context, keyID uuid.UUID, endpoint string, status, latencyMs int) error {
	if s.pool == nil {
		return fmt.Errorf("api key store not connected to a database")
	}
	_, err := s.pool.Exec(ctx,
		`SELECT transit.usage_event_insert($1, $2, $3, $4)`,
		keyID, endpoint, status, latencyMs,
	)
	return err
}

// HashKey returns a SHA-256 hex string for the raw key.
func HashKey(raw string) string {
	h := sha256.Sum256([]byte(raw))
	return fmt.Sprintf("%x", h[:])
}

// UsageWindowStart returns the start of the current quota window.
func UsageWindowStart() time.Time {
	return time.Now().UTC().Truncate(24 * time.Hour)
}
