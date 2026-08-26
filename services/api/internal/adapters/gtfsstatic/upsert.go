package gtfsstatic

import (
	"context"

	"github.com/OneBusAway/go-gtfs"
	"github.com/jackc/pgx/v5"
)

func (a *Adapter) upsertRoutes(ctx context.Context, tx pgx.Tx, agencyID string, routes []gtfs.Route) (int, error) {
	if len(routes) == 0 {
		return 0, nil
	}

	const sql = `
		INSERT INTO routes (
			agency_id, route_id, agency_id_text, route_short_name, route_long_name,
			route_desc, route_type, route_url, route_color, route_text_color,
			route_sort_order, continuous_pickup, continuous_drop_off
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
		ON CONFLICT (agency_id, route_id) DO UPDATE SET
			agency_id_text = EXCLUDED.agency_id_text,
			route_short_name = EXCLUDED.route_short_name,
			route_long_name = EXCLUDED.route_long_name,
			route_desc = EXCLUDED.route_desc,
			route_type = EXCLUDED.route_type,
			route_url = EXCLUDED.route_url,
			route_color = EXCLUDED.route_color,
			route_text_color = EXCLUDED.route_text_color,
			route_sort_order = EXCLUDED.route_sort_order,
			continuous_pickup = EXCLUDED.continuous_pickup,
			continuous_drop_off = EXCLUDED.continuous_drop_off,
			updated_at = now()
		WHERE routes.route_short_name IS DISTINCT FROM EXCLUDED.route_short_name
		   OR routes.route_long_name IS DISTINCT FROM EXCLUDED.route_long_name
		   OR routes.route_desc IS DISTINCT FROM EXCLUDED.route_desc
		   OR routes.route_type IS DISTINCT FROM EXCLUDED.route_type
		   OR routes.route_url IS DISTINCT FROM EXCLUDED.route_url
		   OR routes.route_color IS DISTINCT FROM EXCLUDED.route_color
		   OR routes.route_text_color IS DISTINCT FROM EXCLUDED.route_text_color
		   OR routes.route_sort_order IS DISTINCT FROM EXCLUDED.route_sort_order
		   OR routes.continuous_pickup IS DISTINCT FROM EXCLUDED.continuous_pickup
		   OR routes.continuous_drop_off IS DISTINCT FROM EXCLUDED.continuous_drop_off
	`

	args := make([][]any, 0, len(routes))
	for _, r := range routes {
		agencyTxt := ""
		if r.Agency != nil {
			agencyTxt = r.Agency.Id
		}
		args = append(args, []any{
			agencyID,
			r.Id,
			nullIfEmpty(agencyTxt),
			nullIfEmpty(r.ShortName),
			nullIfEmpty(r.LongName),
			nullIfEmpty(r.Description),
			int32(r.Type),
			nullIfEmpty(r.Url),
			nullIfEmpty(r.Color),
			nullIfEmpty(r.TextColor),
			pgInt(intValue(r.SortOrder)),
			int32(r.ContinuousPickup),
			int32(r.ContinuousDropOff),
		})
	}
	return execBatch(ctx, tx, sql, args)
}

