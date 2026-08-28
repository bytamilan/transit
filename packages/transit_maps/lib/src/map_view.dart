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
      await MapLibreAnnotationForwarder().forward(
        _MapLibreControllerSink(mapController),
        options,
      );
    }

    return MapLibreMap(
      styleString: styleUrl,
      initialCameraPosition: CameraPosition(
        target: LatLng(options.initialLat, options.initialLon),
        zoom: options.zoom,
      ),
      onMapCreated: (createdController) => controller = createdController,
      onStyleLoadedCallback: addAnnotations,
      onMapClick: (_, latLng) => forwardMapClick(options, latLng),
    );
  }
}

/// Testable boundary for forwarding provider-neutral map primitives to
/// MapLibre annotations.
abstract interface class MapLibreAnnotationSink {
  Future<void> addMarker(MapMarker marker);
  Future<void> addPolyline(MapPolyline polyline);
}

class MapLibreAnnotationForwarder {
  Future<void> forward(
    MapLibreAnnotationSink sink,
    MapViewOptions options,
  ) async {
    for (final marker in options.markers) {
      await sink.addMarker(marker);
    }
    for (final polyline in options.polylines) {
      await sink.addPolyline(polyline);
    }
  }
}

void forwardMapClick(MapViewOptions options, LatLng latLng) {
  options.onMapClick?.call(latLng.latitude, latLng.longitude);
}

class _MapLibreControllerSink implements MapLibreAnnotationSink {
  _MapLibreControllerSink(this._controller);

  final MapLibreMapController _controller;

  @override
  Future<void> addMarker(MapMarker marker) => _controller.addSymbol(
        SymbolOptions(
          geometry: LatLng(marker.lat, marker.lon),
          iconImage: 'marker-15',
          iconColor: marker.color == null ? null : _hexColor(marker.color!),
          textField: marker.label,
          textOffset: const Offset(0, 1.5),
        ),
      );

  @override
  Future<void> addPolyline(MapPolyline polyline) => _controller.addLine(
        LineOptions(
          geometry: polyline.points
              .map((point) => LatLng(point.lat, point.lon))
              .toList(growable: false),
          lineColor: _hexColor(polyline.color),
          lineOpacity: polyline.color.a,
          lineWidth: polyline.width,
        ),
      );
}

/// Protomaps tiles rendered through MapLibre with a distinct production style.
class ProtomapsProvider extends MapLibreProvider {
  const ProtomapsProvider({
    super.styleUrl = 'https://api.protomaps.com/styles/v2/light.json',
  });
}

String _hexColor(Color color) =>
    '#${(color.r * 255).round().toRadixString(16).padLeft(2, '0')}${(color.g * 255).round().toRadixString(16).padLeft(2, '0')}${(color.b * 255).round().toRadixString(16).padLeft(2, '0')}';
