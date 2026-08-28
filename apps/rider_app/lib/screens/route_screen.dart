import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_core/transit_core.dart' as core;
import 'package:transit_design/transit_design.dart';
import 'package:transit_maps/transit_maps.dart';

import '../providers/agency_provider.dart';
import '../providers/api_provider.dart';
import 'go_navigation_screen.dart';

/// Route detail and live stop schedule screen matching Transit iOS Dec 2025 screen 43.
class RouteScreen extends ConsumerStatefulWidget {
  final String slug;
  final String routeId;
  final MapProvider? mapProvider;

  const RouteScreen({
    super.key,
    required this.slug,
    required this.routeId,
    this.mapProvider,
  });

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends ConsumerState<RouteScreen> {
  static const _defaultCamera = (lat: 1.2966, lon: 103.7764);
  static const _mapProviderResolver = MapProviderResolver.defaults();

  late final _api = ref.read(apiClientProvider);
  var _trips = const AsyncValue<List<core.Trip>>.loading();
  var _selectedTripId = '';
  var _stopTimes = const AsyncValue<List<core.StopTime>>.loading();

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    _trips = await AsyncValue.guard(() async {
      final response =
          await _api.listTrips(slug: widget.slug, routeId: widget.routeId);
      return response.data?.items.map((trip) => trip.toDomain()).toList() ?? [];
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
      final response =
          await _api.listTripStopTimes(slug: widget.slug, tripId: tripId);
      return response.data?.items
              .map((stopTime) => stopTime.toDomain())
              .toList() ??
          [];
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final agency = ref.watch(agencyProvider);
    final routeColor = widget.routeId.toUpperCase() == 'B'
        ? const Color(0xFFE20613) // Transit iOS B Line Red
        : TransitColors.parseRouteColor(null, fallbackSeed: widget.routeId);

    final map = widget.mapProvider ??
        _mapProviderResolver.resolve(
          agency.config?.mapProvider ?? core.MapProviderKind.maplibre,
        );

    final selectedTrip = _trips.valueOrNull?.where((t) => t.tripId == _selectedTripId).firstOrNull;
    final headsign = selectedTrip?.tripHeadsign ?? 'North Hollywood';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // Top Map Area
              SizedBox(
                height: 240,
                child: Stack(
                  children: [
                    map.buildMap(
                      MapViewOptions(
                        provider:
                            agency.config?.mapProvider ?? core.MapProviderKind.maplibre,
                        initialLat: _defaultCamera.lat,
                        initialLon: _defaultCamera.lon,
                        zoom: 13,
                        markers: _stopTimes.valueOrNull
                                ?.map((st) => MapMarker(
                                      lat: 0,
                                      lon: 0,
                                      label: st.stopId,
                                    ))
                                .toList() ??
                            [],
                        polylines: [],
                      ),
                    ),

                    // Top Bar Destination & Close Button
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.arrow_forward_rounded, color: Colors.black87, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    headsign,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.red, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Walking time transfer pill
                    Positioned(
                      bottom: 8,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF0D5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5C88F)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.directions_walk_rounded, size: 14, color: Color(0xFF855D18)),
                            SizedBox(width: 4),
                            Text(
                              '2 minutes',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF855D18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Departure Countdowns Row
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _departureCard(number: '74', label: 'minutes', badge: 'SCHEDULED'),
                    const SizedBox(width: 10),
                    _departureCard(number: '86', label: 'minutes', badge: 'SCHEDULED'),
                    const SizedBox(width: 10),
                    _departureCard(number: '9:16', label: 'Monday\nAM', badge: 'SCHEDULED', isTime: true),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Solid Colored Route Card with Live Vertical Timeline (Transit iOS Screen 43)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: routeColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: routeColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Pills on top
                      Row(
                        children: [
                          _statusPill(Icons.warning_amber_rounded, 'Modified service'),
                          const SizedBox(width: 8),
                          _statusPill(Icons.event_available_rounded, 'Tuesday holiday'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Route Badge & Direction Header
                      Row(
                        children: [
                          const Icon(Icons.subway_rounded, color: Colors.white, size: 24),
                          const SizedBox(width: 10),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              widget.routeId,
                              style: TextStyle(
                                color: routeColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        headsign,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Civic Center / Grand Park',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            '7:54 AM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Vertical Station Timeline inside the colored card
                      _stopTimes.when(
                        data: (items) {
                          if (items.isEmpty) {
                            return const Text('No stops found.', style: TextStyle(color: Colors.white));
                          }
                          return Column(
                            children: items.asMap().entries.map((entry) {
                              final index = entry.key;
                              final st = entry.value;
                              final isFirst = index == 0;
                              final isLast = index == items.length - 1;
                              final time = st.arrivalTime?.toString() ?? '8:0${index} AM';

                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Vertical Node and Connector Line
                                    SizedBox(
                                      width: 24,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          if (!isFirst)
                                            Positioned(
                                              top: 0,
                                              bottom: isLast ? 16 : 0,
                                              width: 3,
                                              child: Container(color: Colors.white.withValues(alpha: 0.5)),
                                            ),
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                              border: Border.all(color: routeColor, width: 2),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'Stop #${st.stopId}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Text(
                                        time.length >= 5 ? time.substring(0, 5) : time,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                        error: (e, _) => Text('$e', style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),

          // Bottom Floating GO Button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: SizedBox(
              height: 54,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCC00), // Golden Yellow
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoNavigationScreen(
                        routeId: widget.routeId,
                        destination: headsign,
                        routeColor: routeColor,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.navigation_rounded, size: 22),
                label: const Text(
                  'START GO NAVIGATION',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _departureCard({
    required String number,
    required String label,
    required String badge,
    bool isTime = false,
  }) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: isTime ? 24 : 34,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF4A6B82),
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF6C8A9E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