func (a *Adapter) upsertStops(ctx context.Context, tx pgx.Tx, agencyID string, stops []gtfs.Stop) (int, error) {
	if len(stops) == 0 {
		return 0, nil
	}

	const sql = `
		INSERT INTO stops (
			agency_id, stop_id, stop_code, stop_name, stop_desc, stop_lat, stop_lon,
			stop_loc, zone_id, stop_url, location_type, parent_station, stop_timezone,
			wheelchair_boarding, platform_code
		) VALUES (
			$1, $2, $3, $4, $5, $6::double precision, $7::double precision,
			ST_SetSRID(ST_MakePoint($9::double precision, $8::double precision), 4326)::geography,
			$10, $11, $12, $13, $14, $15, $16
		)
		ON CONFLICT (agency_id, stop_id) DO UPDATE SET
			stop_code = EXCLUDED.stop_code,
			stop_name = EXCLUDED.stop_name,
			stop_desc = EXCLUDED.stop_desc,
			stop_lat = EXCLUDED.stop_lat,
			stop_lon = EXCLUDED.stop_lon,
			stop_loc = EXCLUDED.stop_loc,
			zone_id = EXCLUDED.zone_id,
			stop_url = EXCLUDED.stop_url,
			location_type = EXCLUDED.location_type,
			parent_station = EXCLUDED.parent_station,
			stop_timezone = EXCLUDED.stop_timezone,
			wheelchair_boarding = EXCLUDED.wheelchair_boarding,
			platform_code = EXCLUDED.platform_code,
			updated_at = now()
		WHERE stops.stop_name IS DISTINCT FROM EXCLUDED.stop_name
		   OR stops.stop_desc IS DISTINCT FROM EXCLUDED.stop_desc
		   OR stops.stop_lat IS DISTINCT FROM EXCLUDED.stop_lat
		   OR stops.stop_lon IS DISTINCT FROM EXCLUDED.stop_lon
		   OR stops.stop_loc IS DISTINCT FROM EXCLUDED.stop_loc
		   OR stops.zone_id IS DISTINCT FROM EXCLUDED.zone_id
		   OR stops.stop_url IS DISTINCT FROM EXCLUDED.stop_url
		   OR stops.location_type IS DISTINCT FROM EXCLUDED.location_type
		   OR stops.parent_station IS DISTINCT FROM EXCLUDED.parent_station
		   OR stops.stop_timezone IS DISTINCT FROM EXCLUDED.stop_timezone
		   OR stops.wheelchair_boarding IS DISTINCT FROM EXCLUDED.wheelchair_boarding
		   OR stops.platform_code IS DISTINCT FROM EXCLUDED.platform_code
	`

	args := make([][]any, 0, len(stops))
	for _, s := range stops {
		lat, lon := 0.0, 0.0
		if s.Latitude != nil {
			lat = *s.Latitude
		}
		if s.Longitude != nil {
			lon = *s.Longitude
		}
		locType := int32(s.Type)
		args = append(args, []any{
			agencyID,
			s.Id,
			nullIfEmpty(s.Code),
			s.Name,
			nullIfEmpty(s.Description),
			pgFloat(lat),
			pgFloat(lon),
			pgFloat(lat),
			pgFloat(lon),
			nullIfEmpty(s.ZoneId),
			nullIfEmpty(s.Url),
			locType,
			nullIfEmpty(rootStopID(s)),
			nullIfEmpty(s.Timezone),
			int32(s.WheelchairBoarding),
			nullIfEmpty(s.PlatformCode),
		})
	}
	return execBatch(ctx, tx, sql, args)
}

func rootStopID(s gtfs.Stop) string {
	if s.Parent == nil {
		return ""
	}
	return s.Parent.Id
}

func (a *Adapter) upsertCalendar(ctx context.Context, tx pgx.Tx, agencyID string, services []gtfs.Service) (int, error) {
	if len(services) == 0 {
		return 0, nil
	}

	const calSQL = `
		INSERT INTO calendar (
			agency_id, service_id, monday, tuesday, wednesday, thursday, friday,
			saturday, sunday, start_date, end_date
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		ON CONFLICT (agency_id, service_id) DO UPDATE SET
			monday = EXCLUDED.monday,
			tuesday = EXCLUDED.tuesday,
			wednesday = EXCLUDED.wednesday,
			thursday = EXCLUDED.thursday,
			friday = EXCLUDED.friday,
			saturday = EXCLUDED.saturday,
			sunday = EXCLUDED.sunday,
			start_date = EXCLUDED.start_date,
			end_date = EXCLUDED.end_date,
			updated_at = now()
		WHERE calendar.monday IS DISTINCT FROM EXCLUDED.monday
		   OR calendar.tuesday IS DISTINCT FROM EXCLUDED.tuesday
		   OR calendar.wednesday IS DISTINCT FROM EXCLUDED.wednesday
		   OR calendar.thursday IS DISTINCT FROM EXCLUDED.thursday
		   OR calendar.friday IS DISTINCT FROM EXCLUDED.friday
		   OR calendar.saturday IS DISTINCT FROM EXCLUDED.saturday
		   OR calendar.sunday IS DISTINCT FROM EXCLUDED.sunday
		   OR calendar.start_date IS DISTINCT FROM EXCLUDED.start_date
		   OR calendar.end_date IS DISTINCT FROM EXCLUDED.end_date
	`

	const dateSQL = `
		INSERT INTO calendar_dates (agency_id, service_id, date, exception_type)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (agency_id, service_id, date) DO UPDATE SET
			exception_type = EXCLUDED.exception_type,
			updated_at = now()
		WHERE calendar_dates.exception_type IS DISTINCT FROM EXCLUDED.exception_type
	`

	var calArgs [][]any
	var dateArgs [][]any

	for _, svc := range services {
		calArgs = append(calArgs, []any{
			agencyID,
			svc.Id,
			svc.Monday,
			svc.Tuesday,
			svc.Wednesday,
			svc.Thursday,
			svc.Friday,
			svc.Saturday,
			svc.Sunday,
			dateToString(svc.StartDate),
			dateToString(svc.EndDate),
		})
		for _, d := range svc.AddedDates {
			dateArgs = append(dateArgs, []any{agencyID, svc.Id, dateToString(d), 1})
		}
		for _, d := range svc.RemovedDates {
			dateArgs = append(dateArgs, []any{agencyID, svc.Id, dateToString(d), 2})
		}
	}

	total := 0
	if n, err := execBatch(ctx, tx, calSQL, calArgs); err != nil {
		return total, err
	} else {
		total += n
	}
	if n, err := execBatch(ctx, tx, dateSQL, dateArgs); err != nil {
		return total, err
	} else {
		total += n
	}
	return total, nil
}

