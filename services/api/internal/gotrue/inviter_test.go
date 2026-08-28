package gotrue

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

func TestInviteUser_UsesInviteEndpointForEmail(t *testing.T) {
	wantID := uuid.New()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/invite" {
			http.Error(w, "email invites must use /invite", http.StatusNotFound)
			return
		}
		if r.Method != http.MethodPost {
			t.Fatalf("method = %s, want POST", r.Method)
		}
		body, err := io.ReadAll(r.Body)
		if err != nil {
			t.Fatalf("read request body: %v", err)
		}
		if string(body) != `{"email":"driver@example.com"}` {
			t.Fatalf("request body = %s", body)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"id":"` + wantID.String() + `"}`))
	}))
	defer server.Close()

	inviter := &Inviter{BaseURL: server.URL, ServiceRoleKey: "test-key", HTTPClient: server.Client()}
	got, err := inviter.InviteUser(t.Context(), "driver@example.com", "")
	if err != nil {
		t.Fatalf("InviteUser() error = %v", err)
	}
	if got != wantID {
		t.Fatalf("InviteUser() id = %s, want %s", got, wantID)
	}
}
