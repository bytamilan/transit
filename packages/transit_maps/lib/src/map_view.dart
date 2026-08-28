import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'map_provider.dart';

/// MapLibre implementation of [MapProvider].
class MapLibreProvider implements MapProvider {
  final String styleUrl;

  const MapLibreProvider({
    this.styleUrl = 'https://demotiles.maplibre.org/style.json',
  });

  @override
  Widget buildMap(MapViewOptions options) {
    MapLibreMapController? controller;

    Future<void> addAnnotations() async {
      final mapController = controller;
      if (mapController == null) return;
      for (final marker in options.markers) {
        await mapController.addSymbol(SymbolOptions(
          geometry: LatLng(marker.lat, marker.lon),
          iconImage: 'marker-15',
          iconColor: marker.color == null ? null : _hexColor(marker.color!),
          textField: marker.label,
          textOffset: const Offset(0, 1.5),
        ));
      }
      for (final polyline in options.polylines) {
        await mapController.addLine(LineOptions(
          geometry: polyline.points
              .map((point) => LatLng(point.lat, point.lon))
              .toList(growable: false),
          lineColor: _hexColor(polyline.color),
          lineOpacity: polyline.color.a,
          lineWidth: polyline.width,
        ));
      }
    }

    return MapLibreMap(
      styleString: styleUrl,
      initialCameraPosition: CameraPosition(
        target: LatLng(options.initialLat, options.initialLon),
        zoom: options.zoom,
      ),
      onMapCreated: (createdController) => controller = createdController,
      onStyleLoadedCallback: addAnnotations,
      onMapClick: (_, latLng) =>
          options.onMapClick?.call(latLng.latitude, latLng.longitude),
    );
  }
}

String _hexColor(Color color) =>
    '#${(color.r * 255).round().toRadixString(16).padLeft(2, '0')}${(color.g * 255).round().toRadixString(16).padLeft(2, '0')}${(color.b * 255).round().toRadixString(16).padLeft(2, '0')}';
