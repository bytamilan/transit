package planner

// FareProduct is the planner's minimal view of a GTFS fare_products row.
type FareProduct struct {
	FareProductID   string
	FareProductName string
	Amount          string // numeric(10,2) as text — exact, no float rounding (see internal/store/fareproducts)
	Currency        string
}

// Scope reduction: this schema has no GTFS-Fares V2 fare_leg_rules or
// fare_transfer_rules tables (fare_products.txt only — see
// infra/supabase/migrations/0003_gtfs_core.sql), so there is no way to
// compute which fare product applies to a specific set of legs, or to sum
// a real per-itinerary total. Every itinerary is annotated with the
// agency's full fare_products list as-is (Plan's fares parameter, attached
// directly to Itinerary.FareProducts) — "these are the fares this agency
// charges," not "this trip costs X." A real fare computation needs
// fare_leg_rules-equivalent data this codebase doesn't model yet.
