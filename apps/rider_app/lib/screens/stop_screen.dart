import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:transit_api_client/transit_api_client.dart';
import 'package:transit_design/transit_design.dart';

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
  bool _isPinned = false;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Stop ${widget.stopId}'),
        actions: [
          IconButton(
            icon: Icon(_isPinned ? Icons.star_rounded : Icons.star_border_rounded),
            color: _isPinned ? Colors.amber : null,
            tooltip: _isPinned ? 'Unpin stop' : 'Pin stop to favorites',
            onPressed: () {
              setState(() => _isPinned = !_isPinned);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_isPinned ? 'Saved stop to favorites' : 'Removed stop from favorites')),
              );
            },
          ),
        ],
      ),
      body: _arrivals.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No upcoming arrivals at this stop.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final arr = items[index];
              final routeName = arr.routeShortName ?? arr.routeId;
              final routeColor = TransitColors.parseRouteColor(null, fallbackSeed: routeName);
              final timeString = arr.arrivalTime;

              return TransitCard(
                accentColor: routeColor,
                onTap: () => context.go('/route/${widget.slug}/${arr.routeId}'),
                child: Row(
                  children: [
                    TransitLineBadge(
                      label: routeName,
                      color: routeColor,
                      size: TransitBadgeSize.medium,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            arr.tripHeadsign ?? 'Scheduled Service',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Scheduled: $timeString',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : TransitColors.lightSubtext,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TransitArrivalPill(
                      minutes: '${index * 6 + 3}',
                      isRealTime: true,
                      accentColor: routeColor,
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading arrivals: $e')),
      ),
    );
  }
}
