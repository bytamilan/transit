// Package routes reads route rows from the database.
package routes

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Reader loads route rows.
type Reader struct {
	pool *pgxpool.Pool
}

// New returns a route reader backed by pool.
func New(pool *pgxpool.Pool) *Reader {
	return &Reader{pool: pool}
}

// Route is a canonical GTFS route.
type Route struct {
	RouteID        string
	RouteShortName *string
	RouteLongName  *string
	RouteDesc      *string
	RouteType      int
	RouteURL       *string
	RouteColor     *string
	RouteTextColor *string
	RouteSortOrder *int
}

// Params controls listing.
type Params struct {
	AgencyID uuid.UUID
	Limit    int
	Offset   int
}

// List returns routes for an agency.
func (r *Reader) List(ctx context.Context, p Params) ([]Route, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("routes reader not connected to a database")
	}
	rows, err := r.pool.Query(ctx,
		`SELECT * FROM transit.list_routes($1, $2, $3)`,
		p.AgencyID, p.Limit, p.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("query routes: %w", err)
	}
	defer rows.Close()

	var out []Route
	for rows.Next() {
		var rt Route
		if err := rows.Scan(&rt.RouteID, &rt.RouteShortName, &rt.RouteLongName,
			&rt.RouteDesc, &rt.RouteType, &rt.RouteURL, &rt.RouteColor,
			&rt.RouteTextColor, &rt.RouteSortOrder); err != nil {
			return nil, fmt.Errorf("scan route: %w", err)
		}
		out = append(out, rt)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate routes: %w", err)
	}
	return out, nil
}

// Get returns a single route by id.
func (r *Reader) Get(ctx context.Context, agencyID uuid.UUID, routeID string) (*Route, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("routes reader not connected to a database")
	}
	var rt Route
	err := r.pool.QueryRow(ctx,
		`SELECT * FROM transit.get_route($1, $2)`,
		agencyID, routeID,
	).Scan(&rt.RouteID, &rt.RouteShortName, &rt.RouteLongName,
		&rt.RouteDesc, &rt.RouteType, &rt.RouteURL, &rt.RouteColor,
		&rt.RouteTextColor, &rt.RouteSortOrder)
	if err != nil {
		return nil, err
	}
	return &rt, nil
}

// Count returns the total number of routes for an agency.
func (r *Reader) Count(ctx context.Context, agencyID uuid.UUID) (int, error) {
	if r.pool == nil {
		return 0, fmt.Errorf("routes reader not connected to a database")
	}
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT transit.count_routes($1)`, agencyID,
	).Scan(&n)
	if err != nil {
		return 0, err
	}
	return n, nil
}

// Upsert creates or updates a route (the admin routes editor, Phase 6.4).
func (r *Reader) Upsert(ctx context.Context, agencyID uuid.UUID, rt Route) error {
	if r.pool == nil {
		return fmt.Errorf("routes reader not connected to a database")
	}
	_, err := r.pool.Exec(ctx,
		`SELECT transit.upsert_route($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		agencyID, rt.RouteID, rt.RouteShortName, rt.RouteLongName, rt.RouteDesc,
		rt.RouteType, rt.RouteURL, rt.RouteColor, rt.RouteTextColor, rt.RouteSortOrder,
	)
	return err
}

// Delete removes a route.
func (r *Reader) Delete(ctx context.Context, agencyID uuid.UUID, routeID string) error {
	if r.pool == nil {
		return fmt.Errorf("routes reader not connected to a database")
	}
	_, err := r.pool.Exec(ctx, `SELECT transit.delete_route($1, $2)`, agencyID, routeID)
	return err
}
