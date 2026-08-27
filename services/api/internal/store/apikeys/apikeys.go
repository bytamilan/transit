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

// Key is a looked-up API key, as returned by Lookup (the auth middleware's
// hot path — one row, keyed by hash).
type Key struct {
	ID           uuid.UUID
	AgencyID     uuid.UUID
	Scopes       []string
	RateLimitRPM int
	QuotaDaily   int
	Label        string
}

// APIKey is a full key row, as returned by List (the admin management
// surface) — never carries the hash; the raw key is shown to the caller
// exactly once, at creation.
type APIKey struct {
	ID           uuid.UUID
	Label        string
	Scopes       []string
	RateLimitRPM int
	QuotaDaily   int
	CreatedAt    time.Time
	RevokedAt    *time.Time
}

// Lookup returns a key by its hash, or nil if not found or revoked.
func (s *Store) Lookup(ctx context.Context, hash string) (*Key, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("api key store not connected to a database")
	}
	var k Key
	err := s.pool.QueryRow(ctx,
		`SELECT id, agency_id, scopes, rate_limit_rpm, quota_daily, label FROM transit.api_key_lookup($1)`,
		hash,
	).Scan(&k.ID, &k.AgencyID, &k.Scopes, &k.RateLimitRPM, &k.QuotaDaily, &k.Label)
	if err != nil {
		return nil, err
	}
	return &k, nil
}

// Create issues a new API key, storing only its hash — the raw key is the
// caller's responsibility to hand back to the requester exactly once.
func (s *Store) Create(ctx context.Context, agencyID uuid.UUID, keyHash string, scopes []string, rateLimitRPM, quotaDaily int, label string) (uuid.UUID, error) {
	if s.pool == nil {
		return uuid.Nil, fmt.Errorf("api key store not connected to a database")
	}
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT transit.create_api_key($1, $2, $3, $4, $5, $6)`,
		agencyID, keyHash, scopes, rateLimitRPM, quotaDaily, label,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("create api key: %w", err)
	}
	return id, nil
}

// List returns every API key for an agency, including revoked ones.
func (s *Store) List(ctx context.Context, agencyID uuid.UUID) ([]APIKey, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("api key store not connected to a database")
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.list_api_keys($1)`, agencyID)
	if err != nil {
		return nil, fmt.Errorf("query api keys: %w", err)
	}
	defer rows.Close()

	var out []APIKey
	for rows.Next() {
		var k APIKey
		if err := rows.Scan(&k.ID, &k.Label, &k.Scopes, &k.RateLimitRPM, &k.QuotaDaily, &k.CreatedAt, &k.RevokedAt); err != nil {
			return nil, fmt.Errorf("scan api key: %w", err)
		}
		out = append(out, k)
	}
	return out, rows.Err()
}

// Revoke disables a key; subsequent Lookup calls treat it as not found.
func (s *Store) Revoke(ctx context.Context, agencyID, id uuid.UUID) error {
	if s.pool == nil {
		return fmt.Errorf("api key store not connected to a database")
	}
	_, err := s.pool.Exec(ctx, `SELECT transit.revoke_api_key($1, $2)`, agencyID, id)
	return err
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

// CountUsageSince returns how many usage events a key has recorded since a
// point in time — the daily-quota check's building block.
func (s *Store) CountUsageSince(ctx context.Context, keyID uuid.UUID, since time.Time) (int, error) {
	if s.pool == nil {
		return 0, fmt.Errorf("api key store not connected to a database")
	}
	var count int
	err := s.pool.QueryRow(ctx, `SELECT transit.usage_event_count_since($1, $2)`, keyID, since).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count usage since: %w", err)
	}
	return count, nil
}

// DailyUsage is one day's aggregated usage — the portal usage chart's data point.
type DailyUsage struct {
	Day          time.Time
	Requests     int
	ErrorCount   int
	AvgLatencyMs float64
}

// UsageSummary returns daily usage aggregated across every key in the
// agency, since a given date.
func (s *Store) UsageSummary(ctx context.Context, agencyID uuid.UUID, since time.Time) ([]DailyUsage, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("api key store not connected to a database")
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.usage_summary_by_day($1, $2)`, agencyID, since)
	if err != nil {
		return nil, fmt.Errorf("query usage summary: %w", err)
	}
	defer rows.Close()

	var out []DailyUsage
	for rows.Next() {
		var d DailyUsage
		var avgLatency *float64
		if err := rows.Scan(&d.Day, &d.Requests, &d.ErrorCount, &avgLatency); err != nil {
			return nil, fmt.Errorf("scan usage summary: %w", err)
		}
		if avgLatency != nil {
			d.AvgLatencyMs = *avgLatency
		}
		out = append(out, d)
	}
	return out, rows.Err()
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
