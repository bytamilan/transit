// Package dispatchmessages implements dispatcher<->driver messaging.
// Polled, not pushed — there is no FCM/APNs plumbing in this codebase yet;
// the driver app checks for new messages alongside its existing ping-flush
// tick (see docs/PHASE_PLAN.md Phase 9).
package dispatchmessages

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Store reads and writes dispatch_messages rows.
type Store struct {
	pool *pgxpool.Pool
}

// New returns a dispatch-message store backed by pool.
func New(pool *pgxpool.Pool) *Store {
	return &Store{pool: pool}
}

// Message is one dispatcher-to-driver message.
type Message struct {
	ID        uuid.UUID
	SenderID  uuid.UUID
	Body      string
	CreatedAt time.Time
	ReadAt    *time.Time
}

// Send creates a message for a duty assignment and returns its id.
func (s *Store) Send(ctx context.Context, agencyID, assignmentID, senderID uuid.UUID, body string) (uuid.UUID, error) {
	if s.pool == nil {
		return uuid.Nil, fmt.Errorf("dispatch message store not connected to a database")
	}
	var id uuid.UUID
	err := s.pool.QueryRow(ctx,
		`SELECT transit.send_dispatch_message($1, $2, $3, $4)`,
		agencyID, assignmentID, senderID, body,
	).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("send dispatch message: %w", err)
	}
	return id, nil
}

// ListForAssignment returns messages for an assignment, oldest first.
func (s *Store) ListForAssignment(ctx context.Context, agencyID, assignmentID uuid.UUID, unreadOnly bool) ([]Message, error) {
	if s.pool == nil {
		return nil, fmt.Errorf("dispatch message store not connected to a database")
	}
	rows, err := s.pool.Query(ctx, `SELECT * FROM transit.list_dispatch_messages($1, $2, $3)`, agencyID, assignmentID, unreadOnly)
	if err != nil {
		return nil, fmt.Errorf("query dispatch messages: %w", err)
	}
	defer rows.Close()

	var out []Message
	for rows.Next() {
		var m Message
		if err := rows.Scan(&m.ID, &m.SenderID, &m.Body, &m.CreatedAt, &m.ReadAt); err != nil {
			return nil, fmt.Errorf("scan dispatch message: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// MarkRead marks every unread message for an assignment as read.
func (s *Store) MarkRead(ctx context.Context, agencyID, assignmentID uuid.UUID) error {
	if s.pool == nil {
		return fmt.Errorf("dispatch message store not connected to a database")
	}
	_, err := s.pool.Exec(ctx, `SELECT transit.mark_dispatch_messages_read($1, $2)`, agencyID, assignmentID)
	return err
}
