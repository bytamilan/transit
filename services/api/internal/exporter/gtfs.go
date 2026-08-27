// Package exporter builds a standards-compliant GTFS.zip from the
// canonical tables (brief §5, §9 — "manual" adapter agencies emit their
// first-ever GTFS feed this way, but every agency's export goes through the
// same path regardless of adapter). cmd/exporter calls this on a schedule.
package exporter

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/csv"
	"fmt"
	"sort"
	"strconv"
	"time"

	"github.com/google/uuid"

	"github.com/bytamilan/transit/services/api/internal/store/agencies"
	"github.com/bytamilan/transit/services/api/internal/store/calendar"
	"github.com/bytamilan/transit/services/api/internal/store/fareproducts"
	"github.com/bytamilan/transit/services/api/internal/store/routes"
	"github.com/bytamilan/transit/services/api/internal/store/shapes"
	"github.com/bytamilan/transit/services/api/internal/store/stops"
	"github.com/bytamilan/transit/services/api/internal/store/trips"
)

// maxExportRows is passed as the LIMIT to every List call — those methods
// exist for the paginated public API, so a very large limit is how this
// batch job asks for "everything". Fine at the scale a self-hosted agency
// (the target deployment, per the brief) actually reaches; a feed that
// outgrows this needs streaming export, a later optimisation.
const maxExportRows = 1_000_000

// Sources bundles every store reader BuildGTFSZip needs.
type Sources struct {
	Agencies     *agencies.Reader
	Stops        *stops.Reader
	Routes       *routes.Reader
	Trips        *trips.Reader
	Calendar     *calendar.Reader
	Shapes       *shapes.Reader
	FareProducts *fareproducts.Reader
}

// BuildGTFSZip queries every canonical GTFS table for one agency and
// returns a zipped feed. Optional files (calendar_dates, shapes,
// fare_products) are omitted entirely when the agency has no rows for
// them — GTFS permits this, and demo/seed data typically has none.
func (s Sources) BuildGTFSZip(ctx context.Context, agencyID uuid.UUID) ([]byte, error) {
	agency, err := s.Agencies.LookupByID(ctx, agencyID)
	if err != nil {
		return nil, fmt.Errorf("lookup agency: %w", err)
	}
	if agency == nil {
		return nil, fmt.Errorf("agency %s not found", agencyID)
	}

	buf := &bytes.Buffer{}
	zw := zip.NewWriter(buf)

	if err := writeAgency(zw, agency); err != nil {
		return nil, err
	}
	if err := s.writeStops(ctx, zw, agencyID); err != nil {
		return nil, err
	}
	if err := s.writeRoutes(ctx, zw, agencyID); err != nil {
		return nil, err
	}
	tripRows, err := s.Trips.List(ctx, trips.Params{AgencyID: agencyID, Limit: maxExportRows})
	if err != nil {
		return nil, fmt.Errorf("list trips: %w", err)
	}
	if err := writeTrips(zw, tripRows); err != nil {
		return nil, err
	}
	if err := s.writeStopTimes(ctx, zw, agencyID, tripRows); err != nil {
		return nil, err
	}
	if err := s.writeCalendar(ctx, zw, agencyID); err != nil {
		return nil, err
	}
	if err := s.writeCalendarDates(ctx, zw, agencyID); err != nil {
		return nil, err
	}
	if err := s.writeShapes(ctx, zw, agencyID); err != nil {
		return nil, err
	}
	if err := s.writeFareProducts(ctx, zw, agencyID); err != nil {
		return nil, err
	}

	if err := zw.Close(); err != nil {
		return nil, fmt.Errorf("close zip: %w", err)
	}
	return buf.Bytes(), nil
}

func writeAgency(zw *zip.Writer, agency *agencies.Agency) error {
	lang := primaryLocale(agency.Name)
	name := agency.Name[lang]
	return writeCSVFile(zw, "agency.txt",
		[]string{"agency_id", "agency_name", "agency_url", "agency_timezone", "agency_lang"},
		[][]string{{agency.Slug, name, agencyURL(agency.Config, agency.Slug), agency.Timezone, lang}},
	)
}

