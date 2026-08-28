// Package gotrue calls Supabase Auth's (GoTrue) admin API to create and
// invite driver accounts. It is used only server-side by the admin API — the
// service-role key it holds is never sent to a client.
package gotrue

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/google/uuid"
)

// Inviter creates a Supabase Auth user for a newly invited driver and
// triggers GoTrue's invite email when an address is given.
type Inviter struct {
	BaseURL        string // e.g. http://localhost:8000/auth/v1
	ServiceRoleKey string
	HTTPClient     *http.Client
}

// NewInviter returns an Inviter, or nil if baseURL/serviceRoleKey are empty —
// callers should treat a nil Inviter as "invite by email/phone unavailable;
// the caller must supply an existing user_id instead".
func NewInviter(baseURL, serviceRoleKey string) *Inviter {
	if baseURL == "" || serviceRoleKey == "" {
		return nil
	}
	return &Inviter{BaseURL: baseURL, ServiceRoleKey: serviceRoleKey, HTTPClient: &http.Client{Timeout: 10 * time.Second}}
}

type adminUserResponse struct {
	ID string `json:"id"`
}

// InviteUser creates the GoTrue user and, when email is set, sends GoTrue's
// invite email. At least one of email/phone must be non-empty.
func (i *Inviter) InviteUser(ctx context.Context, email, phone string) (uuid.UUID, error) {
	if email == "" && phone == "" {
		return uuid.Nil, fmt.Errorf("invite requires an email or phone")
	}

	// GoTrue's /invite endpoint creates the unconfirmed user and sends the
	// invitation email in one operation. Creating the user through
	// /admin/users first makes /invite fail with a duplicate-user error.
	if email != "" {
		user, err := i.post(ctx, "/invite", map[string]any{"email": email})
		if err != nil {
			return uuid.Nil, fmt.Errorf("send invite email: %w", err)
		}
		return parseUserID(user)
	}

	body := map[string]any{}
	if phone != "" {
		body["phone"] = phone
		body["phone_confirm"] = false
	}

	user, err := i.post(ctx, "/admin/users", body)
	if err != nil {
		return uuid.Nil, fmt.Errorf("create gotrue user: %w", err)
	}
	return parseUserID(user)
}

func parseUserID(user *adminUserResponse) (uuid.UUID, error) {
	id, err := uuid.Parse(user.ID)
	if err != nil {
		return uuid.Nil, fmt.Errorf("parse gotrue user id: %w", err)
	}
	return id, nil
}

func (i *Inviter) post(ctx context.Context, path string, body map[string]any) (*adminUserResponse, error) {
	payload, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, i.BaseURL+path, bytes.NewReader(payload))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+i.ServiceRoleKey)
	req.Header.Set("apikey", i.ServiceRoleKey)

	resp, err := i.HTTPClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 300 {
		return nil, fmt.Errorf("gotrue %s returned %d", path, resp.StatusCode)
	}

	var out adminUserResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode gotrue response: %w", err)
	}
	return &out, nil
}
