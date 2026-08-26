// Package audit writes append-only rows to transit.audit_log.
package audit

import (
	"context"
	"encoding/json"
	"fmt"
	"net"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Writer inserts audit rows. It uses a SECURITY DEFINER function because the
// API connects as transit_app, whose JWT claim does not match any RLS role.
type Writer struct {
	pool *pgxpool.Pool
}

// New returns an audit writer backed by pool.
func New(pool *pgxpool.Pool) *Writer {
	return &Writer{pool: pool}
}

// Entry is a single audit-log row.
type Entry struct {
	AgencyID uuid.UUID
	ActorID  uuid.UUID
	Action   string // e.g. "insert", "update", "delete", "export"
	Entity   string // e.g. "stops", "driver_profiles", "duty_assignments"
	Before   map[string]any
	After    map[string]any
	IP       net.IP
}

// Write persists an audit row. nil before/after are stored as SQL NULL.
func (w *Writer) Write(ctx context.Context, e Entry) error {
	if w.pool == nil {
		return fmt.Errorf("audit writer not connected to a database")
	}
	before, err := toJSONB(e.Before)
	if err != nil {
		return fmt.Errorf("marshal before: %w", err)
	}
	after, err := toJSONB(e.After)
	if err != nil {
		return fmt.Errorf("marshal after: %w", err)
	}

	_, err = w.pool.Exec(ctx,
		`SELECT transit.audit_log_insert($1, $2, $3, $4, $5, $6, $7)`,
		e.AgencyID, e.ActorID, e.Action, e.Entity, before, after, e.IP,
	)
	return err
}

func toJSONB(v map[string]any) ([]byte, error) {
	if v == nil {
		return []byte("null"), nil
	}
	return json.Marshal(v)
}
