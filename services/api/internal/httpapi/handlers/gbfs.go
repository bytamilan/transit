package handlers

import (
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
)

// GBFS implements a minimal GBFS (General Bikeshare Feed Specification)
// stub — brief §10 task 5: "GBFS endpoint stub where micromobility modes
// are configured". Only the discovery file and system_information are
// implemented; station_information/status and vehicle data need an actual
// micromobility fleet data model this codebase doesn't have yet, so this
// stays a stub rather than a full GBFS publisher.
type GBFS struct {
	Agencies *agencies.Reader
}

var micromobilityModes = map[string]bool{"bike": true, "scooter": true, "moped": true}

func hasMicromobilityMode(config map[string]any) bool {
	modes, _ := config["modes"].([]any)
	for _, m := range modes {
		if s, ok := m.(string); ok && micromobilityModes[s] {
			return true
		}
	}
	return false
}

func (h *GBFS) lookupMicromobilityAgency(w http.ResponseWriter, r *http.Request) *agencies.Agency {
	slug := chi.URLParam(r, "slug")
	agency, err := h.Agencies.LookupBySlug(r.Context(), slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return nil
		}
		internalError(w, "lookup agency", err)
		return nil
	}
	if !hasMicromobilityMode(agency.Config) {
		writeJSON(w, http.StatusNotFound, errorResponse{Error: "this agency has no micromobility modes configured"})
		return nil
	}
	return agency
}

// Discovery serves gbfs.json, the GBFS auto-discovery manifest.
func (h *GBFS) Discovery(w http.ResponseWriter, r *http.Request) {
	agency := h.lookupMicromobilityAgency(w, r)
	if agency == nil {
		return
	}
	lang := primaryGBFSLanguage(agency.Config)
	base := "/v0/agencies/" + agency.Slug + "/gbfs"
	writeJSON(w, http.StatusOK, map[string]any{
		"last_updated": time.Now().UTC().Format(time.RFC3339),
		"ttl":          3600,
		"version":      "2.3",
		"data": map[string]any{
			lang: map[string]any{
				"feeds": []map[string]any{
					{"name": "system_information", "url": base + "/system_information.json"},
				},
			},
		},
	})
}

// SystemInformation serves the one non-stub GBFS feed file.
func (h *GBFS) SystemInformation(w http.ResponseWriter, r *http.Request) {
	agency := h.lookupMicromobilityAgency(w, r)
	if agency == nil {
		return
	}
	lang := primaryGBFSLanguage(agency.Config)
	writeJSON(w, http.StatusOK, map[string]any{
		"last_updated": time.Now().UTC().Format(time.RFC3339),
		"ttl":          3600,
		"version":      "2.3",
		"data": map[string]any{
			"system_id": agency.Slug,
			"language":  lang,
			"name":      agency.Name[lang],
			"timezone":  agency.Timezone,
		},
	})
}

func primaryGBFSLanguage(config map[string]any) string {
	locales, _ := config["locales"].([]any)
	if len(locales) > 0 {
		if s, ok := locales[0].(string); ok {
			return s
		}
	}
	return "en"
}