func (s Sources) writeStops(ctx context.Context, zw *zip.Writer, agencyID uuid.UUID) error {
	list, err := s.Stops.List(ctx, stops.Params{AgencyID: agencyID, Limit: maxExportRows})
	if err != nil {
		return fmt.Errorf("list stops: %w", err)
	}
	rows := make([][]string, len(list))
	for i, st := range list {
		rows[i] = []string{
			st.StopID, strOrEmpty(st.StopCode), st.StopName, strOrEmpty(st.StopDesc),
			floatOrEmpty(st.StopLat), floatOrEmpty(st.StopLon), intOrEmpty(st.LocationType),
			strOrEmpty(st.ParentStation), intOrEmpty(st.WheelchairBoarding), strOrEmpty(st.PlatformCode),
		}
	}
	return writeCSVFile(zw, "stops.txt",
		[]string{"stop_id", "stop_code", "stop_name", "stop_desc", "stop_lat", "stop_lon", "location_type", "parent_station", "wheelchair_boarding", "platform_code"},
		rows,
	)
}

func (s Sources) writeRoutes(ctx context.Context, zw *zip.Writer, agencyID uuid.UUID) error {
	list, err := s.Routes.List(ctx, routes.Params{AgencyID: agencyID, Limit: maxExportRows})
	if err != nil {
		return fmt.Errorf("list routes: %w", err)
	}
	rows := make([][]string, len(list))
	for i, rt := range list {
		rows[i] = []string{
			rt.RouteID, strOrEmpty(rt.RouteShortName), strOrEmpty(rt.RouteLongName), strOrEmpty(rt.RouteDesc),
			strconv.Itoa(rt.RouteType), strOrEmpty(rt.RouteURL), strOrEmpty(rt.RouteColor),
			strOrEmpty(rt.RouteTextColor), intOrEmpty(rt.RouteSortOrder),
		}
	}
	return writeCSVFile(zw, "routes.txt",
		[]string{"route_id", "route_short_name", "route_long_name", "route_desc", "route_type", "route_url", "route_color", "route_text_color", "route_sort_order"},
		rows,
	)
}

func writeTrips(zw *zip.Writer, list []trips.Trip) error {
	rows := make([][]string, len(list))
	for i, t := range list {
		rows[i] = []string{
			t.RouteID, t.ServiceID, t.TripID, strOrEmpty(t.TripHeadsign), strOrEmpty(t.TripShortName),
			intOrEmpty(t.DirectionID), strOrEmpty(t.BlockID), strOrEmpty(t.ShapeID),
			intOrEmpty(t.WheelchairAccessible), intOrEmpty(t.BikesAllowed),
		}
	}
	return writeCSVFile(zw, "trips.txt",
		[]string{"route_id", "service_id", "trip_id", "trip_headsign", "trip_short_name", "direction_id", "block_id", "shape_id", "wheelchair_accessible", "bikes_allowed"},
		rows,
	)
}

func (s Sources) writeStopTimes(ctx context.Context, zw *zip.Writer, agencyID uuid.UUID, tripRows []trips.Trip) error {
	var rows [][]string
	for _, t := range tripRows {
		sts, err := s.Trips.ListStopTimes(ctx, agencyID, t.TripID)
		if err != nil {
			return fmt.Errorf("list stop times for trip %s: %w", t.TripID, err)
		}
		for _, st := range sts {
			rows = append(rows, []string{
				t.TripID, st.ArrivalTime, st.DepartureTime, st.StopID, strconv.Itoa(st.StopSequence),
				strOrEmpty(st.StopHeadsign), intOrEmpty(st.PickupType), intOrEmpty(st.DropOffType), intOrEmpty(st.Timepoint),
			})
		}
	}
	return writeCSVFile(zw, "stop_times.txt",
		[]string{"trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence", "stop_headsign", "pickup_type", "drop_off_type", "timepoint"},
		rows,
	)
}

func (s Sources) writeCalendar(ctx context.Context, zw *zip.Writer, agencyID uuid.UUID) error {
	list, err := s.Calendar.List(ctx, agencyID)
	if err != nil {
		return fmt.Errorf("list calendar: %w", err)
	}
	rows := make([][]string, len(list))
	for i, c := range list {
		rows[i] = []string{
			c.ServiceID, gtfsBool(c.Monday), gtfsBool(c.Tuesday), gtfsBool(c.Wednesday), gtfsBool(c.Thursday),
			gtfsBool(c.Friday), gtfsBool(c.Saturday), gtfsBool(c.Sunday), gtfsDate(c.StartDate), gtfsDate(c.EndDate),
		}
	}
	return writeCSVFile(zw, "calendar.txt",
		[]string{"service_id", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "start_date", "end_date"},
		rows,
	)
}

