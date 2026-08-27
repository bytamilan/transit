import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:transit_api_client/transit_api_client.dart';
import '../models/itinerary.dart';
import '../providers/api_provider.dart';
import '../providers/extra_api.dart';
import '../providers/locale_provider.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  final String slug;
  const PlannerScreen({super.key, required this.slug});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late final _api = ref.read(apiClientProvider);
  late final _extra = ref.read(extraApiProvider);

  var _stops = const AsyncValue<List<Stop>>.loading();
  String? _originStopId;
  bool _useMyLocation = false;
  String? _destinationStopId;

  var _itineraries = const AsyncValue<List<Itinerary>>.data([]);
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    _stops = await AsyncValue.guard(() async {
      final response = await _api.listStops(slug: widget.slug);
      return response.data?.items.toList() ?? [];
    });
    if (mounted) setState(() {});
  }

  Future<void> _plan() async {
    if (_destinationStopId == null) return;
    if (!_useMyLocation && _originStopId == null) return;

    setState(() {
      _searched = true;
      _itineraries = const AsyncValue.loading();
    });

    double? lat, lon;
    if (_useMyLocation) {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lon = pos.longitude;
      } catch (e) {
        setState(() => _itineraries = AsyncValue.error('Could not get your location: $e', StackTrace.current));
        return;
      }
    }

    final locale = ref.read(localeProvider);
    _itineraries = await AsyncValue.guard(() => _extra.planTrip(
          slug: widget.slug,
          originStopId: _useMyLocation ? null : _originStopId,
          originLat: lat,
          originLon: lon,
          destinationStopId: _destinationStopId!,
          locale: locale,
        ));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan a trip')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _stops.when(
              data: (stops) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start from my current location'),
                    value: _useMyLocation,
                    onChanged: (v) => setState(() => _useMyLocation = v),
                  ),
                  if (!_useMyLocation)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'From stop'),
                      value: _originStopId,
                      items: stops
                          .map((s) => DropdownMenuItem(value: s.stopId, child: Text(s.stopName)))
                          .toList(),
                      onChanged: (v) => setState(() => _originStopId = v),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'To stop'),
                    value: _destinationStopId,
                    items: stops
                        .map((s) => DropdownMenuItem(value: s.stopId, child: Text(s.stopName)))
                        .toList(),
                    onChanged: (v) => setState(() => _destinationStopId = v),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _plan, child: const Text('Find itineraries')),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load stops: $e'),
            ),
            const SizedBox(height: 16),
            if (_searched)
              Expanded(
                child: _itineraries.when(
                  data: (itins) => itins.isEmpty
                      ? const Center(child: Text('No itineraries found for this trip.'))
                      : ListView.separated(
                          itemCount: itins.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) => _ItineraryTile(itinerary: itins[index]),
                        ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItineraryTile extends StatelessWidget {
  final Itinerary itinerary;
  const _ItineraryTile({required this.itinerary});

  String _fmt(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: itinerary.durationSeconds);
    return ListTile(
      title: Text('${_fmt(itinerary.departureTime)} → ${_fmt(itinerary.arrivalTime)}'
          ' (${duration.inMinutes} min, ${itinerary.transfers} transfer${itinerary.transfers == 1 ? '' : 's'})'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final leg in itinerary.legs)
            Text(leg.mode == 'walk'
                ? 'Walk ${leg.walkMeters?.round() ?? 0} m'
                : 'Ride ${leg.routeShortName ?? leg.routeId ?? ''} to ${leg.toStopName ?? leg.toStopId ?? ''}'),
          if (itinerary.fareProducts.isNotEmpty)
            Text(
              'Fares: ${itinerary.fareProducts.map((f) => '${f.name} ${f.amount} ${f.currency}').join(', ')}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
