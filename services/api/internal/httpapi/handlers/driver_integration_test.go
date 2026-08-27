//go:build integration

package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"
	"github.com/lestrrat-go/jwx/v2/jwa"
	"github.com/lestrrat-go/jwx/v2/jwk"
	"github.com/lestrrat-go/jwx/v2/jwt"

	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/blocks"
	"github.com/bytamilan/transit/services/api/internal/store/drivers"
	"github.com/bytamilan/transit/services/api/internal/store/duty"
	"github.com/bytamilan/transit/services/api/internal/store/incidents"
	"github.com/bytamilan/transit/services/api/internal/store/pings"
	"github.com/bytamilan/transit/services/api/internal/store/vehicles"
	"github.com/bytamilan/transit/services/api/internal/testutil"
)

func driverJWT(t *testing.T, secret []byte, agencyID, userID uuid.UUID) string {
	t.Helper()
	tok := jwt.New()
	_ = tok.Set(jwt.SubjectKey, userID.String())
	_ = tok.Set("agency_id", agencyID.String())
	_ = tok.Set("roles", []string{"driver"})
	_ = tok.Set(jwt.AudienceKey, []string{"authenticated"})
	key, _ := jwk.FromRaw(secret)
	signed, _ := jwt.Sign(tok, jwt.WithKey(jwa.HS256, key))
	return string(signed)
}

func TestDriverFlow_ConfirmSubmitPingsEnd(t *testing.T) {
	pool := testutil.MustPool(t)
	ctx := context.Background()

	ag := agencies.New(pool)
	agency, err := ag.LookupBySlug(ctx, "demo-metro")
	if err != nil || agency == nil {
		t.Fatalf("lookup demo-metro: %v", err)
	}

	vehicleStore := vehicles.New(pool)
	driverStore := drivers.New(pool)
	blockStore := blocks.New(pool)
	dutyStore := duty.New(pool)

	vehicleID, err := vehicleStore.Upsert(ctx, vehicles.UpsertParams{
		AgencyID: agency.ID, FleetNo: "V-DRIVERFLOW", Registration: "REG-DRIVERFLOW", Status: "active",
	})
	if err != nil {
		t.Fatalf("create vehicle: %v", err)
	}
	driverID := uuid.New()
	if _, err := driverStore.Upsert(ctx, drivers.UpsertParams{AgencyID: agency.ID, UserID: driverID, Status: "active"}); err != nil {
		t.Fatalf("create driver: %v", err)
	}
	otherDriverID := uuid.New()
	if _, err := driverStore.Upsert(ctx, drivers.UpsertParams{AgencyID: agency.ID, UserID: otherDriverID, Status: "active"}); err != nil {
		t.Fatalf("create other driver: %v", err)
	}

	serviceDate := time.Date(2026, 4, 6, 0, 0, 0, 0, time.UTC)
	blockID, err := blockStore.Upsert(ctx, blocks.UpsertParams{AgencyID: agency.ID, BlockRef: "blk_driverflow", ServiceDate: serviceDate})
	if err != nil {
		t.Fatalf("create block: %v", err)
	}
	assignmentID, err := dutyStore.Create(ctx, agency.ID, blockID, driverID, vehicleID, serviceDate, uuid.New())
	if err != nil {
		t.Fatalf("create assignment: %v", err)
	}

	secret := []byte("test-secret")
	mw, err := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, pool)
	if err != nil {
		t.Fatalf("build auth middleware: %v", err)
	}
	d := &Driver{Agencies: ag, Duty: dutyStore, Pings: pings.New(pool), Incidents: incidents.New(pool)}

	r := chi.NewRouter()
	r.Group(func(r chi.Router) {
		r.Use(mw.Handler)
		r.Post("/driver/duty/{id}/confirm", d.ConfirmDuty)
		r.Post("/driver/duty/{id}/end", d.EndDuty)
		r.Post("/driver/pings", d.SubmitPings)
	})

	authHeader := func(userID uuid.UUID) string { return "Bearer " + driverJWT(t, secret, agency.ID, userID) }

	// Confirm own duty.
	confirmReq := httptest.NewRequest(http.MethodPost, "/driver/duty/"+assignmentID.String()+"/confirm", nil)
	confirmReq.Header.Set("Authorization", authHeader(driverID))
	confirmRec := httptest.NewRecorder()
	r.ServeHTTP(confirmRec, confirmReq)
	if confirmRec.Code != http.StatusNoContent {
		t.Fatalf("confirm duty: expected 204, got %d: %s", confirmRec.Code, confirmRec.Body.String())
	}

	// Submitting pings against the now-open duty succeeds.
	pingBody, _ := json.Marshal(map[string]any{
		"pings": []map[string]any{
			{"assignment_id": assignmentID.String(), "ts": time.Now().UTC().Format(time.RFC3339), "lat": 1.3, "lon": 103.8},
		},
	})
	pingReq := httptest.NewRequest(http.MethodPost, "/driver/pings", bytes.NewReader(pingBody))
	pingReq.Header.Set("Authorization", authHeader(driverID))
	pingReq.Header.Set("Content-Type", "application/json")
	pingRec := httptest.NewRecorder()
	r.ServeHTTP(pingRec, pingReq)
	if pingRec.Code != http.StatusNoContent {
		t.Fatalf("submit own pings: expected 204, got %d: %s", pingRec.Code, pingRec.Body.String())
	}

	// The other driver may not submit pings against this assignment.
	otherPingReq := httptest.NewRequest(http.MethodPost, "/driver/pings", bytes.NewReader(pingBody))
	otherPingReq.Header.Set("Authorization", authHeader(otherDriverID))
	otherPingReq.Header.Set("Content-Type", "application/json")
	otherPingRec := httptest.NewRecorder()
	r.ServeHTTP(otherPingRec, otherPingReq)
	if otherPingRec.Code != http.StatusForbidden {
		t.Fatalf("submit pings for another driver's duty: expected 403, got %d: %s", otherPingRec.Code, otherPingRec.Body.String())
	}

	// The other driver may not end this assignment either.
	otherEndReq := httptest.NewRequest(http.MethodPost, "/driver/duty/"+assignmentID.String()+"/end", nil)
	otherEndReq.Header.Set("Authorization", authHeader(otherDriverID))
	otherEndRec := httptest.NewRecorder()
	r.ServeHTTP(otherEndRec, otherEndReq)
	if otherEndRec.Code != http.StatusNotFound {
		t.Fatalf("end another driver's duty: expected 404, got %d: %s", otherEndRec.Code, otherEndRec.Body.String())
	}

	// The owning driver can end it.
	endReq := httptest.NewRequest(http.MethodPost, "/driver/duty/"+assignmentID.String()+"/end", nil)
	endReq.Header.Set("Authorization", authHeader(driverID))
	endRec := httptest.NewRecorder()
	r.ServeHTTP(endRec, endReq)
	if endRec.Code != http.StatusNoContent {
		t.Fatalf("end own duty: expected 204, got %d: %s", endRec.Code, endRec.Body.String())
	}
}
