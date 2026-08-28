import 'package:transit_api_client/src/model/agency.dart' as api;
import 'package:transit_api_client/src/model/agency_branding.dart' as api;
import 'package:transit_api_client/src/model/agency_config.dart' as api;
import 'package:transit_api_client/src/model/agency_license.dart' as api;
import 'package:transit_api_client/src/model/driver_ops_config.dart' as api;
import 'package:transit_api_client/src/model/route.dart' as api;
import 'package:transit_api_client/src/model/stop.dart' as api;
import 'package:transit_api_client/src/model/stop_time.dart' as api;
import 'package:transit_api_client/src/model/trip.dart' as api;
import 'package:transit_core/transit_core.dart' as core;

extension AgencyDomainMapper on api.Agency {
  core.Agency toDomain() => _map(() => core.Agency(
        id: id,
        slug: slug,
        name: core.LocalizedText(Map<String, String>.fromEntries(name.entries)),
        timezone: timezone,
      ));
}

extension AgencyConfigDomainMapper on api.AgencyConfig {
  core.AgencyConfig toDomain() => _map(() => core.AgencyConfig(
        locales: List<String>.from(locales),
        currency: currency,
        distanceUnit: switch (distanceUnit) {
          api.AgencyConfigDistanceUnitEnum.metric => core.DistanceUnit.metric,
          api.AgencyConfigDistanceUnitEnum.imperial =>
            core.DistanceUnit.imperial,
          _ => throw ArgumentError.value(distanceUnit, 'distanceUnit'),
        },
        modes: List<String>.from(modes),
        mapProvider: switch (mapProvider) {
          api.AgencyConfigMapProviderEnum.google => core.MapProviderKind.google,
          api.AgencyConfigMapProviderEnum.maplibre =>
            core.MapProviderKind.maplibre,
          api.AgencyConfigMapProviderEnum.protomaps =>
            core.MapProviderKind.protomaps,
          _ => throw ArgumentError.value(mapProvider, 'mapProvider'),
        },
        license: license.toDomain(),
        branding: branding.toDomain(),
        driverOps: driverOps.toDomain(),
      ));
}

extension AgencyBrandingDomainMapper on api.AgencyBranding {
  core.AgencyBranding toDomain() => _map(() => core.AgencyBranding(
        primary: primary,
        secondary: secondary ?? '#FFFFFF',
        logoUrl: logoUrl,
        font: font,
      ));
}

extension AgencyLicenseDomainMapper on api.AgencyLicense {
  core.AgencyLicense toDomain() => _map(() => core.AgencyLicense(
        spdx: spdx,
        attribution: attribution,
        termsUrl: termsUrl,
      ));
}

extension DriverOpsConfigDomainMapper on api.DriverOpsConfig {
  core.DriverOpsConfig toDomain() => _map(() => core.DriverOpsConfig(
        stopGeofenceM: stopGeofenceM,
        pingIntervalMovingS: pingIntervalMovingS,
        pingIntervalIdleS: pingIntervalIdleS,
        autoStartTrip: autoStartTrip,
        lockUiAboveKmh: lockUiAboveKmh,
      ));
}

extension StopDomainMapper on api.Stop {
  core.Stop toDomain() => _map(() {
        if ((stopLat == null) != (stopLon == null)) {
          throw ArgumentError(
              'stop_lat and stop_lon must be provided together');
        }
        return core.Stop(
          stopId: stopId,
          stopCode: stopCode,
          stopName: stopName,
          stopDesc: stopDesc,
          coordinates: stopLat == null
              ? null
              : core.GeoPoint(latitude: stopLat!, longitude: stopLon!),
          locationType: locationType,
          parentStation: parentStation,
          wheelchairBoarding: wheelchairBoarding,
          platformCode: platformCode,
        );
      });
}

extension RouteDomainMapper on api.Route {
  core.Route toDomain() => _map(() => core.Route(
        routeId: routeId,
        routeShortName: routeShortName,
        routeLongName: routeLongName,
        routeDesc: routeDesc,
        routeType: routeType,
        routeUrl: routeUrl,
        routeColor: routeColor,
        routeTextColor: routeTextColor,
        routeSortOrder: routeSortOrder,
      ));
}

extension TripDomainMapper on api.Trip {
  core.Trip toDomain() => _map(() => core.Trip(
        tripId: tripId,
        routeId: routeId,
        serviceId: serviceId,
        tripHeadsign: tripHeadsign,
        tripShortName: tripShortName,
        directionId: directionId,
        blockId: blockId,
        shapeId: shapeId,
        wheelchairAccessible: wheelchairAccessible,
        bikesAllowed: bikesAllowed,
      ));
}

extension StopTimeDomainMapper on api.StopTime {
  core.StopTime toDomain() => _map(() => core.StopTime(
        tripId: tripId,
        stopId: stopId,
        arrivalTime:
            arrivalTime == null ? null : core.GtfsTime.parse(arrivalTime!),
        departureTime:
            departureTime == null ? null : core.GtfsTime.parse(departureTime!),
        stopSequence: stopSequence,
        stopHeadsign: stopHeadsign,
        pickupType: pickupType,
        dropOffType: dropOffType,
        timepoint: timepoint,
      ));
}

T _map<T>(T Function() convert) {
  try {
    return convert();
  } on core.ValidationFailure catch (error) {
    throw core.TransitException(error);
  } on FormatException catch (error) {
    throw core.TransitException(core.ValidationFailure(error.message));
  } on ArgumentError catch (error) {
    throw core.TransitException(core.ValidationFailure(error.toString()));
  } on TypeError catch (error) {
    throw core.TransitException(core.ValidationFailure(error.toString()));
  }
}
