// Package servicealerts reads and writes admin-authored GTFS-RT service
// alerts (Phase 11): the /admin authoring queue, the public rider-facing
// read, and the exporter's GTFS-RT feed all go through this store.
package servicealerts

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store reads and writes service_alerts rows.
type Store struct {
	pool *pgxpool.Pool
}

// New returns a service alert store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// Alert is one service alert. HeaderText/DescriptionText/URL are locale ->
// text maps ({"en": "...", "ta": "..."}), the same shape as an agency's
// name — an empty InformedRoutes and InformedStops means the alert applies
// agency-wide.
type Alert struct {
	ID              uuid.UUID
	Cause           string
	Effect          string
	HeaderText      map[string]string
	DescriptionText map[string]string
	URL             map[string]string
	InformedRoutes  []string
	InformedStops   []string
	ActiveFrom      time.Time
	ActiveUntil     *time.Time
	CreatedBy       *uuid.UUID
	CreatedAt       time.Time
	UpdatedAt       time.Time
	ResolvedAt      *time.Time
}

// Upsert creates or updates an alert. A nil ID creates a new alert; a
// non-nil ID updates the existing one (scoped to agencyID, so an id from
// another agency silently updates nothing — callers should treat a
// zero-row outcome the same as "not found", the same as everywhere else in
// this codebase's admin write paths).
func (s *Store) Upsert(ctx context.Context, agencyID uuid.UUID, id *uuid.UUID, a Alert, createdBy *uuid.UUID) (uuid.UUID, error) {
	if s.pool == nil {
		return uuid.Nil, fmt.Errorf("service alert store not connected to a database")
	}
	header, err := toJSONB(a.HeaderText)
	if err != nil {
		return uuid.Nil, fmt.Errorf("marshal header_text: %w", err)
	}
	description, err := toJSONB(a.DescriptionText)
	if err != nil {
		return uuid.Nil, fmt.Errorf("marshal description_text: %w", err)
	}
	url, err := toJSONBOrNull(a.URL)
	if err != nil {
		return uuid.Nil, fmt.Errorf("marshal url: %w", err)
	}

	var out uuid.UUID
	err = s.pool.QueryRow(ctx,
		`SELECT transit.upsert_service_alert($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`,
		agencyID, id, a.Cause, a.Effect, header, description, url,
		a.InformedRoutes, a.InformedStops, a.ActiveFrom, a.ActiveUntil, createdBy,
	).Scan(&out)
	if err != nil {
		return uuid.Nil, fmt.Errorf("upsert service alert: %w", err)
	}
	return out, nil
}

// List returns alerts for an agency. activeOnly restricts to unresolved
// alerts whose active window contains now(); the admin queue passes false
// to see everything including resolved history.
func (s *Store) List(ctx context.Context, agencyID uuid.UUID, activeOnly bool) ([]Alert, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("service alert store not connected to a database")
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.list_service_alerts($1, $2)`, agencyID, activeOnly)
	if err != nil {
		return nil, fmt.Errorf("query service alerts: %w", err)
	}
	defer rows.Close()

	var out []Alert
	for rows.Next() {
		var a Alert
		var header, description []byte
		var url []byte
		if err := rows.Scan(
			&a.ID, &a.Cause, &a.Effect, &header, &description, &url,
			&a.InformedRoutes, &a.InformedStops, &a.ActiveFrom, &a.ActiveUntil,
			&a.CreatedBy, &a.CreatedAt, &a.UpdatedAt, &a.ResolvedAt,
		); err != nil {
			return nil, fmt.Errorf("scan service alert: %w", err)
		}
		if err := json.Unmarshal(header, &a.HeaderText); err != nil {
			return nil, fmt.Errorf("unmarshal header_text: %w", err)
		}
		if err := json.Unmarshal(description, &a.DescriptionText); err != nil {
			return nil, fmt.Errorf("unmarshal description_text: %w", err)
		}
		if url != nil {
			if err := json.Unmarshal(url, &a.URL); err != nil {
				return nil, fmt.Errorf("unmarshal url: %w", err)
			}
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// Resolve marks an alert resolved (stops it appearing in active reads).
func (s *Store) Resolve(ctx context.Context, agencyID, id uuid.UUID) error {
	if s.pool == nil {
		return fmt.Errorf("service alert store not connected to a database")
	}
	_, err := s.pool.Exec(ctx, `SELECT transit.resolve_service_alert($1, $2)`, agencyID, id)
	return err
}

// Delete permanently removes an alert.
func (s *Store) Delete(ctx context.Context, agencyID, id uuid.UUID) error {
	if s.pool == nil {
		return fmt.Errorf("service alert store not connected to a database")
	}
	_, err := s.pool.Exec(ctx, `SELECT transit.delete_service_alert($1, $2)`, agencyID, id)
	return err
}

func toJSONB(m map[string]string) ([]byte, error) {
	if m == nil {
		return json.Marshal(map[string]string{})
	}
	return json.Marshal(m)
}

func toJSONBOrNull(m map[string]string) ([]byte, error) {
	if len(m) == 0 {
		return nil, nil
	}
	return json.Marshal(m)
}
