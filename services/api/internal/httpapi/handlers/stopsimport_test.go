package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/bytamilan/transit/services/api/internal/adapters/osm"
	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
)

const fixtureOverpassJSON = `{
  "elements": [
    {"type": "node", "id": 123, "lat": 1.3500, "lon": 103.8000,
     "tags": {"highway": "bus_stop", "name": "Main St", "ref": "A1", "wheelchair": "yes"}},
    {"type": "node", "id": 456, "lat": 1.3600, "lon": 103.8100,
     "tags": {"public_transport": "platform", "local_ref": "B2"}}
  ]
}`

type fakeOSMFetcher struct {
	status int
	body   string
}

func (f *fakeOSMFetcher) Fetch(ctx context.Context, url string, headers map[string]string) (*http.Response, error) {
	return &http.Response{
		StatusCode: f.status,
		Status:     http.StatusText(f.status),
		Body:       io.NopCloser(strings.NewReader(f.body)),
		Header:     make(http.Header),
	}, nil
}

// stubStopImportStore implements stopImportStore. Candidates whose longitude
// matches nearbyLon get one "existing" hit.
type stubStopImportStore struct {
	nearbyLon    float64
	nearbyStopID string
	upserted     []stops.Stop
	upsertCount  int
}

func (s *stubStopImportStore) UpsertBatch(ctx context.Context, agencyID string, batch []stops.Stop) (int, error) {
	s.upserted = batch
	if s.upsertCount == 0 {
		s.upsertCount = len(batch)
	}
	return s.upsertCount, nil
}

func (s *stubStopImportStore) FindNearby(ctx context.Context, agencyID string, lat, lon, radiusM float64) ([]stops.NearbyStop, error) {
	if lon == s.nearbyLon {
		return []stops.NearbyStop{{StopID: s.nearbyStopID, StopName: "Main St", DistanceM: 3.2}}, nil
	}
	return nil, nil
}

func newStopsImport(store stopImportStore, status int, body string) *StopsImport {
	return &StopsImport{
		Stops:    store,
		Overpass: &osm.Client{BaseURL: "https://overpass.example/api", Fetcher: &fakeOSMFetcher{status: status, body: body}},
	}
}

func fleetManagerRequest(t *testing.T, body string) *http.Request {
	t.Helper()
	req := httptest.NewRequest(http.MethodPost, "/admin/stops/import/osm", strings.NewReader(body))
	actor := auth.Actor{
		UserID:   uuid.New(),
		AgencyID: uuid.MustParse("11111111-1111-1111-1111-111111111111"),
		Roles:    []string{"fleet_manager"},
	}
	return req.WithContext(auth.WithActor(req.Context(), actor))
}

