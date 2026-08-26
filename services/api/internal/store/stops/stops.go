// Package stops reads stop rows from the database.
package stops

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Reader loads stop rows.
type Reader struct {
	pool *pgxpool.Pool
}

// New returns a stop reader backed by pool.
func New(pool *pgxpool.Pool) *Reader {
	return &Reader{pool: pool}
}

// Stop is a canonical GTFS stop.
type Stop struct {
	StopID             string
	StopCode           *string
	StopName           string
	StopDesc           *string
	StopLat            *float64
	StopLon            *float64
	LocationType       *int
	ParentStation      *string
	WheelchairBoarding *int
	PlatformCode       *string
}

// Params controls listing.
type Params struct {
	AgencyID  uuid.UUID
	Lat       *float64
	Lon       *float64
	RadiusM   *float64
	Limit     int
	Offset    int
}

// List returns stops for an agency, optionally filtered by distance.
func (r *Reader) List(ctx context.Context, p Params) ([]Stop, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("stops reader not connected to a database")
	}
	var lat, lon, radius *float64
	if p.Lat != nil && p.Lon != nil && p.RadiusM != nil {
		lat, lon, radius = p.Lat, p.Lon, p.RadiusM
	}
	rows, err := r.pool.Query(ctx,
		`SELECT * FROM transit.list_stops($1, $2, $3, $4, $5, $6)`,
		p.AgencyID, lat, lon, radius, p.Limit, p.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("query stops: %w", err)
	}
	defer rows.Close()

	var out []Stop
	for rows.Next() {
		var s Stop
		if err := rows.Scan(&s.StopID, &s.StopCode, &s.StopName, &s.StopDesc,
			&s.StopLat, &s.StopLon, &s.LocationType, &s.ParentStation,
			&s.WheelchairBoarding, &s.PlatformCode); err != nil {
			return nil, fmt.Errorf("scan stop: %w", err)
		}
		out = append(out, s)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate stops: %w", err)
	}
	return out, nil
}

// Get returns a single stop by id.
func (r *Reader) Get(ctx context.Context, agencyID uuid.UUID, stopID string) (*Stop, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("stops reader not connected to a database")
	}
	var s Stop
	err := r.pool.QueryRow(ctx,
		`SELECT * FROM transit.get_stop($1, $2)`,
		agencyID, stopID,
	).Scan(&s.StopID, &s.StopCode, &s.StopName, &s.StopDesc,
		&s.StopLat, &s.StopLon, &s.LocationType, &s.ParentStation,
		&s.WheelchairBoarding, &s.PlatformCode)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

// Count returns the total number of stops for an agency.
func (r *Reader) Count(ctx context.Context, agencyID uuid.UUID) (int, error) {
	if r.pool == nil {
		return 0, fmt.Errorf("stops reader not connected to a database")
	}
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT transit.count_stops($1)`, agencyID,
	).Scan(&n)
	if err != nil {
		return 0, err
	}
	return n, nil
}
