//go:build api_smoke

package main

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/lestrrat-go/jwx/v2/jwa"
	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"
)

const smokeAgencySlug = "demo-metro"

type smokeCase struct {
	name       string
	method     string
	path       string
	body       string
	allowEmpty bool
}

// TestAPIEndpoints exercises every route registered by cmd/server. It is a
// live-stack test: run it with the API container up and API_SMOKE_JWT_SECRET
// set to the API's JWT_SECRET. Requests intentionally use validation errors
// for mutations so this test does not create or delete application data.
func TestAPIEndpoints(t *testing.T) {
	baseURL := strings.TrimRight(strings.TrimSpace(os.Getenv("API_SMOKE_BASE_URL")), "/")
	if baseURL == "" {
		t.Skip("set API_SMOKE_BASE_URL to run the live API smoke test")
	}
	origin := smokeEnvDefault("API_SMOKE_ORIGIN", "http://localhost:3002")
	client := &http.Client{Timeout: 15 * time.Second}
	agencyID := lookupSmokeAgency(t, client, baseURL, origin)
	token := smokeJWT(t, agencyID)

	cases := []smokeCase{
		{name: "auth settings", method: http.MethodGet, path: "/auth/v1/settings"},
		{name: "healthz", method: http.MethodGet, path: "/healthz", allowEmpty: true},
		{name: "readyz", method: http.MethodGet, path: "/readyz"},
		{name: "public agency", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug},
		{name: "public agency config", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/config"},
		{name: "public stops", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/stops"},
		{name: "public stop", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/stops/airport_a"},
		{name: "public routes", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/routes"},
		{name: "public route", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/routes/a1"},
		{name: "public trips", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/trips"},
		{name: "public trip", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/trips/a1_0600"},
		{name: "public stop times", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/trips/a1_0600/stop_times"},
		{name: "public arrivals", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/arrivals?stop_id=terminal_a"},
		{name: "public vehicle positions", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/gtfs-rt/vehicle-positions", allowEmpty: true},
		{name: "public trip updates", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/gtfs-rt/trip-updates", allowEmpty: true},
		{name: "public GBFS discovery", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/gbfs.json"},
		{name: "public GBFS system information", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/gbfs/system_information.json"},
		{name: "agency directory", method: http.MethodGet, path: "/v0/agencies"},
		{name: "trip planner validation", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/plan-trip"},
		{name: "public fares", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/fares"},
		{name: "public alerts", method: http.MethodGet, path: "/v0/agencies/" + smokeAgencySlug + "/alerts"},

		{name: "admin health", method: http.MethodGet, path: "/admin/health"},
		{name: "audit export", method: http.MethodGet, path: "/admin/audit/export"},
		{name: "list API keys", method: http.MethodGet, path: "/admin/api-keys"},
		{name: "create API key validation", method: http.MethodPost, path: "/admin/api-keys", body: `{}`},
		{name: "revoke API key validation", method: http.MethodDelete, path: "/admin/api-keys/not-a-uuid"},
		{name: "API key usage", method: http.MethodGet, path: "/admin/api-keys/usage"},
		{name: "list depots", method: http.MethodGet, path: "/admin/depots"},
		{name: "create depot validation", method: http.MethodPost, path: "/admin/depots", body: `{}`},
		{name: "list vehicles", method: http.MethodGet, path: "/admin/vehicles"},
		{name: "upsert vehicle validation", method: http.MethodPost, path: "/admin/vehicles", body: `{}`},
		{name: "import vehicles validation", method: http.MethodPost, path: "/admin/vehicles/import", body: ""},
		{name: "get vehicle validation", method: http.MethodGet, path: "/admin/vehicles/not-a-uuid"},
		{name: "delete vehicle validation", method: http.MethodDelete, path: "/admin/vehicles/not-a-uuid"},
		{name: "list drivers", method: http.MethodGet, path: "/admin/drivers"},
		{name: "invite driver without inviter", method: http.MethodPost, path: "/admin/drivers", body: `{"email":"smoke-driver@example.com"}`},
		{name: "import drivers validation", method: http.MethodPost, path: "/admin/drivers/import", body: ""},
		{name: "get driver validation", method: http.MethodGet, path: "/admin/drivers/not-a-uuid"},
		{name: "suspend driver validation", method: http.MethodPost, path: "/admin/drivers/not-a-uuid/suspend"},
		{name: "reactivate driver validation", method: http.MethodPost, path: "/admin/drivers/not-a-uuid/reactivate"},
		{name: "list admin routes", method: http.MethodGet, path: "/admin/routes"},
		{name: "upsert route validation", method: http.MethodPost, path: "/admin/routes", body: `{}`},
		{name: "delete admin route", method: http.MethodDelete, path: "/admin/routes/__smoke_missing__", allowEmpty: true},
		{name: "list admin trips", method: http.MethodGet, path: "/admin/trips"},
		{name: "upsert trip validation", method: http.MethodPost, path: "/admin/trips", body: `{}`},
		{name: "delete admin trip", method: http.MethodDelete, path: "/admin/trips/__smoke_missing__", allowEmpty: true},
		{name: "list trip stop times", method: http.MethodGet, path: "/admin/trips/__smoke_missing__/stop_times"},
		{name: "replace trip stop times validation", method: http.MethodPut, path: "/admin/trips/__smoke_missing__/stop_times", body: `{`},
		{name: "list calendars", method: http.MethodGet, path: "/admin/calendars"},
		{name: "upsert calendar validation", method: http.MethodPost, path: "/admin/calendars", body: `{}`},
		{name: "list blocks", method: http.MethodGet, path: "/admin/blocks"},
		{name: "upsert block validation", method: http.MethodPost, path: "/admin/blocks", body: `{}`},
		{name: "list unassigned blocks validation", method: http.MethodGet, path: "/admin/blocks/unassigned"},
		{name: "get block validation", method: http.MethodGet, path: "/admin/blocks/not-a-uuid"},
		{name: "list duty assignments", method: http.MethodGet, path: "/admin/duty-assignments"},
		{name: "create duty assignment validation", method: http.MethodPost, path: "/admin/duty-assignments", body: `{}`},
		{name: "get duty assignment validation", method: http.MethodGet, path: "/admin/duty-assignments/not-a-uuid"},
		{name: "reassign duty validation", method: http.MethodPost, path: "/admin/duty-assignments/not-a-uuid/reassign", body: `{}`},
		{name: "handover duty validation", method: http.MethodPost, path: "/admin/duty-assignments/not-a-uuid/handover", body: `{}`},
		{name: "set duty status validation", method: http.MethodPost, path: "/admin/duty-assignments/not-a-uuid/status", body: `{}`},
		{name: "list duty events validation", method: http.MethodGet, path: "/admin/duty-assignments/not-a-uuid/events"},
		{name: "expand roster validation", method: http.MethodPost, path: "/admin/roster/expand", body: `{}`},
		{name: "dispatch vehicles", method: http.MethodGet, path: "/admin/dispatch/vehicles"},
		{name: "dispatch alerts", method: http.MethodGet, path: "/admin/dispatch/alerts"},
		{name: "assignment pings validation", method: http.MethodGet, path: "/admin/duty-assignments/not-a-uuid/pings"},
		{name: "send dispatch message validation", method: http.MethodPost, path: "/admin/duty-assignments/not-a-uuid/message", body: `{}`},
		{name: "list incidents", method: http.MethodGet, path: "/admin/incidents"},
		{name: "resolve incident validation", method: http.MethodPost, path: "/admin/incidents/not-a-uuid/resolve"},
		{name: "list admin alerts", method: http.MethodGet, path: "/admin/alerts"},
		{name: "create alert validation", method: http.MethodPost, path: "/admin/alerts", body: `{}`},
		{name: "update alert validation", method: http.MethodPut, path: "/admin/alerts/not-a-uuid", body: `{}`},
		{name: "resolve alert validation", method: http.MethodPost, path: "/admin/alerts/not-a-uuid/resolve"},
		{name: "delete alert validation", method: http.MethodDelete, path: "/admin/alerts/not-a-uuid"},

		{name: "driver agency", method: http.MethodGet, path: "/driver/agency"},
		{name: "driver duty", method: http.MethodGet, path: "/driver/duty"},
		{name: "driver duty block validation", method: http.MethodGet, path: "/driver/duty/not-a-uuid/block"},
		{name: "driver confirm validation", method: http.MethodPost, path: "/driver/duty/not-a-uuid/confirm"},
		{name: "driver end validation", method: http.MethodPost, path: "/driver/duty/not-a-uuid/end"},
		{name: "driver pings validation", method: http.MethodPost, path: "/driver/pings", body: `{}`},
		{name: "driver incident validation", method: http.MethodPost, path: "/driver/incidents", body: `{}`},
		{name: "driver messages validation", method: http.MethodGet, path: "/driver/duty/not-a-uuid/messages"},
		{name: "driver messages read validation", method: http.MethodPost, path: "/driver/duty/not-a-uuid/messages/read"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			req, err := http.NewRequest(tc.method, baseURL+tc.path, strings.NewReader(tc.body))
			if err != nil {
				t.Fatal(err)
			}
			req.Header.Set("Origin", origin)
			req.Header.Set("Content-Type", "application/json")
			if tc.path != "/auth/v1/settings" {
				req.Header.Set("Authorization", "Bearer "+token)
			}

			resp, err := client.Do(req)
			if err != nil {
				t.Fatalf("request failed: %v", err)
			}
			defer resp.Body.Close()
			responseBody, err := io.ReadAll(resp.Body)
			if err != nil {
				t.Fatalf("read response: %v", err)
			}
			if resp.StatusCode >= http.StatusInternalServerError {
				t.Fatalf("unexpected server error %d: %s", resp.StatusCode, responseBody)
			}
			if len(responseBody) == 0 && !tc.allowEmpty {
				t.Fatalf("empty response from %s %s", tc.method, tc.path)
			}
			if got := resp.Header.Get("Access-Control-Allow-Origin"); got != origin {
				t.Fatalf("CORS origin = %q, want %q", got, origin)
			}
		})
	}
}

func lookupSmokeAgency(t *testing.T, client *http.Client, baseURL, origin string) string {
	t.Helper()
	req, err := http.NewRequest(http.MethodGet, baseURL+"/v0/agencies/"+smokeAgencySlug, nil)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Origin", origin)
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("lookup agency: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("lookup agency status %d: %s", resp.StatusCode, body)
	}
	var agency struct {
		ID string `json:"id"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&agency); err != nil {
		t.Fatalf("decode agency: %v", err)
	}
	if _, err := uuid.Parse(agency.ID); err != nil {
		t.Fatalf("agency id %q is not a UUID: %v", agency.ID, err)
	}
	return agency.ID
}

func smokeJWT(t *testing.T, agencyID string) string {
	t.Helper()
	secret := smokeEnv(t, "API_SMOKE_JWT_SECRET")
	tok := jwt.New()
	_ = tok.Set(jwt.SubjectKey, uuid.New().String())
	_ = tok.Set("agency_id", agencyID)
	_ = tok.Set("roles", []string{"agency_admin"})
	_ = tok.Set(jwt.AudienceKey, []string{"authenticated"})
	_ = tok.Set(jwt.IssuerKey, smokeEnvDefault("API_SMOKE_JWT_ISSUER", "http://localhost:8000/auth"))
	_ = tok.Set(jwt.ExpirationKey, time.Now().Add(10*time.Minute))
	key, err := jwk.FromRaw([]byte(secret))
	if err != nil {
		t.Fatalf("build smoke JWT key: %v", err)
	}
	signed, err := jwt.Sign(tok, jwt.WithKey(jwa.HS256, key))
	if err != nil {
		t.Fatalf("sign smoke JWT: %v", err)
	}
	return string(signed)
}

func smokeEnv(t *testing.T, key string) string {
	t.Helper()
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		t.Fatalf("%s must be set", key)
	}
	return value
}

func smokeEnvDefault(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}
