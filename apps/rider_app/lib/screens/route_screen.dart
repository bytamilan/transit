import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_maps/transit_maps.dart';
import '../providers/agency_provider.dart';
import '../providers/api_provider.dart';

class RouteScreen extends ConsumerStatefulWidget {
  final String slug;
  final String routeId;

  const RouteScreen({super.key, required this.slug, required this.routeId});

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends ConsumerState<RouteScreen> {
  late final _api = ref.read(apiClientProvider);
  final _map = MapLibreProvider();
  var _trips = const AsyncValue<List<Trip>>.loading();
  var _selectedTripId = '';
  var _stopTimes = const AsyncValue<List<StopTime>>.loading();

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    _trips = await AsyncValue.guard(() async {
      final response = await _api.listTrips(slug: widget.slug, routeId: widget.routeId);
      return response.data?.items.toList() ?? [];
    });
    if (mounted) {
      setState(() {});
      if (_trips.valueOrNull?.isNotEmpty ?? false) {
        _selectTrip(_trips.valueOrNull!.first.tripId);
      }
    }
  }

  Future<void> _selectTrip(String tripId) async {
    _selectedTripId = tripId;
    _stopTimes = await AsyncValue.guard(() async {
      final response = await _api.listTripStopTimes(slug: widget.slug, tripId: tripId);
      return response.data?.items.toList() ?? [];
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final agency = ref.watch(agencyProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Route ${widget.routeId}')),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: _map.buildMap(
              initialLat: agency.config?.branding != null ? 1.2966 : 34.0522,
              initialLon: agency.config?.branding != null ? 103.7764 : -118.2437,
              zoom: 13,
              markers: _stopTimes.valueOrNull?.map((st) => MapMarker(
                    lat: 0,
                    lon: 0,
                    label: st.stopId,
                  )).toList() ?? [],
              polylines: [],
              onTap: null,
            ),
          ),
          Expanded(
            child: _trips.when(
              data: (trips) => Column(
                children: [
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: trips.length,
                      itemBuilder: (context, index) {
                        final trip = trips[index];
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: ChoiceChip(
                            label: Text(trip.tripHeadsign ?? trip.tripId),
                            selected: trip.tripId == _selectedTripId,
                            onSelected: (_) => _selectTrip(trip.tripId),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: _stopTimes.when(
                      data: (items) => ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final st = items[index];
                          return ListTile(
                            leading: CircleAvatar(child: Text('${st.stopSequence}')),
                            title: Text('${st.stopId}'),
                            subtitle: Text('${st.arrivalTime}'),
                          );
                        },
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
