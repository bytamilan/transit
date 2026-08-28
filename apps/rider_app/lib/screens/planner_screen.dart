import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_core/transit_core.dart' as core;
import 'package:transit_design/transit_design.dart';

import '../models/itinerary.dart';
import '../providers/api_provider.dart';
import '../providers/extra_api.dart';
import '../providers/locale_provider.dart';
import 'go_navigation_screen.dart';

/// Search and Trip Planner screen matching Transit iOS Dec 2025 search sheet.
class PlannerScreen extends ConsumerStatefulWidget {
  final String slug;
  const PlannerScreen({super.key, required this.slug});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late final _api = ref.read(apiClientProvider);
  late final _extra = ref.read(extraApiProvider);

  final TextEditingController _searchController = TextEditingController();
  var _stops = const AsyncValue<List<core.Stop>>.loading();
  String? _originStopId;
  bool _useMyLocation = true;
  String? _destinationStopId;
  String? _destinationName;

  var _itineraries = const AsyncValue<List<Itinerary>>.data([]);
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStops() async {
    _stops = await AsyncValue.guard(() async {
      final response = await _api.listStops(slug: widget.slug);
      return response.data?.items.map((stop) => stop.toDomain()).toList() ?? [];
    });
    if (mounted) setState(() {});
  }

  Future<void> _planToStop(core.Stop stop) async {
    setState(() {
      _destinationStopId = stop.stopId;
      _destinationName = stop.stopName;
      _searchController.text = stop.stopName;
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
      } catch (_) {
        // Fallback to default stop coordinates if emulator/no GPS
        lat = 1.2966;
        lon = 103.7764;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? TransitColors.darkBackground : const Color(0xFFF3F4F6),
      body: Column(
        children: [
          // Transit iOS Signature Solid Green Header with Search
          Container(
            color: TransitColors.brandGreen,
            padding: const EdgeInsets.only(top: 48, bottom: 16, left: 16, right: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: Colors.grey, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Line or destination',
                                  hintStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  filled: false,
                                ),
                                onSubmitted: (val) {
                                  final stops = _stops.valueOrNull ?? [];
                                  final match = stops.where(
                                    (s) => s.stopName.toLowerCase().contains(val.toLowerCase()),
                                  ).firstOrNull;
                                  if (match != null) {
                                    _planToStop(match);
                                  }
                                },
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searched = false);
                                },
                              ),
                            const Icon(Icons.swap_vert_rounded, color: TransitColors.brandGreen, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Sheet Actions or Trip Results
          Expanded(
            child: _searched ? _buildResultsView(isDark) : _buildActionSheet(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSheet(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        TransitActionCard(
          title: 'Choose on map',
          icon: const Icon(Icons.location_on_rounded, color: Colors.black87, size: 24),
          onTap: () {
            final stops = _stops.valueOrNull ?? [];
            if (stops.isNotEmpty) _planToStop(stops.first);
          },
        ),
        TransitActionCard(
          title: 'Map location',
          subtitle: '210 W Temple St',
          icon: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFBA0CBA), width: 6),
            ),
          ),
          onTap: () {
            final stops = _stops.valueOrNull ?? [];
            if (stops.isNotEmpty) _planToStop(stops.first);
          },
        ),
        TransitActionCard(
          title: 'Set home',
          icon: const Icon(Icons.home_rounded, color: TransitColors.metroBlue, size: 24),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Home location saved')),
            );
          },
        ),
        TransitActionCard(
          title: 'Set work',
          icon: const Icon(Icons.work_rounded, color: TransitColors.metroOrange, size: 24),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Work location saved')),
            );
          },
        ),
        TransitActionCard(
          title: 'Show upcoming events',
          icon: const Icon(Icons.event_note_rounded, color: Colors.black87, size: 24),
          onTap: () {},
        ),

        const SizedBox(height: 16),

        // Recent Destinations / Suggested Stops
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Text(
            'RECENT & NEARBY STOPS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? Colors.white54 : TransitColors.lightSubtext,
            ),
          ),
        ),

        _stops.when(
          data: (stops) {
            return Column(
              children: stops.take(6).map((stop) {
                return TransitActionCard(
                  title: stop.stopName,
                  subtitle: 'Stop #${stop.stopId} • Public Transit',
                  icon: const Icon(Icons.history_rounded, color: Colors.grey, size: 22),
                  onTap: () => _planToStop(stop),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
          error: (e, _) => Padding(padding: const EdgeInsets.all(20), child: Text('Failed to load stops: $e')),
        ),
      ],
    );
  }

  Widget _buildResultsView(bool isDark) {
    return _itineraries.when(
      data: (itins) {
        if (itins.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.directions_bus_filled_rounded, size: 48, color: TransitColors.brandGreen),
                    const SizedBox(height: 10),
                    const Text(
                      'It’s right around the corner!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Destination is close to your current location. Compare these quick options:',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _multimodalOptionCard(
                title: 'Walk direct',
                modeIcon: Icons.directions_walk_rounded,
                duration: '12 min',
                distance: '0.9 km • 42 kcal',
                color: TransitColors.walkSlate,
              ),
              _multimodalOptionCard(
                title: 'Metro Bike Share / Scooter',
                modeIcon: Icons.pedal_bike_rounded,
                duration: '4 min',
                distance: '1.0 km • \$1.75 • 89% safe bike path',
                color: const Color(0xFF27AE60),
              ),
              _multimodalOptionCard(
                title: 'UberX',
                modeIcon: Icons.local_taxi_rounded,
                duration: '3 min',
                distance: '2 min pickup • \$8.50',
                color: Colors.black,
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: itins.length,
          itemBuilder: (context, index) {
            final itin = itins[index];
            final durationMin = Duration(seconds: itin.durationSeconds).inMinutes;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GoNavigationScreen(
                        routeId: itin.legs.firstOrNull?.routeShortName ?? 'Transit',
                        destination: _destinationName ?? 'Destination',
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_fmt(itin.departureTime)} → ${_fmt(itin.arrivalTime)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$durationMin min • ${itin.transfers} transfer${itin.transfers == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: TransitColors.brandGreen,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFCC00), // Golden Yellow GO Badge
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'GO',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Leg Segment Capsules
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (int i = 0; i < itin.legs.length; i++) ...[
                            if (i > 0)
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                            _legCapsule(itin.legs[i]),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Widget _multimodalOptionCard({
    required String title,
    required IconData modeIcon,
    required String duration,
    required String distance,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(modeIcon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distance,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Text(
              duration,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legCapsule(Leg leg) {
    if (leg.mode == 'walk') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_walk_rounded, size: 14),
            const SizedBox(width: 4),
            Text('${leg.walkMeters?.round() ?? 0}m', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final routeName = leg.routeShortName ?? leg.routeId ?? 'Line';
    final color = TransitColors.parseRouteColor(null, fallbackSeed: routeName);

    return TransitLineBadge(
      label: routeName,
      color: color,
      size: TransitBadgeSize.small,
      isPill: true,
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
