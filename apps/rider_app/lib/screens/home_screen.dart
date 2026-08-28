import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_core/transit_core.dart' as core;
import 'package:transit_maps/transit_maps.dart';
import '../providers/agency_provider.dart';
import '../providers/api_provider.dart';
import '../providers/locale_provider.dart';
import '../screens/about_screen.dart';
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
      appBar: AppBar(
        title: Text(title.isNotEmpty ? title : 'Transit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions),
            tooltip: 'Plan a trip',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => PlannerScreen(slug: agency.agencySlug ?? '')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          if (agency.agencySlug != null) AlertBanner(slug: agency.agencySlug!),
          Expanded(
            flex: 1,
            child: map.buildMap(
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
          ),
          Expanded(
            flex: 1,
            child: _stops.when(
              data: (items) => ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final stop = items[index];
                  return ListTile(
                    title: Text(stop.stopName),
                    subtitle: Text(stop.stopId),
                    onTap: () =>
                        context.go('/stop/${agency.agencySlug}/${stop.stopId}'),
                  );
                },
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
