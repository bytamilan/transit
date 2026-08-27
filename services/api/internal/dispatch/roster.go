package dispatch

import (
	"context"
	"fmt"
	"net"
	"time"

	"github.com/google/uuid"

	"github.com/bytamilan/transit/services/api/internal/store/blocks"
)

// RosterEntry is one line of a recurring weekly pattern: on this weekday, run
// this block with this driver and vehicle. TripIDs is the ordered trip list
// for the block — the caller resolves it once (e.g. from the trips already
// filtered by block_id in the routes editor) since it's the same for every
// occurrence of the pattern.
type RosterEntry struct {
	Weekday   time.Weekday
	BlockRef  string
	TripIDs   []string
	DriverID  uuid.UUID
	VehicleID uuid.UUID
}

// ExpandParams describes a recurring roster to apply across a date range.
type ExpandParams struct {
	AgencyID uuid.UUID
	From     time.Time
	To       time.Time
	Entries  []RosterEntry
	ActorID  uuid.UUID
	IP       net.IP
}

// ExpandRow is the outcome of one (entry, date) occurrence.
type ExpandRow struct {
	ServiceDate  time.Time  `json:"service_date"`
	BlockRef     string     `json:"block_ref"`
	AssignmentID *uuid.UUID `json:"assignment_id,omitempty"`
	Conflicts    []Conflict `json:"conflicts,omitempty"`
}

// ExpandRoster materialises a block for each (entry, matching weekday) pair
// in [From, To] and attempts to assign it. A row with conflicts is skipped —
// it does not roll back or block any other row in the batch, so a partially
// conflicting week still gets everything else scheduled.
func (s *Service) ExpandRoster(ctx context.Context, p ExpandParams) ([]ExpandRow, error) {
	if p.To.Before(p.From) {
		return nil, fmt.Errorf("roster range end %s is before start %s", p.To, p.From)
	}

	var out []ExpandRow
	for d := p.From; !d.After(p.To); d = d.AddDate(0, 0, 1) {
		for _, entry := range p.Entries {
			if entry.Weekday != d.Weekday() {
				continue
			}

			blockID, err := s.Blocks.Upsert(ctx, blocks.UpsertParams{
				AgencyID: p.AgencyID, BlockRef: entry.BlockRef, ServiceDate: d, TripIDs: entry.TripIDs,
			})
			if err != nil {
				return nil, fmt.Errorf("materialise block %s on %s: %w", entry.BlockRef, d.Format("2006-01-02"), err)
			}

			result, err := s.Assign(ctx, p.AgencyID, blockID, entry.DriverID, entry.VehicleID, d, p.ActorID, p.IP)
			if err != nil {
				return nil, fmt.Errorf("assign block %s on %s: %w", entry.BlockRef, d.Format("2006-01-02"), err)
			}

			row := ExpandRow{ServiceDate: d, BlockRef: entry.BlockRef, Conflicts: result.Conflicts}
			if result.AssignmentID != uuid.Nil {
				row.AssignmentID = &result.AssignmentID
			}
			out = append(out, row)
		}
	}
	return out, nil
}
