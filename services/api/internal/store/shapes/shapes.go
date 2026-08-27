// Package shapes reads GTFS shape points — used only by cmd/exporter; the
// public API has no shapes endpoint yet (see driver_app's DutyBlockLoader
// and internal/tracking, which both fall back to straight lines between
// stops for the same reason).
package shapes

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Reader loads shape points.
type Reader struct {
	pool *pgxpool.Pool
}

// New returns a shape reader backed by pool.
func New(pool *pgxpool.Pool) *Reader {
	return &Reader{pool: pool}
}

// Point is one row of shapes.txt.
type Point struct {
	ShapeID      string
	Lat          float64
	Lon          float64
	Sequence     int
	DistTraveled *float64
}

// List returns every shape point for an agency, ordered by shape then sequence.
func (r *Reader) List(ctx context.Context, agencyID uuid.UUID) ([]Point, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("shape reader not connected to a database")
	}
	rows, err := r.pool.Query(ctx, `SELECT * FROM transit.list_shapes($1)`, agencyID)
	if err != nil {
		return nil, fmt.Errorf("query shapes: %w", err)
	}
	defer rows.Close()

	var out []Point
	for rows.Next() {
		var p Point
		if err := rows.Scan(&p.ShapeID, &p.Lat, &p.Lon, &p.Sequence, &p.DistTraveled); err != nil {
			return nil, fmt.Errorf("scan shape point: %w", err)
		}
		out = append(out, p)
	}
	return out, rows.Err()
}
