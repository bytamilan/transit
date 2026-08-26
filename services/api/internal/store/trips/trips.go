// Package trips reads trip, stop_time and arrival rows from the database.
package trips

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Reader loads trip rows.
type Reader struct {
	pool *pgxpool.Pool
}

// New returns a trip reader backed by pool.
func New(pool *pgxpool.Pool) *Reader {
	return &Reader{pool: pool}
}

// Trip is a canonical GTFS trip.
type Trip struct {
	TripID               string
	RouteID              string
	ServiceID            string
	TripHeadsign         *string
	TripShortName        *string
	DirectionID          *int
	BlockID              *string
	ShapeID              *string
	WheelchairAccessible *int
	BikesAllowed         *int
}

// Params controls listing.
type Params struct {
	AgencyID  uuid.UUID
	RouteID   string
	ServiceID string
	Limit     int
	Offset    int
}

// List returns trips for an agency.
func (r *Reader) List(ctx context.Context, p Params) ([]Trip, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("trips reader not connected to a database")
	}
	rows, err := r.pool.Query(ctx,
		`SELECT * FROM transit.list_trips($1, $2, $3, $4, $5)`,
		p.AgencyID, nullString(p.RouteID), nullString(p.ServiceID), p.Limit, p.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("query trips: %w", err)
	}
	defer rows.Close()

	var out []Trip
	for rows.Next() {
		var t Trip
		if err := rows.Scan(&t.TripID, &t.RouteID, &t.ServiceID, &t.TripHeadsign,
			&t.TripShortName, &t.DirectionID, &t.BlockID, &t.ShapeID,
			&t.WheelchairAccessible, &t.BikesAllowed); err != nil {
			return nil, fmt.Errorf("scan trip: %w", err)
		}
		out = append(out, t)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate trips: %w", err)
	}
	return out, nil
}

// Get returns a single trip by id.
func (r *Reader) Get(ctx context.Context, agencyID uuid.UUID, tripID string) (*Trip, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("trips reader not connected to a database")
	}
	var t Trip
	err := r.pool.QueryRow(ctx,
		`SELECT * FROM transit.get_trip($1, $2)`,
		agencyID, tripID,
	).Scan(&t.TripID, &t.RouteID, &t.ServiceID, &t.TripHeadsign,
		&t.TripShortName, &t.DirectionID, &t.BlockID, &t.ShapeID,
		&t.WheelchairAccessible, &t.BikesAllowed)
	if err != nil {
		return nil, err
	}
	return &t, nil
}

// Count returns the total number of trips for an agency.
func (r *Reader) Count(ctx context.Context, agencyID uuid.UUID, routeID, serviceID string) (int, error) {
	if r.pool == nil {
		return 0, fmt.Errorf("trips reader not connected to a database")
	}
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT transit.count_trips($1, $2, $3)`,
		agencyID, nullString(routeID), nullString(serviceID),
	).Scan(&n)
	if err != nil {
		return 0, err
	}
	return n, nil
}

// StopTime is a canonical GTFS stop time.
type StopTime struct {
	StopID        string
	ArrivalTime   string
	DepartureTime string
	StopSequence  int
	StopHeadsign  *string
	PickupType    *int
	DropOffType   *int
	Timepoint     *int
}

// ListStopTimes returns stop times for a trip.
func (r *Reader) ListStopTimes(ctx context.Context, agencyID uuid.UUID, tripID string) ([]StopTime, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("trips reader not connected to a database")
	}
	rows, err := r.pool.Query(ctx,
		`SELECT * FROM transit.list_trip_stop_times($1, $2)`,
		agencyID, tripID,
	)
	if err != nil {
		return nil, fmt.Errorf("query stop times: %w", err)
	}
	defer rows.Close()

	var out []StopTime
	for rows.Next() {
		var st StopTime
		var arr, dep pgtype.Interval
		if err := rows.Scan(&st.StopID, &arr, &dep, &st.StopSequence,
			&st.StopHeadsign, &st.PickupType, &st.DropOffType, &st.Timepoint); err != nil {
			return nil, fmt.Errorf("scan stop time: %w", err)
		}
		st.ArrivalTime = intervalString(arr)
		st.DepartureTime = intervalString(dep)
		out = append(out, st)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate stop times: %w", err)
	}
	return out, nil
}

// Arrival is a static timetable arrival.
type Arrival struct {
	StopID               string
	TripID               string
	RouteID              string
	RouteShortName       *string
	TripHeadsign         *string
	ArrivalTime          string
	DepartureTime        string
	StopSequence         int
	WheelchairAccessible *int
}

// ArrivalParams controls listing.
type ArrivalParams struct {
	AgencyID    uuid.UUID
	StopID      string
	RouteID     string
	ServiceDate *time.Time
	Limit       int
	Offset      int
}

// ListArrivals returns upcoming arrivals for an agency.
func (r *Reader) ListArrivals(ctx context.Context, p ArrivalParams) ([]Arrival, error) {
	if r.pool == nil {
		return nil, fmt.Errorf("trips reader not connected to a database")
	}
	var serviceDate *time.Time
	if p.ServiceDate != nil {
		d := *p.ServiceDate
		serviceDate = &d
	}
	rows, err := r.pool.Query(ctx,
		`SELECT * FROM transit.list_arrivals($1, $2, $3, $4, $5, $6)`,
		p.AgencyID, nullString(p.StopID), nullString(p.RouteID), serviceDate, p.Limit, p.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("query arrivals: %w", err)
	}
	defer rows.Close()

	var out []Arrival
	for rows.Next() {
		var a Arrival
		var arr, dep pgtype.Interval
		if err := rows.Scan(&a.StopID, &a.TripID, &a.RouteID, &a.RouteShortName,
			&a.TripHeadsign, &arr, &dep, &a.StopSequence, &a.WheelchairAccessible); err != nil {
			return nil, fmt.Errorf("scan arrival: %w", err)
		}
		a.ArrivalTime = intervalString(arr)
		a.DepartureTime = intervalString(dep)
		out = append(out, a)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate arrivals: %w", err)
	}
	return out, nil
}

// CountArrivals returns the total number of arrivals matching the filters.
func (r *Reader) CountArrivals(ctx context.Context, agencyID uuid.UUID, stopID, routeID string, serviceDate *time.Time) (int, error) {
	if r.pool == nil {
		return 0, fmt.Errorf("trips reader not connected to a database")
	}
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT transit.count_arrivals($1, $2, $3, $4)`,
		agencyID, nullString(stopID), nullString(routeID), serviceDate,
	).Scan(&n)
	if err != nil {
		return 0, err
	}
	return n, nil
}

func nullString(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func intervalString(i pgtype.Interval) string {
	if !i.Valid {
		return ""
	}
	// Convert microseconds to a HH:MM:SS string.
	d := time.Duration(i.Microseconds) * time.Microsecond
	h := int(d.Hours())
	m := int(d.Minutes()) % 60
	s := int(d.Seconds()) % 60
	return fmt.Sprintf("%02d:%02d:%02d", h, m, s)
}
