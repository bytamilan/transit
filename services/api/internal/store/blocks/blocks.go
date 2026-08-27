// Package blocks reads and writes GTFS block realisations for a service date.
package blocks

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store reads and writes blocks.
type Store struct {
	pool *pgxpool.Pool
}

// New returns a block store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// Block is a block_id realised for one service date.
type Block struct {
	ID          uuid.UUID
	BlockRef    string
	ServiceDate time.Time
	TripIDs     []string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Span is a block's scheduled start/end instant, derived from its trips'
// stop_times and localised to the agency's timezone.
type Span struct {
	StartsAt time.Time
	EndsAt   time.Time
}

// UpsertParams upserts a block by (agency, block_ref, service_date).
type UpsertParams struct {
	AgencyID    uuid.UUID
	BlockRef    string
	ServiceDate time.Time
	TripIDs     []string
}

// ListParams controls listing.
type ListParams struct {
	AgencyID    uuid.UUID
	ServiceDate *time.Time
	Limit       int
	Offset      int
}

func (s *Store) checkPool() error {
	if s.pool == nil {
		return fmt.Errorf("block store not connected to a database")
	}
	return nil
}

// Upsert creates or updates a block and returns its id.
func (s *Store) Upsert(ctx context.Context, p UpsertParams) (uuid.UUID, error) {
	if err := s.checkPool(); err != nil {
		return uuid.Nil, err
	}
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT transit.upsert_block($1, $2, $3, $4)`,
		p.AgencyID, p.BlockRef, p.ServiceDate, p.TripIDs,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("upsert block: %w", err)
	}
	return id, nil
}

// List returns blocks for an agency.
func (s *Store) List(ctx context.Context, p ListParams) ([]Block, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx,
		`SELECT * FROM transit.list_blocks($1, $2, $3, $4)`,
		p.AgencyID, p.ServiceDate, p.Limit, p.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("query blocks: %w", err)
	}
	defer rows.Close()

	var out []Block
	for rows.Next() {
		b, err := scanBlock(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate blocks: %w", err)
	}
	return out, nil
}

// Get returns a single block, or nil if not found.
func (s *Store) Get(ctx context.Context, agencyID, id uuid.UUID) (*Block, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.get_block($1, $2)`, agencyID, id)
	if err != nil {
		return nil, fmt.Errorf("query block: %w", err)
	}
	defer rows.Close()
	if !rows.Next() {
		return nil, nil
	}
	b, err := scanBlock(rows)
	if err != nil {
		return nil, err
	}
	return &b, nil
}

// Count returns the total number of blocks matching the filter.
func (s *Store) Count(ctx context.Context, agencyID uuid.UUID, serviceDate *time.Time) (int, error) {
	if err := s.checkPool(); err != nil {
		return 0, err
	}
	var n int
	err := s.pool.QueryRow(ctx, `SELECT transit.count_blocks($1, $2)`, agencyID, serviceDate).Scan(&n)
	return n, err
}

// Unassigned returns blocks on serviceDate with no live duty assignment.
func (s *Store) Unassigned(ctx context.Context, agencyID uuid.UUID, serviceDate time.Time) ([]Block, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx, `SELECT id, block_ref, service_date, trip_ids FROM transit.list_unassigned_blocks($1, $2)`,
		agencyID, serviceDate)
	if err != nil {
		return nil, fmt.Errorf("query unassigned blocks: %w", err)
	}
	defer rows.Close()

	var out []Block
	for rows.Next() {
		var b Block
		if err := rows.Scan(&b.ID, &b.BlockRef, &b.ServiceDate, &b.TripIDs); err != nil {
			return nil, fmt.Errorf("scan unassigned block: %w", err)
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

// TimeSpan returns the block's scheduled start/end instant, or nil if it has
// no trips with stop_times.
func (s *Store) TimeSpan(ctx context.Context, agencyID, blockID uuid.UUID) (*Span, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	var span Span
	err := s.pool.QueryRow(ctx, `SELECT starts_at, ends_at FROM transit.block_time_span($1, $2)`, agencyID, blockID).
		Scan(&span.StartsAt, &span.EndsAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("block time span: %w", err)
	}
	return &span, nil
}

func scanBlock(rows pgx.Rows) (Block, error) {
	var b Block
	if err := rows.Scan(&b.ID, &b.BlockRef, &b.ServiceDate, &b.TripIDs, &b.CreatedAt, &b.UpdatedAt); err != nil {
		return Block{}, fmt.Errorf("scan block: %w", err)
	}
	return b, nil
}
