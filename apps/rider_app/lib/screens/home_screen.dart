import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_maps/transit_maps.dart';
import '../providers/agency_provider.dart';
import '../providers/api_provider.dart';
import '../screens/about_screen.dart';
import '../screens/planner_screen.dart';
import '../widgets/alert_banner.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final _api = ref.read(apiClientProvider);
  final _map = MapLibreProvider();
  var _stops = const AsyncValue<List<Stop>>.loading();

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
      return response.data?.items.toList() ?? [];
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final agency = ref.watch(agencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(agency.agency?.name['en'] ?? 'Transit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions),
            tooltip: 'Plan a trip',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlannerScreen(slug: agency.agencySlug ?? '')),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          if (agency.agencySlug != null) AlertBanner(slug: agency.agencySlug!),
          Expanded(
            flex: 1,
            child: _map.buildMap(
              initialLat: agency.config?.branding != null ? 1.2966 : 34.0522,
              initialLon: agency.config?.branding != null ? 103.7764 : -118.2437,
              zoom: 13,
              markers: _stops.valueOrNull?.map((s) => MapMarker(
                    lat: s.stopLat ?? 0,
                    lon: s.stopLon ?? 0,
                    label: s.stopName,
                  )).toList() ?? [],
              polylines: [],
              onTap: null,
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
                    onTap: () => context.go('/stop/${agency.agencySlug}/${stop.stopId}'),
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
