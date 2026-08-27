import 'package:transit_telemetry/transit_telemetry.dart';

import '../models/agency_info.dart';
import '../models/duty_assignment.dart';
import 'gtfs_time.dart';
import 'public_api.dart';

/// Everything a [TripTracker] needs for one duty: the block's full stop
/// sequence (concatenated across every trip in the block, in order) and its
/// scheduled departure instant.
class LoadedDutyBlock {
  const LoadedDutyBlock({required this.stops, required this.shape, required this.scheduledDeparture});
  final List<TripStop> stops;
  final List<ShapePoint> shape;
  final DateTime scheduledDeparture;
}

/// Builds the on-device tracking inputs for a duty's block. There is no
/// dedicated shapes.txt read endpoint yet (Phase 4 only exposed stops,
/// routes, trips and stop_times) — the shape is approximated as the
/// straight line through the block's stops in order, which is the same
/// degraded-but-workable fallback GTFS map-matchers use for a feed with no
/// shapes.txt at all.
class DutyBlockLoader {
  DutyBlockLoader({required this.publicApi});

  final PublicApi publicApi;

  Future<LoadedDutyBlock> load({
    required String agencySlug,
    required DutyBlock block,
    required AgencyInfo agency,
  }) async {
    final agencyStops = await publicApi.listStops(agencySlug);
    final stopById = {for (final s in agencyStops) s.stopId: s};

    final stops = <TripStop>[];
    DateTime? scheduledDeparture;
    final serviceDateMidnight = DateTime.parse(block.serviceDate);

    for (final tripId in block.tripIds) {
      final stopTimes = await publicApi.listTripStopTimes(agencySlug, tripId);
      stopTimes.sort((a, b) => a.stopSequence.compareTo(b.stopSequence));

      for (final st in stopTimes) {
        final loc = stopById[st.stopId];
        if (loc == null) continue; // an unknown stop id — skip rather than crash tracking
        stops.add(TripStop(
          stopId: st.stopId,
          sequence: stops.length + 1,
          lat: loc.lat,
          lon: loc.lon,
          geofenceRadiusM: agency.stopGeofenceM,
        ));
        scheduledDeparture ??= serviceDateTime(serviceDateMidnight, parseGtfsTime(st.departureTime));
      }
    }

    if (stops.length < 2) {
      throw StateError('duty block ${block.blockRef} resolved fewer than 2 stops — cannot track');
    }

    final shape = ShapeMatcher.fromPoints(stops.map((s) => (lat: s.lat, lon: s.lon)).toList());
    return LoadedDutyBlock(stops: stops, shape: shape, scheduledDeparture: scheduledDeparture!);
  }
}
