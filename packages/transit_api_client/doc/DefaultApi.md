# transit_api_client.api.DefaultApi

## Load the API package
```dart
import 'package:transit_api_client/api.dart';
```

All URIs are relative to *http://localhost:8080*

Method | HTTP request | Description
------------- | ------------- | -------------
[**getAgency**](DefaultApi.md#getagency) | **GET** /v0/agencies/{slug} | Get public agency metadata
[**getAgencyConfig**](DefaultApi.md#getagencyconfig) | **GET** /v0/agencies/{slug}/config | Get agency runtime configuration
[**getRoute**](DefaultApi.md#getroute) | **GET** /v0/agencies/{slug}/routes/{route_id} | Get a single route
[**getStop**](DefaultApi.md#getstop) | **GET** /v0/agencies/{slug}/stops/{stop_id} | Get a single stop
[**getTrip**](DefaultApi.md#gettrip) | **GET** /v0/agencies/{slug}/trips/{trip_id} | Get a single trip
[**healthz**](DefaultApi.md#healthz) | **GET** /healthz | Liveness probe
[**listArrivals**](DefaultApi.md#listarrivals) | **GET** /v0/agencies/{slug}/arrivals | List upcoming arrivals for an agency
[**listRoutes**](DefaultApi.md#listroutes) | **GET** /v0/agencies/{slug}/routes | List routes for an agency
[**listStops**](DefaultApi.md#liststops) | **GET** /v0/agencies/{slug}/stops | List stops for an agency
[**listTripStopTimes**](DefaultApi.md#listtripstoptimes) | **GET** /v0/agencies/{slug}/trips/{trip_id}/stop_times | List stop times for a trip
[**listTrips**](DefaultApi.md#listtrips) | **GET** /v0/agencies/{slug}/trips | List trips for an agency
[**readyz**](DefaultApi.md#readyz) | **GET** /readyz | Readiness probe


# **getAgency**
> Agency getAgency(slug)

Get public agency metadata

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();
final String slug = slug_example; // String | 

try {
    final response = api.getAgency(slug);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getAgency: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 

### Return type

[**Agency**](Agency.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getAgencyConfig**
> AgencyConfig getAgencyConfig(slug)

Get agency runtime configuration

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();
final String slug = slug_example; // String | 

try {
    final response = api.getAgencyConfig(slug);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getAgencyConfig: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 

### Return type

[**AgencyConfig**](AgencyConfig.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getRoute**
> Route getRoute(slug, routeId)

Get a single route

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();
final String slug = slug_example; // String | 
final String routeId = routeId_example; // String | 

try {
    final response = api.getRoute(slug, routeId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getRoute: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **routeId** | **String**|  | 

### Return type

[**Route**](Route.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getStop**
> Stop getStop(slug, stopId)

Get a single stop

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();
final String slug = slug_example; // String | 
final String stopId = stopId_example; // String | 

try {
    final response = api.getStop(slug, stopId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getStop: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **stopId** | **String**|  | 

### Return type

[**Stop**](Stop.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getTrip**
> Trip getTrip(slug, tripId)

Get a single trip

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();
final String slug = slug_example; // String | 
final String tripId = tripId_example; // String | 

try {
    final response = api.getTrip(slug, tripId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->getTrip: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **tripId** | **String**|  | 

### Return type

[**Trip**](Trip.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **healthz**
> healthz()

Liveness probe

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();

try {
    api.healthz();
} on DioException catch (e) {
    print('Exception when calling DefaultApi->healthz: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listArrivals**
> ArrivalList listArrivals(slug, stopId, routeId, serviceDate, limit, offset)

List upcoming arrivals for an agency

Returns static timetable arrivals. Realtime predictions will be layered on top in Phase 8.

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();
final String slug = slug_example; // String | 
final String stopId = stopId_example; // String | 
final String routeId = routeId_example; // String | 
final Date serviceDate = 2013-10-20; // Date | 
final int limit = 56; // int | 
final int offset = 56; // int | 

try {
    final response = api.listArrivals(slug, stopId, routeId, serviceDate, limit, offset);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listArrivals: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **stopId** | **String**|  | [optional] 
 **routeId** | **String**|  | [optional] 
 **serviceDate** | **Date**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 50]
 **offset** | **int**|  | [optional] [default to 0]

### Return type

[**ArrivalList**](ArrivalList.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listRoutes**
> RouteList listRoutes(slug, limit, offset)

List routes for an agency

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();
final String slug = slug_example; // String | 
final int limit = 56; // int | 
final int offset = 56; // int | 

try {
    final response = api.listRoutes(slug, limit, offset);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listRoutes: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **limit** | **int**|  | [optional] [default to 100]
 **offset** | **int**|  | [optional] [default to 0]

### Return type

[**RouteList**](RouteList.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listStops**
> StopList listStops(slug, lat, lon, radiusM, limit, offset)

List stops for an agency

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();
final String slug = slug_example; // String | 
final double lat = 1.2; // double | 
final double lon = 1.2; // double | 
final double radiusM = 1.2; // double | 
final int limit = 56; // int | 
final int offset = 56; // int | 

try {
    final response = api.listStops(slug, lat, lon, radiusM, limit, offset);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listStops: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **lat** | **double**|  | [optional] 
 **lon** | **double**|  | [optional] 
 **radiusM** | **double**|  | [optional] [default to 500]
 **limit** | **int**|  | [optional] [default to 100]
 **offset** | **int**|  | [optional] [default to 0]

### Return type

[**StopList**](StopList.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listTripStopTimes**
> StopTimeList listTripStopTimes(slug, tripId)

List stop times for a trip

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();
final String slug = slug_example; // String | 
final String tripId = tripId_example; // String | 

try {
    final response = api.listTripStopTimes(slug, tripId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listTripStopTimes: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **tripId** | **String**|  | 

### Return type

[**StopTimeList**](StopTimeList.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listTrips**
> TripList listTrips(slug, routeId, serviceId, limit, offset)

List trips for an agency

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();
final String slug = slug_example; // String | 
final String routeId = routeId_example; // String | 
final String serviceId = serviceId_example; // String | 
final int limit = 56; // int | 
final int offset = 56; // int | 

try {
    final response = api.listTrips(slug, routeId, serviceId, limit, offset);
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->listTrips: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **slug** | **String**|  | 
 **routeId** | **String**|  | [optional] 
 **serviceId** | **String**|  | [optional] 
 **limit** | **int**|  | [optional] [default to 100]
 **offset** | **int**|  | [optional] [default to 0]

### Return type

[**TripList**](TripList.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **readyz**
> ReadyResponse readyz()

Readiness probe

### Example
```dart
import 'package:transit_api_client/api.dart';

final api = TransitApiClient().getDefaultApi();

try {
    final response = api.readyz();
    print(response);
} on DioException catch (e) {
    print('Exception when calling DefaultApi->readyz: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**ReadyResponse**](ReadyResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

