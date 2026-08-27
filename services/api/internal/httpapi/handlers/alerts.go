package handlers

import (
	"net/http"
	"sort"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/servicealerts"
)

// Alerts serves the public, unauthenticated rider-facing alert read: GET
// /v0/agencies/{slug}/alerts. Hand-mounted like GBFS/AgencyList/GTFS-RT —
// not part of the OpenAPI contract (see their doc comments for why).
type Alerts struct {
	Agencies *agencies.Reader
	Store    *servicealerts.Store
}

type publicAlertResponse struct {
	ID              string   `json:"id"`
	Cause           string   `json:"cause"`
	Effect          string   `json:"effect"`
	HeaderText      string   `json:"header_text"`
	DescriptionText string   `json:"description_text,omitempty"`
	URL             string   `json:"url,omitempty"`
	Locale          string   `json:"locale"`
	InformedRoutes  []string `json:"informed_routes,omitempty"`
	InformedStops   []string `json:"informed_stops,omitempty"`
	ActiveFrom      string   `json:"active_from"`
	ActiveUntil     *string  `json:"active_until,omitempty"`
}

// List returns every currently-active alert for the agency, with header/
// description/url text resolved to a single locale — ?locale= if given and
// the alert has that translation, else the same "en" else
// alphabetically-first fallback used everywhere else text is picked from a
// locale map in this codebase (see selectLocale).
func (h *Alerts) List(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	slug := chi.URLParam(r, "slug")
	agency, err := h.Agencies.LookupBySlug(ctx, slug)
	if err != nil {
		if err == pgx.ErrNoRows {
			writeJSON(w, http.StatusNotFound, errorResponse{Error: "agency not found"})
			return
		}
		internalError(w, "lookup agency", err)
		return
	}

	rows, err := h.Store.List(ctx, agency.ID, true)
	if err != nil {
		internalError(w, "list service alerts", err)
		return
	}

	requested := r.URL.Query().Get("locale")
	out := make([]publicAlertResponse, 0, len(rows))
	for _, a := range rows {
		locale, header := selectLocale(a.HeaderText, requested)
		_, description := selectLocale(a.DescriptionText, requested)
		_, url := selectLocale(a.URL, requested)
		resp := publicAlertResponse{
			ID: a.ID.String(), Cause: a.Cause, Effect: a.Effect,
			HeaderText: header, DescriptionText: description, URL: url, Locale: locale,
			InformedRoutes: a.InformedRoutes, InformedStops: a.InformedStops,
			ActiveFrom: a.ActiveFrom.Format(rfc3339),
		}
		if a.ActiveUntil != nil {
			s := a.ActiveUntil.Format(rfc3339)
			resp.ActiveUntil = &s
		}
		out = append(out, resp)
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}

const rfc3339 = "2006-01-02T15:04:05Z07:00"

// selectLocale picks text from a locale map: the requested locale if
// present, else "en", else the alphabetically-first key (deterministic —
// Go map iteration order is randomized) — same fallback rule as
// agencylist.go's primaryName and exporter/gtfs.go's primaryLocale.
func selectLocale(m map[string]string, requested string) (locale, text string) {
	if requested != "" {
		if v, ok := m[requested]; ok {
			return requested, v
		}
	}
	if v, ok := m["en"]; ok {
		return "en", v
	}
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	if len(keys) == 0 {
		return "", ""
	}
	return keys[0], m[keys[0]]
}
