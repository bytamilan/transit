import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_core/transit_core.dart' as core;
import 'package:transit_design/transit_design.dart';
import 'package:transit_maps/transit_maps.dart';

import '../providers/agency_provider.dart';
import '../providers/api_provider.dart';
import '../providers/locale_provider.dart';
import '../screens/planner_screen.dart';
import '../utils/localized_name.dart';
import '../widgets/alert_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.mapProvider});

  /// Overridable for tests — defaults to the real MapLibre implementation.
  final MapProvider? mapProvider;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _defaultCamera = (lat: 1.2966, lon: 103.7764);
  static const _mapProviderResolver = MapProviderResolver.defaults();

  late final _api = ref.read(apiClientProvider);
  var _stops = const AsyncValue<List<core.Stop>>.loading();

  // Transit iOS signature route color palette
  static const List<Color> _lineColors = [
    Color(0xFF22252A), // Line J/910 (Charcoal)
    Color(0xFFE20613), // Line B (Vivid Red)
    Color(0xFF993399), // Line D (Purple)
    Color(0xFFF58220), // Line 45 (Orange)
    Color(0xFF02B857), // Line 70 (Transit Green)
    Color(0xFF007AFF), // Line A (Blue)
    Color(0xFF009B77), // Line E (Teal)
    Color(0xFFDB2777), // Line M (Magenta)
  ];

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    final slug = ref.read(agencyProvider).agencySlug;
    if (slug == null) return;
    _stops = await AsyncValue.guard(() async {
      final response = await _api.listStops(slug: slug);
      return response.data?.items.map((stop) => stop.toDomain()).toList() ?? [];
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final agency = ref.watch(agencyProvider);
    final locale = ref.watch(localeProvider);
    final title = agency.agency != null
        ? localizedName(agency.agency!.name.values, locale)
        : 'Transit';

    final map = widget.mapProvider ??
        _mapProviderResolver.resolve(
          agency.config?.mapProvider ?? core.MapProviderKind.maplibre,
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // Top Map Area (45% of height)
              Expanded(
                flex: 45,
                child: Stack(
                  children: [
                    map.buildMap(
                      MapViewOptions(
                        provider:
                            agency.config?.mapProvider ?? core.MapProviderKind.maplibre,
                        initialLat: _defaultCamera.lat,
                        initialLon: _defaultCamera.lon,
                        zoom: 13,
                        markers: _stops.valueOrNull
                                ?.map((s) => MapMarker(
                                      lat: s.coordinates?.latitude ?? 0,
                                      lon: s.coordinates?.longitude ?? 0,
                                      label: s.stopName,
                                    ))
                                .toList() ??
                            [],
                        polylines: [],
                      ),
                    ),

                    // Top Floating Location Prompt Banner
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFA000), // Transit iOS Amber Banner
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.near_me_rounded, color: Colors.black87, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Tap to turn on location',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      'Automatically see transit lines around you',
                                      style: TextStyle(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Floating Profile Avatar Button
                    Positioned(
                      top: 88,
                      left: 16,
                      child: InkWell(
                        onTap: () => context.push('/profile'),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF0D5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Text('👩‍🏫', style: TextStyle(fontSize: 26)),
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.settings, color: Colors.white, size: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Floating Magenta Destination Pill
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlannerScreen(slug: agency.agencySlug ?? ''),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFBA0CBA), // Transit iOS Magenta Pill
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFBA0CBA).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Options near',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    '210 W Temple St',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.turn_right_rounded, color: Colors.white, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Full-Bleed Color-Coded Transit Lines Stack (55% of height)
              Expanded(
                flex: 55,
                child: _stops.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(child: Text('No transit lines nearby.'));
                    }
                    return ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final stop = items[index];
                        final color = _lineColors[index % _lineColors.length];
                        final lineCode = stop.stopId.length > 3
                            ? stop.stopId.substring(0, 3).toUpperCase()
                            : stop.stopId.toUpperCase();
                        final minutes = '${(index * 3 + 1)}';

                        return TransitFullBleedLineTile(
                          lineCode: lineCode,
                          destination: stop.stopName,
                          stationSubtitle: 'Spring / Temple',
                          minutes: minutes,
                          tileColor: color,
                          onTap: () => context.go(
                            '/stop/${agency.agencySlug}/${stop.stopId}',
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),

          // Service Alert Banner overlay if active
          if (agency.agencySlug != null)
            SafeArea(
              child: AlertBanner(slug: agency.agencySlug!),
            ),
        ],
      ),
    );
  }
}
