// Package fareproducts reads GTFS fare_products rows — used by
// cmd/exporter; a public fares read path arrives with Phase 11's planner.
package fareproducts

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Reader loads fare products.
type Reader struct {
	pool *pgxpool.Pool
}

// New returns a fare-product reader backed by pool.
func New(pool *pgxpool.Pool) *Reader {
	return &Reader{pool: pool}
}

// FareProduct is one row of fare_products.txt.
type FareProduct struct {
	FareProductID   string
	FareProductName string
	FareMediaID     *string
	Amount          string // numeric(10,2) as text — exact for CSV export, no float rounding
	Currency        string
}

// List returns every fare product for an agency.
func (r *Reader) List(ctx context.Context, agencyID uuid.UUID) ([]FareProduct, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("fare product reader not connected to a database")
	}
	rows, err := r.pool.Query(ctx, `SELECT * FROM transit.list_fare_products($1)`, agencyID)
	if err != nil {
		return nil, fmt.Errorf("query fare products: %w", err)
	}
	defer rows.Close()

	var out []FareProduct
	for rows.Next() {
		var f FareProduct
		if err := rows.Scan(&f.FareProductID, &f.FareProductName, &f.FareMediaID, &f.Amount, &f.Currency); err != nil {
			return nil, fmt.Errorf("scan fare product: %w", err)
		}
		out = append(out, f)
	}
	return out, rows.Err()
}
