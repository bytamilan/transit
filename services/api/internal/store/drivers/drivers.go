// Package drivers reads and writes driver profile rows and grants the
// driver role. Licence numbers are never stored in the clear — callers pass
// the raw number to Upsert and only its SHA-256 hash is persisted.
package drivers

import (
	"context"
	"crypto/sha256"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store reads and writes driver profiles.
type Store struct {
	pool *pgxpool.Pool
}

// New returns a driver store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// Driver is a driver profile.
type Driver struct {
	UserID           uuid.UUID
	DepotID          *uuid.UUID
	DisplayName      *string
	InviteEmail      *string
	InvitePhone      *string
	LicenceRefHash   *string
	LicenceExpiresOn *time.Time
	Status           string
	CreatedAt        time.Time
	UpdatedAt        time.Time
}

// DutyEligible reports whether the driver can be assigned a new duty at now,
// and why not when they cannot. Licence expiry always overrides an "active"
// status — an admin marking a driver active does not un-expire a licence.
func (d Driver) DutyEligible(now time.Time) (bool, string) {
	if d.Status == "suspended" {
		return false, "driver_suspended"
	}
	if d.LicenceExpiresOn != nil && d.LicenceExpiresOn.Before(now) {
		return false, "licence_expired"
	}
	return true, ""
}

// LicenceWarning reports whether the licence expires within warningDays but
// has not yet expired.
func (d Driver) LicenceWarning(now time.Time, warningDays int) bool {
	if d.LicenceExpiresOn == nil || d.LicenceExpiresOn.Before(now) {
		return false
	}
	return d.LicenceExpiresOn.Before(now.AddDate(0, 0, warningDays))
}

// UpsertParams upserts a driver profile by user_id.
type UpsertParams struct {
	AgencyID         uuid.UUID
	UserID           uuid.UUID
	DepotID          *uuid.UUID
	DisplayName      *string
	InviteEmail      *string
	InvitePhone      *string
	LicenceNumber    *string // raw; hashed before storage
	LicenceExpiresOn *time.Time
	Status           string
}

// ListParams controls listing.
type ListParams struct {
	AgencyID uuid.UUID
	DepotID  *uuid.UUID
	Status   *string
	Limit    int
	Offset   int
}

func (s *Store) checkPool() error {
	if s.pool == nil {
		return fmt.Errorf("driver store not connected to a database")
	}
	return nil
}

// HashLicence returns a SHA-256 hex digest of a raw licence number.
func HashLicence(raw string) string {
	h := sha256.Sum256([]byte(raw))
	return fmt.Sprintf("%x", h[:])
}

// Upsert creates or updates a driver profile and returns the user id.
func (s *Store) Upsert(ctx context.Context, p UpsertParams) (uuid.UUID, error) {
	if err := s.checkPool(); err != nil {
		return uuid.Nil, err
	}
	var hash *string
	if p.LicenceNumber != nil && *p.LicenceNumber != "" {
		h := HashLicence(*p.LicenceNumber)
		hash = &h
	}
	status := p.Status
	if status == "" {
		status = "active"
	}
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT transit.upsert_driver_profile($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		p.AgencyID, p.UserID, p.DepotID, p.DisplayName, p.InviteEmail,
		p.InvitePhone, hash, p.LicenceExpiresOn, status,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("upsert driver profile: %w", err)
	}
	if _, err := s.pool.Exec(ctx,
		`SELECT transit.insert_user_role($1, $2, $3, $4)`,
		p.UserID, p.AgencyID, "driver", p.DepotID,
	); err != nil {
		return uuid.Nil, fmt.Errorf("grant driver role: %w", err)
	}
	return id, nil
}

// List returns driver profiles for an agency.
func (s *Store) List(ctx context.Context, p ListParams) ([]Driver, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx,
		`SELECT * FROM transit.list_driver_profiles($1, $2, $3, $4, $5)`,
		p.AgencyID, p.DepotID, p.Status, p.Limit, p.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("query driver profiles: %w", err)
	}
	defer rows.Close()

	var out []Driver
	for rows.Next() {
		d, err := scanDriver(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate driver profiles: %w", err)
	}
	return out, nil
}

// Get returns a single driver profile, or nil if not found.
func (s *Store) Get(ctx context.Context, agencyID, userID uuid.UUID) (*Driver, error) {
	if err := s.checkPool(); err != nil {
		return nil, err
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.get_driver_profile($1, $2)`, agencyID, userID)
	if err != nil {
		return nil, fmt.Errorf("query driver profile: %w", err)
	}
	defer rows.Close()
	if !rows.Next() {
		return nil, nil
	}
	d, err := scanDriver(rows)
	if err != nil {
		return nil, err
	}
	return &d, nil
}

// Count returns the total number of driver profiles matching the filter.
func (s *Store) Count(ctx context.Context, agencyID uuid.UUID, depotID *uuid.UUID, status *string) (int, error) {
	if err := s.checkPool(); err != nil {
		return 0, err
	}
	var n int
	err := s.pool.QueryRow(ctx, `SELECT transit.count_driver_profiles($1, $2, $3)`, agencyID, depotID, status).Scan(&n)
	return n, err
}

// SetStatus suspends or reactivates a driver.
func (s *Store) SetStatus(ctx context.Context, agencyID, userID uuid.UUID, status string) error {
	if err := s.checkPool(); err != nil {
		return err
	}
	d, err := s.Get(ctx, agencyID, userID)
	if err != nil {
		return err
	}
	if d == nil {
		return fmt.Errorf("driver %s not found", userID)
	}
	_, err = s.pool.Exec(ctx,
		`SELECT transit.upsert_driver_profile($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
		agencyID, userID, d.DepotID, d.DisplayName, d.InviteEmail,
		d.InvitePhone, d.LicenceRefHash, d.LicenceExpiresOn, status,
	)
	return err
}

func scanDriver(rows pgx.Rows) (Driver, error) {
	var d Driver
	if err := rows.Scan(&d.UserID, &d.DepotID, &d.DisplayName, &d.InviteEmail, &d.InvitePhone,
		&d.LicenceRefHash, &d.LicenceExpiresOn, &d.Status, &d.CreatedAt, &d.UpdatedAt); err != nil {
		return Driver{}, fmt.Errorf("scan driver profile: %w", err)
	}
	return d, nil
}
