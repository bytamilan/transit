package handlers

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/fareproducts"
)

// Fares serves the public, unauthenticated fare read: GET
// /v0/agencies/{slug}/fares. Hand-mounted like GBFS/AgencyList/GTFS-RT —
// not part of the OpenAPI contract. See internal/planner/fares.go for why
// this is a flat list of the agency's fare products rather than a
// per-itinerary computed total: the schema has no GTFS-Fares V2 rule
// tables to compute one from.
type Fares struct {
	Agencies *agencies.Reader
	Store    *fareproducts.Reader
}

// List returns every fare product for the agency.
func (h *Fares) List(w http.ResponseWriter, r *http.Request) {
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

	rows, err := h.Store.List(ctx, agency.ID)
	if err != nil {
		internalError(w, "list fare products", err)
		return
	}
	out := make([]fareProductResponse, 0, len(rows))
	for _, fp := range rows {
		out = append(out, fareProductResponse{
			FareProductID: fp.FareProductID, Name: fp.FareProductName, Amount: fp.Amount, Currency: fp.Currency,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": out})
}
