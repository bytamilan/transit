import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_api_client/transit_api_client.dart';
import '../providers/api_provider.dart';

class StopScreen extends ConsumerStatefulWidget {
  final String slug;
  final String stopId;

  const StopScreen({super.key, required this.slug, required this.stopId});

  @override
  ConsumerState<StopScreen> createState() => _StopScreenState();
}

class _StopScreenState extends ConsumerState<StopScreen> {
  late final _api = ref.read(apiClientProvider);
  var _arrivals = const AsyncValue<List<Arrival>>.loading();

  @override
  void initState() {
    super.initState();
    _loadArrivals();
  }

  Future<void> _loadArrivals() async {
    _arrivals = await AsyncValue.guard(() async {
      final response = await _api.listArrivals(
        slug: widget.slug,
        stopId: widget.stopId,
      );
      return response.data?.items.toList() ?? [];
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stop ${widget.stopId}')),
      body: _arrivals.when(
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final arr = items[index];
            return ListTile(
              title: Text('${arr.routeShortName ?? arr.routeId} → ${arr.tripHeadsign ?? ''}'),
              subtitle: Text('Arrival: ${arr.arrivalTime}'),
              onTap: () => context.go('/route/${widget.slug}/${arr.routeId}'),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Favourites storage would go here.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Favourited (stub)')),
          );
        },
        child: const Icon(Icons.favorite),
      ),
    );
  }
}
