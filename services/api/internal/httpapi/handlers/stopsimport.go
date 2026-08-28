package handlers

import (
	"context"
	"errors"
	"log/slog"
	"net/http"

	"github.com/bytamilan/transit/services/api/internal/adapters/osm"
	"github.com/bytamilan/transit/services/api/internal/httpapi/auth"
	"github.com/bytamilan/transit/services/api/internal/httpapi/rbac"
	"github.com/bytamilan/transit/services/api/internal/store/audit"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
)

// previewMatchRadiusM is the radius around an OSM candidate that flags it as
// already present in the agency's stops during preview.
const previewMatchRadiusM = 25.0

// stopImportStore is the slice of store/stops.Writer the import handlers
// need. Declared as an interface so tests can stub the database — the same
// pattern as driverInviter in fleet.go.
type stopImportStore interface {
	UpsertBatch(ctx context.Context, agencyID string, batch []stops.Stop) (int, error)
	FindNearby(ctx context.Context, agencyID string, lat, lon, radiusM float64) ([]stops.NearbyStop, error)
}

// StopsImport implements the admin OSM bus-stop import endpoints: a preview
// that fetches candidates from the Overpass API and flags duplicates, and a
// confirm step that bulk-upserts the selected candidates into the canonical
// stops table.
type StopsImport struct {
	Stops    stopImportStore
	Overpass *osm.Client
	Audit    *audit.Writer
}

func (h *StopsImport) audit(actor auth.Actor, action, entity string, before, after map[string]any) {
	if h.Audit == nil {
		return
	}
	entry := audit.Entry{AgencyID: actor.AgencyID, ActorID: actor.UserID, Action: action, Entity: entity, Before: before, After: after, IP: actor.IP}
	if err := h.Audit.Write(context.Background(), entry); err != nil {
		slog.Error("stops import: failed to write audit log entry", "action", action, "entity", entity, "err", err)
	}
}

type osmPreviewInput struct {
	South float64 `json:"south"`
	West  float64 `json:"west"`
	North float64 `json:"north"`
	East  float64 `json:"east"`
}

type osmPreviewItem struct {
	StopID             string  `json:"stop_id"`
	Name               string  `json:"name"`
	Ref                string  `json:"ref"`
	Lat                float64 `json:"lat"`
	Lon                float64 `json:"lon"`
	WheelchairBoarding int     `json:"wheelchair_boarding"`
	PlatformCode       string  `json:"platform_code"`
	Status             string  `json:"status"`
	ExistingStopID     string  `json:"existing_stop_id"`
}

// PreviewOSMImport fetches bus stops inside a bounding box from the Overpass
// API and flags candidates that already exist near the same location.
func (h *StopsImport) PreviewOSMImport(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	var in osmPreviewInput
	if !decodeJSON(w, r, &in) {
		return
	}
	query, err := osm.BuildBusStopQuery(in.South, in.West, in.North, in.East)
	if err != nil {
		var bboxErr *osm.BBoxError
		if errors.As(err, &bboxErr) {
			writeJSON(w, http.StatusBadRequest, errorResponse{Error: err.Error()})
			return
		}
		internalError(w, "build overpass query", err)
		return
	}
	candidates, err := h.Overpass.FetchBusStops(r.Context(), query)
	if err != nil {
		slog.Error("overpass fetch failed", "err", err)
		writeJSON(w, http.StatusBadGateway, errorResponse{Error: err.Error()})
		return
	}
	items := make([]osmPreviewItem, 0, len(candidates))
	for _, c := range candidates {
		item := osmPreviewItem{
			StopID: c.StopID, Name: c.Name, Ref: c.Ref, Lat: c.Lat, Lon: c.Lon,
			WheelchairBoarding: c.WheelchairBoarding, PlatformCode: c.PlatformCode,
			Status: "new",
		}
		nearby, err := h.Stops.FindNearby(r.Context(), actor.AgencyID.String(), c.Lat, c.Lon, previewMatchRadiusM)
		if err != nil {
			internalError(w, "find nearby stops", err)
			return
		}
		if len(nearby) > 0 {
			item.Status = "existing"
			item.ExistingStopID = nearby[0].StopID
		}
		items = append(items, item)
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

type osmImportStopInput struct {
	StopID             string   `json:"stop_id"`
	Name               string   `json:"name"`
	Ref                string   `json:"ref"`
	Lat                *float64 `json:"lat"`
	Lon                *float64 `json:"lon"`
	WheelchairBoarding int      `json:"wheelchair_boarding"`
	PlatformCode       string   `json:"platform_code"`
}

type osmImportRowResult struct {
	StopID  string `json:"stop_id"`
	Status  string `json:"status"`
	Message string `json:"message,omitempty"`
}

// ImportOSMStops bulk-upserts the OSM candidates the admin confirmed in the
// preview. Rows that fail validation are reported per-row instead of
// aborting the import, mirroring the fleet CSV import report.
func (h *StopsImport) ImportOSMStops(w http.ResponseWriter, r *http.Request) {
	actor := auth.FromContext(r.Context())
	if !requirePermission(w, actor, rbac.PermFleetWrite) {
		return
	}
	var in struct {
		Stops []osmImportStopInput `json:"stops"`
	}
	if !decodeJSON(w, r, &in) {
		return
	}
	report := make([]osmImportRowResult, 0, len(in.Stops))
	batch := make([]stops.Stop, 0, len(in.Stops))
	for _, s := range in.Stops {
		if s.StopID == "" || s.Name == "" || s.Lat == nil || s.Lon == nil {
			report = append(report, osmImportRowResult{StopID: s.StopID, Status: "error", Message: "stop_id, name, lat and lon are required"})
			continue
		}
		wheelchair := s.WheelchairBoarding
		batch = append(batch, stops.Stop{
			StopID: s.StopID, StopCode: nonEmptyPtr(s.Ref), StopName: s.Name,
			StopLat: s.Lat, StopLon: s.Lon,
			WheelchairBoarding: &wheelchair, PlatformCode: nonEmptyPtr(s.PlatformCode),
		})
		report = append(report, osmImportRowResult{StopID: s.StopID, Status: "ok"})
	}
	imported, err := h.Stops.UpsertBatch(r.Context(), actor.AgencyID.String(), batch)
	if err != nil {
		internalError(w, "import osm stops", err)
		return
	}
	h.audit(actor, "import_osm_stops", "stops", nil, map[string]any{"imported": imported})
	writeJSON(w, http.StatusOK, map[string]any{"rows": report, "imported": imported})
}
