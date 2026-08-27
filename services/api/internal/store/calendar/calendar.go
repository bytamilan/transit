// Package calendar reads and writes GTFS service calendar rows.
package calendar

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Reader loads and writes calendar rows.
type Reader struct {
	pool *pgxpool.Pool
}

// New returns a calendar reader backed by pool.
func New(pool *pgxpool.Pool) *Reader {
	return &Reader{pool: pool}
}

// Calendar is a canonical GTFS service calendar.
type Calendar struct {
	ServiceID string
	Monday    bool
	Tuesday   bool
	Wednesday bool
	Thursday  bool
	Friday    bool
	Saturday  bool
	Sunday    bool
	StartDate time.Time
	EndDate   time.Time
}

// List returns every calendar for an agency.
func (r *Reader) List(ctx context.Context, agencyID uuid.UUID) ([]Calendar, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("calendar reader not connected to a database")
	}
	rows, err := r.pool.Query(ctx, `SELECT * FROM transit.list_calendars($1)`, agencyID)
	if err != nil {
		return nil, fmt.Errorf("query calendars: %w", err)
	}
	defer rows.Close()

	var out []Calendar
	for rows.Next() {
		var c Calendar
		if err := rows.Scan(&c.ServiceID, &c.Monday, &c.Tuesday, &c.Wednesday, &c.Thursday,
			&c.Friday, &c.Saturday, &c.Sunday, &c.StartDate, &c.EndDate); err != nil {
			return nil, fmt.Errorf("scan calendar: %w", err)
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

// DateException is one row of calendar_dates.txt.
type DateException struct {
	ServiceID     string
	Date          time.Time
	ExceptionType int // 1 = added, 2 = removed
}

// ListDateExceptions returns every calendar_dates row for an agency — used
// by cmd/exporter; calendar_dates.txt is optional in GTFS and most feeds
// (including the demo seed data) have none.
func (r *Reader) ListDateExceptions(ctx context.Context, agencyID uuid.UUID) ([]DateException, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("calendar reader not connected to a database")
	}
	rows, err := r.pool.Query(ctx, `SELECT * FROM transit.list_calendar_dates($1)`, agencyID)
	if err != nil {
		return nil, fmt.Errorf("query calendar dates: %w", err)
	}
	defer rows.Close()

	var out []DateException
	for rows.Next() {
		var d DateException
		if err := rows.Scan(&d.ServiceID, &d.Date, &d.ExceptionType); err != nil {
			return nil, fmt.Errorf("scan calendar date: %w", err)
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// Upsert creates or updates a service calendar.
func (r *Reader) Upsert(ctx context.Context, agencyID uuid.UUID, c Calendar) error {
	if r.pool == nil {
		return fmt.Errorf("calendar reader not connected to a database")
	}
	_, err := r.pool.Exec(ctx,
		`SELECT transit.upsert_calendar($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
		agencyID, c.ServiceID, c.Monday, c.Tuesday, c.Wednesday, c.Thursday,
		c.Friday, c.Saturday, c.Sunday, c.StartDate, c.EndDate,
	)
	return err
}