func (a *Adapter) upsertTrips(ctx context.Context, tx pgx.Tx, agencyID string, trips []gtfs.ScheduledTrip) (int, error) {
	if len(trips) == 0 {
		return 0, nil
	}

	const sql = `
		INSERT INTO trips (
			agency_id, route_id, service_id, trip_id, trip_headsign, trip_short_name,
			direction_id, block_id, shape_id, wheelchair_accessible, bikes_allowed
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		ON CONFLICT (agency_id, trip_id) DO UPDATE SET
			route_id = EXCLUDED.route_id,
			service_id = EXCLUDED.service_id,
			trip_headsign = EXCLUDED.trip_headsign,
			trip_short_name = EXCLUDED.trip_short_name,
			direction_id = EXCLUDED.direction_id,
			block_id = EXCLUDED.block_id,
			shape_id = EXCLUDED.shape_id,
			wheelchair_accessible = EXCLUDED.wheelchair_accessible,
			bikes_allowed = EXCLUDED.bikes_allowed,
			updated_at = now()
		WHERE trips.route_id IS DISTINCT FROM EXCLUDED.route_id
		   OR trips.service_id IS DISTINCT FROM EXCLUDED.service_id
		   OR trips.trip_headsign IS DISTINCT FROM EXCLUDED.trip_headsign
		   OR trips.trip_short_name IS DISTINCT FROM EXCLUDED.trip_short_name
		   OR trips.direction_id IS DISTINCT FROM EXCLUDED.direction_id
		   OR trips.block_id IS DISTINCT FROM EXCLUDED.block_id
		   OR trips.shape_id IS DISTINCT FROM EXCLUDED.shape_id
		   OR trips.wheelchair_accessible IS DISTINCT FROM EXCLUDED.wheelchair_accessible
		   OR trips.bikes_allowed IS DISTINCT FROM EXCLUDED.bikes_allowed
	`

	args := make([][]any, 0, len(trips))
	for _, t := range trips {
		routeID := ""
		if t.Route != nil {
			routeID = t.Route.Id
		}
		serviceID := ""
		if t.Service != nil {
			serviceID = t.Service.Id
		}
		shapeID := ""
		if t.Shape != nil {
			shapeID = t.Shape.ID
		}
		args = append(args, []any{
			agencyID,
			routeID,
			serviceID,
			t.ID,
			nullIfEmpty(t.Headsign),
			nullIfEmpty(t.ShortName),
			pgInt(int(t.DirectionId)),
			nullIfEmpty(t.BlockID),
			nullIfEmpty(shapeID),
			int32(t.WheelchairAccessible),
			int32(t.BikesAllowed),
		})
	}
	return execBatch(ctx, tx, sql, args)
}

