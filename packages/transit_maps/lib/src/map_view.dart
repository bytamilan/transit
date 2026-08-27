import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'map_provider.dart';

/// MapLibre implementation of [MapProvider].
class MapLibreProvider implements MapProvider {
  final String styleUrl;

  MapLibreProvider({
    this.styleUrl = 'https://demotiles.maplibre.org/style.json',
  });

  @override
  Widget buildMap({
    required double initialLat,
    required double initialLon,
    required double zoom,
    required List<MapMarker> markers,
    required List<MapPolyline> polylines,
    required void Function(double lat, double lon)? onTap,
  }) {
    return MapLibreMap(
      styleString: styleUrl,
      initialCameraPosition: CameraPosition(
        target: LatLng(initialLat, initialLon),
        zoom: zoom,
      ),
      onMapCreated: (controller) async {
        for (var i = 0; i < markers.length; i++) {
          final m = markers[i];
          await controller.addSymbol(SymbolOptions(
            geometry: LatLng(m.lat, m.lon),
            iconImage: 'marker-15',
            textField: m.label,
            textOffset: const Offset(0, 1.5),
          ));
        }
      },
    );
  }
}