func TestPreviewOSMImport(t *testing.T) {
	store := &stubStopImportStore{nearbyLon: 103.8, nearbyStopID: "existing-stop-1"}
	h := newStopsImport(store, http.StatusOK, fixtureOverpassJSON)

	req := fleetManagerRequest(t, `{"south": 1.2, "west": 103.7, "north": 1.4, "east": 103.9}`)
	rr := httptest.NewRecorder()
	h.PreviewOSMImport(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp struct {
		Items []struct {
			StopID         string `json:"stop_id"`
			Name           string `json:"name"`
			Status         string `json:"status"`
			ExistingStopID string `json:"existing_stop_id"`
		} `json:"items"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(resp.Items) != 2 {
		t.Fatalf("expected 2 items, got %d", len(resp.Items))
	}
	if resp.Items[0].StopID != "osm:node:123" || resp.Items[0].Status != "existing" || resp.Items[0].ExistingStopID != "existing-stop-1" {
		t.Errorf("unexpected first item: %+v", resp.Items[0])
	}
	if resp.Items[1].StopID != "osm:node:456" || resp.Items[1].Status != "new" || resp.Items[1].ExistingStopID != "" {
		t.Errorf("unexpected second item: %+v", resp.Items[1])
	}
	if resp.Items[1].Name != "B2" {
		t.Errorf("expected local_ref fallback name, got %q", resp.Items[1].Name)
	}
}

func TestPreviewOSMImport_InvalidBBox(t *testing.T) {
	h := newStopsImport(&stubStopImportStore{}, http.StatusOK, fixtureOverpassJSON)

	req := fleetManagerRequest(t, `{"south": 1.4, "west": 103.7, "north": 1.2, "east": 103.9}`)
	rr := httptest.NewRecorder()
	h.PreviewOSMImport(rr, req)

	if rr.Code != http.StatusBadRequest {
		t.Fatalf("expected 400, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp errorResponse
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.Error == "" {
		t.Error("expected an error message")
	}
}

func TestPreviewOSMImport_OverpassFailure(t *testing.T) {
	h := newStopsImport(&stubStopImportStore{}, http.StatusBadRequest, "syntax error")

	req := fleetManagerRequest(t, `{"south": 1.2, "west": 103.7, "north": 1.4, "east": 103.9}`)
	rr := httptest.NewRecorder()
	h.PreviewOSMImport(rr, req)

	if rr.Code != http.StatusBadGateway {
		t.Fatalf("expected 502, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestPreviewOSMImport_ForbiddenForRider(t *testing.T) {
	secret := []byte("test-secret")
	mw, _ := auth.NewMiddleware(auth.Config{Mode: "hmac", HMAC: secret, Audience: "authenticated"}, nil)
	h := newStopsImport(&stubStopImportStore{}, http.StatusOK, fixtureOverpassJSON)

	handler := mw.Handler(http.HandlerFunc(h.PreviewOSMImport))
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, signedRequest(t, http.MethodPost, "/admin/stops/import/osm/preview", []string{"rider"}))

	if rr.Code != http.StatusForbidden {
		t.Errorf("expected 403, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestImportOSMStops(t *testing.T) {
	store := &stubStopImportStore{}
	h := &StopsImport{Stops: store}

	req := fleetManagerRequest(t, `{"stops": [
		{"stop_id": "osm:node:123", "name": "Main St", "ref": "A1", "lat": 1.35, "lon": 103.8, "wheelchair_boarding": 1, "platform_code": "1"},
		{"stop_id": "osm:node:456", "lat": 1.36, "lon": 103.81}
	]}`)
	rr := httptest.NewRecorder()
	h.ImportOSMStops(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	var resp struct {
		Rows []struct {
			StopID  string `json:"stop_id"`
			Status  string `json:"status"`
			Message string `json:"message"`
		} `json:"rows"`
		Imported int `json:"imported"`
	}
	if err := json.Unmarshal(rr.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if len(resp.Rows) != 2 {
		t.Fatalf("expected 2 rows, got %d", len(resp.Rows))
	}
	if resp.Rows[0].Status != "ok" {
		t.Errorf("expected first row ok, got %+v", resp.Rows[0])
	}
	if resp.Rows[1].Status != "error" || resp.Rows[1].Message == "" {
		t.Errorf("expected second row error with message, got %+v", resp.Rows[1])
	}
	if resp.Imported != 1 {
		t.Errorf("expected imported=1, got %d", resp.Imported)
	}
	if len(store.upserted) != 1 {
		t.Fatalf("expected 1 stop upserted, got %d", len(store.upserted))
	}
	got := store.upserted[0]
	if got.StopID != "osm:node:123" || got.StopName != "Main St" {
		t.Errorf("unexpected upserted stop: %+v", got)
	}
	if got.StopLat == nil || *got.StopLat != 1.35 || got.StopLon == nil || *got.StopLon != 103.8 {
		t.Errorf("expected coordinates on upserted stop: %+v", got)
	}
	if got.StopCode == nil || *got.StopCode != "A1" {
		t.Errorf("expected ref mapped to stop_code: %+v", got)
	}
	if got.WheelchairBoarding == nil || *got.WheelchairBoarding != 1 {
		t.Errorf("expected wheelchair_boarding=1: %+v", got)
	}
}

func TestImportOSMStops_StoreError(t *testing.T) {
	h := &StopsImport{Stops: &failingStopImportStore{}}

	req := fleetManagerRequest(t, `{"stops": [{"stop_id": "osm:node:1", "name": "X", "lat": 1.0, "lon": 103.0}]}`)
	rr := httptest.NewRecorder()
	h.ImportOSMStops(rr, req)

	if rr.Code != http.StatusInternalServerError {
		t.Fatalf("expected 500, got %d: %s", rr.Code, rr.Body.String())
	}
}

type failingStopImportStore struct{}

func (failingStopImportStore) UpsertBatch(ctx context.Context, agencyID string, batch []stops.Stop) (int, error) {
	return 0, errors.New("db down")
}

func (failingStopImportStore) FindNearby(ctx context.Context, agencyID string, lat, lon, radiusM float64) ([]stops.NearbyStop, error) {
	return nil, errors.New("db down")
}