func (a *Adapter) upsertShapes(ctx context.Context, tx pgx.Tx, agencyID string, shapes []gtfs.Shape) (int, error) {
	if len(shapes) == 0 {
		return 0, nil
	}

	const sql = `
		INSERT INTO shapes (
			agency_id, shape_id, shape_pt_sequence, shape_pt_lat, shape_pt_lon,
			shape_pt_loc, shape_dist_traveled
		) VALUES (
			$1, $2, $3, $4::double precision, $5::double precision,
			ST_SetSRID(ST_MakePoint($5::double precision, $4::double precision), 4326)::geography,
			$6
		)
		ON CONFLICT (agency_id, shape_id, shape_pt_sequence) DO UPDATE SET
			shape_pt_lat = EXCLUDED.shape_pt_lat,
			shape_pt_lon = EXCLUDED.shape_pt_lon,
			shape_pt_loc = EXCLUDED.shape_pt_loc,
			shape_dist_traveled = EXCLUDED.shape_dist_traveled
		WHERE shapes.shape_pt_lat IS DISTINCT FROM EXCLUDED.shape_pt_lat
		   OR shapes.shape_pt_lon IS DISTINCT FROM EXCLUDED.shape_pt_lon
		   OR shapes.shape_dist_traveled IS DISTINCT FROM EXCLUDED.shape_dist_traveled
	`

	args := make([][]any, 0, len(shapes)*10)
	for _, sh := range shapes {
		for i, pt := range sh.Points {
			args = append(args, []any{
				agencyID,
				sh.ID,
				i + 1,
				pt.Latitude,
				pt.Longitude,
				pgFloat(valueOrZero(pt.Distance)),
			})
		}
	}
	return execBatch(ctx, tx, sql, args)
}

func (a *Adapter) upsertStopTimes(ctx context.Context, tx pgx.Tx, agencyID string, trips []gtfs.ScheduledTrip) (int, error) {
	if len(trips) == 0 {
		return 0, nil
	}

	const sql = `
		INSERT INTO stop_times (
			agency_id, trip_id, stop_id, arrival_time, departure_time, stop_sequence,
			stop_headsign, pickup_type, drop_off_type, continuous_pickup,
			continuous_drop_off, shape_dist_traveled, timepoint
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
		ON CONFLICT (agency_id, trip_id, stop_sequence) DO UPDATE SET
			stop_id = EXCLUDED.stop_id,
			arrival_time = EXCLUDED.arrival_time,
			departure_time = EXCLUDED.departure_time,
			stop_headsign = EXCLUDED.stop_headsign,
			pickup_type = EXCLUDED.pickup_type,
			drop_off_type = EXCLUDED.drop_off_type,
			continuous_pickup = EXCLUDED.continuous_pickup,
			continuous_drop_off = EXCLUDED.continuous_drop_off,
			shape_dist_traveled = EXCLUDED.shape_dist_traveled,
			timepoint = EXCLUDED.timepoint,
			updated_at = now()
		WHERE stop_times.stop_id IS DISTINCT FROM EXCLUDED.stop_id
		   OR stop_times.arrival_time IS DISTINCT FROM EXCLUDED.arrival_time
		   OR stop_times.departure_time IS DISTINCT FROM EXCLUDED.departure_time
		   OR stop_times.stop_headsign IS DISTINCT FROM EXCLUDED.stop_headsign
		   OR stop_times.pickup_type IS DISTINCT FROM EXCLUDED.pickup_type
		   OR stop_times.drop_off_type IS DISTINCT FROM EXCLUDED.drop_off_type
		   OR stop_times.continuous_pickup IS DISTINCT FROM EXCLUDED.continuous_pickup
		   OR stop_times.continuous_drop_off IS DISTINCT FROM EXCLUDED.continuous_drop_off
		   OR stop_times.shape_dist_traveled IS DISTINCT FROM EXCLUDED.shape_dist_traveled
		   OR stop_times.timepoint IS DISTINCT FROM EXCLUDED.timepoint
	`

	args := make([][]any, 0, len(trips)*10)
	for _, trip := range trips {
		for _, st := range trip.StopTimes {
			stopID := ""
			if st.Stop != nil {
				stopID = st.Stop.Id
			}
			timepoint := 0
			if st.ExactTimes {
				timepoint = 1
			}
			args = append(args, []any{
				agencyID,
				trip.ID,
				stopID,
				durationToInterval(st.ArrivalTime),
				durationToInterval(st.DepartureTime),
				st.StopSequence,
				nullIfEmpty(st.Headsign),
				int32(st.PickupType),
				int32(st.DropOffType),
				int32(st.ContinuousPickup),
				int32(st.ContinuousDropOff),
				pgFloat(valueOrZero(st.ShapeDistanceTraveled)),
				timepoint,
			})
		}
	}
	return execBatch(ctx, tx, sql, args)
}

// helpers for non-pointer numeric defaults
func valueOrZero[T any](v *T) T {
	var zero T
	if v == nil {
		return zero
	}
	return *v
}
