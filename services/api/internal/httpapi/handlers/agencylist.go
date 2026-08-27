package handlers

import (
	"log/slog"
	"net/http"
	"sort"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
)

// AgencyList serves a platform-wide agency directory. It exists for the
// portal's public /datasets page (Phase 10) — nothing in contracts/openapi.yaml
// needs it, so it's hand-mounted rather than generated, same as GBFS and
// GTFS-RT.
type AgencyList struct {
	Agencies *agencies.Reader
}

type datasetAgency struct {
	Slug        string   `json:"slug"`
	Name        string   `json:"name"`
	Timezone    string   `json:"timezone"`
	Modes       []string `json:"modes"`
	LicenseSPDX string   `json:"license_spdx"`
	Attribution string   `json:"attribution"`
	TermsURL    *string  `json:"terms_url,omitempty"`
}

// List returns every agency's public directory entry: name, timezone,
// modes and licence/attribution, for a data-portal listing page. Fetches
// full config per agency (N+1 queries) — acceptable for a low-traffic,
// small-cardinality directory page, not a hot path.
func (h *AgencyList) List(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	refs, err := h.Agencies.ListAll(ctx)
	if err != nil {
		internalError(w, "list agencies", err)
		return
	}

	out := make([]datasetAgency, 0, len(refs))
	for _, ref := range refs {
		agency, err := h.Agencies.LookupBySlug(ctx, ref.Slug)
		if err != nil {
			slog.Error("lookup agency for directory", "slug", ref.Slug, "err", err)
			continue
		}
		cfg, err := configFromMap(agency.Config)
		if err != nil {
			slog.Error("parse agency config for directory", "slug", ref.Slug, "err", err)
			continue
		}
		out = append(out, datasetAgency{
			Slug:        agency.Slug,
			Name:        primaryName(agency.Name),
			Timezone:    agency.Timezone,
			Modes:       cfg.Modes,
			LicenseSPDX: cfg.License.Spdx,
			Attribution: cfg.License.Attribution,
			TermsURL:    cfg.License.TermsUrl,
		})
	}
	writeJSON(w, http.StatusOK, out)
}

// primaryName picks a deterministic display name from a locale-keyed name
// map: "en" if present, else the alphabetically-first locale key — Go's map
// iteration order is randomized, so a bare "first entry" pick would make
// this endpoint's output flap between requests.
func primaryName(name map[string]string) string {
	if v, ok := name["en"]; ok {
		return v
	}
	keys := make([]string, 0, len(name))
	for k := range name {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	if len(keys) == 0 {
		return ""
	}
	return name[keys[0]]
}