func (s Sources) writeCalendarDates(ctx context.Context, zw *zip.Writer, agencyID uuid.UUID) error {
	list, err := s.Calendar.ListDateExceptions(ctx, agencyID)
	if err != nil {
		return fmt.Errorf("list calendar dates: %w", err)
	}
	if len(list) == 0 {
		return nil // optional file — omit rather than write an empty one
	}
	rows := make([][]string, len(list))
	for i, d := range list {
		rows[i] = []string{d.ServiceID, gtfsDate(d.Date), strconv.Itoa(d.ExceptionType)}
	}
	return writeCSVFile(zw, "calendar_dates.txt", []string{"service_id", "date", "exception_type"}, rows)
}

func (s Sources) writeShapes(ctx context.Context, zw *zip.Writer, agencyID uuid.UUID) error {
	list, err := s.Shapes.List(ctx, agencyID)
	if err != nil {
		return fmt.Errorf("list shapes: %w", err)
	}
	if len(list) == 0 {
		return nil
	}
	rows := make([][]string, len(list))
	for i, p := range list {
		dist := ""
		if p.DistTraveled != nil {
			dist = strconv.FormatFloat(*p.DistTraveled, 'f', -1, 64)
		}
		rows[i] = []string{p.ShapeID, strconv.FormatFloat(p.Lat, 'f', -1, 64), strconv.FormatFloat(p.Lon, 'f', -1, 64), strconv.Itoa(p.Sequence), dist}
	}
	return writeCSVFile(zw, "shapes.txt", []string{"shape_id", "shape_pt_lat", "shape_pt_lon", "shape_pt_sequence", "shape_dist_traveled"}, rows)
}

func (s Sources) writeFareProducts(ctx context.Context, zw *zip.Writer, agencyID uuid.UUID) error {
	list, err := s.FareProducts.List(ctx, agencyID)
	if err != nil {
		return fmt.Errorf("list fare products: %w", err)
	}
	if len(list) == 0 {
		return nil
	}
	rows := make([][]string, len(list))
	for i, f := range list {
		media := ""
		if f.FareMediaID != nil {
			media = *f.FareMediaID
		}
		rows[i] = []string{f.FareProductID, f.FareProductName, media, f.Amount, f.Currency}
	}
	return writeCSVFile(zw, "fare_products.txt", []string{"fare_product_id", "fare_product_name", "fare_media_id", "amount", "currency"}, rows)
}

func writeCSVFile(zw *zip.Writer, name string, header []string, rows [][]string) error {
	f, err := zw.Create(name)
	if err != nil {
		return fmt.Errorf("create %s: %w", name, err)
	}
	cw := csv.NewWriter(f)
	if err := cw.Write(header); err != nil {
		return fmt.Errorf("write %s header: %w", name, err)
	}
	for _, row := range rows {
		if err := cw.Write(row); err != nil {
			return fmt.Errorf("write %s row: %w", name, err)
		}
	}
	cw.Flush()
	return cw.Error()
}

func strOrEmpty(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func intOrEmpty(v *int) string {
	if v == nil {
		return ""
	}
	return strconv.Itoa(*v)
}

func floatOrEmpty(v *float64) string {
	if v == nil {
		return ""
	}
	return strconv.FormatFloat(*v, 'f', -1, 64)
}

func gtfsBool(b bool) string {
	if b {
		return "1"
	}
	return "0"
}

func gtfsDate(t time.Time) string {
	return t.Format("20060102")
}

// agencyURL returns agency_config.license.terms_url when set, otherwise a
// clearly-a-placeholder URL — GTFS requires agency_url, but the brief's
// agency_config schema doesn't (terms_url is optional).
func agencyURL(config map[string]any, slug string) string {
	if license, ok := config["license"].(map[string]any); ok {
		if url, ok := license["terms_url"].(string); ok && url != "" {
			return url
		}
	}
	return fmt.Sprintf("https://%s.example/", slug)
}

// primaryLocale picks a deterministic locale from an agency's {locale: name}
// map — Go map iteration order is randomised, so picking a "first" entry
// naively would make agency_name/agency_lang flap between export runs.
// Prefers "en" when present, otherwise the alphabetically first key.
func primaryLocale(name map[string]string) string {
	if _, ok := name["en"]; ok {
		return "en"
	}
	keys := make([]string, 0, len(name))
	for k := range name {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	if len(keys) == 0 {
		return "en"
	}
	return keys[0]
}
