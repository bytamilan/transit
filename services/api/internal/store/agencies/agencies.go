// Package agencies reads agency metadata from the database.
package agencies

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Reader loads agency rows.
type Reader struct {
	pool *pgxpool.Pool
}

// New returns an agency reader backed by pool.
func New(pool *pgxpool.Pool) *Reader {
	return &Reader{pool: pool}
}

// Agency is a public agency row.
type Agency struct {
	ID       uuid.UUID
	Slug     string
	Name     map[string]string
	Timezone string
	Config   map[string]any
}

// LookupBySlug returns an agency by slug, or nil if not found.
func (r *Reader) LookupBySlug(ctx context.Context, slug string) (*Agency, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("agency reader not connected to a database")
	}
	var id uuid.UUID
	var nameJSON, configJSON []byte
	var outSlug, timezone string
	err := r.pool.QueryRow(ctx,
		`SELECT id, slug, name, timezone, config FROM transit.get_agency_by_slug($1)`,
		slug,
	).Scan(&id, &outSlug, &nameJSON, &timezone, &configJSON)
	if err != nil {
		return nil, err
	}

	var name map[string]string
	if err := json.Unmarshal(nameJSON, &name); err != nil {
		return nil, fmt.Errorf("unmarshal name: %w", err)
	}
	var config map[string]any
	if err := json.Unmarshal(configJSON, &config); err != nil {
		return nil, fmt.Errorf("unmarshal config: %w", err)
	}

	return &Agency{ID: id, Slug: slug, Name: name, Timezone: timezone, Config: config}, nil
}

// LookupByID returns an agency by id, or nil if not found.
func (r *Reader) LookupByID(ctx context.Context, id uuid.UUID) (*Agency, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("agency reader not connected to a database")
	}
	var outID uuid.UUID
	var nameJSON, configJSON []byte
	var slug, timezone string
	err := r.pool.QueryRow(ctx,
		`SELECT id, slug, name, timezone, config FROM transit.get_agency_by_id($1)`,
		id,
	).Scan(&outID, &slug, &nameJSON, &timezone, &configJSON)
	if err != nil {
		return nil, err
	}

	var name map[string]string
	if err := json.Unmarshal(nameJSON, &name); err != nil {
		return nil, fmt.Errorf("unmarshal name: %w", err)
	}
	var config map[string]any
	if err := json.Unmarshal(configJSON, &config); err != nil {
		return nil, fmt.Errorf("unmarshal config: %w", err)
	}

	return &Agency{ID: outID, Slug: slug, Name: name, Timezone: timezone, Config: config}, nil
}
