"use client";

import { useEffect, useRef } from "react";
import type * as maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";

// The style comes from env so the portal never hard-codes a map provider —
// point NEXT_PUBLIC_MAP_STYLE_URL at any MapLibre-compatible style JSON.
const STYLE_URL =
  process.env.NEXT_PUBLIC_MAP_STYLE_URL ?? "https://demotiles.maplibre.org/style.json";

export interface MapMarker {
  id: string;
  lat: number;
  lon: number;
  kind: "new" | "existing" | "selected";
}

interface MapViewProps {
  markers?: MapMarker[];
  onBBoxChange?: (south: number, west: number, north: number, east: number) => void;
  center?: [number, number]; // [lon, lat]
  zoom?: number;
  className?: string;
}

const MARKER_COLORS: Record<MapMarker["kind"], string> = {
  new: "#10b981", // emerald-500
  existing: "#f59e0b", // amber-500
  selected: "#3b82f6", // blue-500
};

// Minimal structural GeoJSON shapes — @types/geojson is a transitive dep of
// maplibre-gl and not directly resolvable from the portal, so we declare the
// small subset we need here (structurally assignable to GeoJSONSource data).
interface PointFeature {
  type: "Feature";
  properties: { id: string; kind: MapMarker["kind"] };
  geometry: { type: "Point"; coordinates: [number, number] };
}

interface FeatureCollection<F> {
  type: "FeatureCollection";
  features: F[];
}

function bboxPolygon(west: number, south: number, east: number, north: number) {
  return {
    type: "Feature" as const,
    properties: {},
    geometry: {
      type: "Polygon" as const,
      coordinates: [
        [
          [west, south],
          [east, south],
          [east, north],
          [west, north],
          [west, south],
        ],
      ],
    },
  };
}

// MapView renders a MapLibre map with GeoJSON circle markers and shift-drag
// bbox selection (reported via onBBoxChange). MapLibre is imported lazily
// inside useEffect so the module never evaluates during SSR.
export function MapView({ markers = [], onBBoxChange, center, zoom = 11, className }: MapViewProps) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const readyRef = useRef(false);
  const markersRef = useRef<MapMarker[]>(markers);
  markersRef.current = markers;
  const onBBoxChangeRef = useRef(onBBoxChange);
  onBBoxChangeRef.current = onBBoxChange;

  function pushMarkers() {
    const map = mapRef.current;
    if (!map || !readyRef.current) return;
    const source = map.getSource("markers") as maplibregl.GeoJSONSource | undefined;
    if (!source) return;

    const current = markersRef.current;
    const features: PointFeature[] = current.map((m) => ({
      type: "Feature",
      properties: { id: m.id, kind: m.kind },
      geometry: { type: "Point", coordinates: [m.lon, m.lat] },
    }));
    const collection: FeatureCollection<PointFeature> = {
      type: "FeatureCollection",
      features,
    };
    source.setData(collection);

    if (features.length > 0) {
      const lons = current.map((m) => m.lon);
      const lats = current.map((m) => m.lat);
      map.fitBounds(
        [
          [Math.min(...lons), Math.min(...lats)],
          [Math.max(...lons), Math.max(...lats)],
        ],
        { padding: 60, maxZoom: 15, duration: 500 }
      );
    }
  }
  const pushMarkersRef = useRef(pushMarkers);
  pushMarkersRef.current = pushMarkers;

  useEffect(() => {
    let cancelled = false;
    let map: maplibregl.Map | null = null;

    async function init() {
      const maplibregl = (await import("maplibre-gl")).default;
      if (cancelled || !containerRef.current) return;

      map = new maplibregl.Map({
        container: containerRef.current,
        style: STYLE_URL,
        center: center ?? [0, 0],
        zoom,
      });
      mapRef.current = map;
      map.addControl(new maplibregl.NavigationControl(), "top-right");

      // We implement bbox selection ourselves with shift-drag, so the
      // built-in shift-drag box zoom must not fight it.
      map.boxZoom.disable();

      map.on("load", () => {
        if (!map) return;
        map.addSource("markers", {
          type: "geojson",
          data: { type: "FeatureCollection", features: [] },
        });
        map.addLayer({
          id: "markers-circle",
          type: "circle",
          source: "markers",
          paint: {
            "circle-radius": 7,
            "circle-color": [
              "match",
              ["get", "kind"],
              "new",
              MARKER_COLORS.new,
              "existing",
              MARKER_COLORS.existing,
              MARKER_COLORS.selected,
            ],
            "circle-stroke-width": 2,
            "circle-stroke-color": "#ffffff",
          },
        });

        map.addSource("bbox", {
          type: "geojson",
          data: { type: "FeatureCollection", features: [] },
        });
        map.addLayer({
          id: "bbox-fill",
          type: "fill",
          source: "bbox",
          paint: { "fill-color": "#3b82f6", "fill-opacity": 0.12 },
        });
        map.addLayer({
          id: "bbox-outline",
          type: "line",
          source: "bbox",
          paint: { "line-color": "#3b82f6", "line-width": 2, "line-dasharray": [2, 2] },
        });

        readyRef.current = true;
        pushMarkersRef.current();
      });

      let dragStart: maplibregl.LngLat | null = null;

      map.on("mousedown", (e) => {
        if (!map || !e.originalEvent.shiftKey) return;
        e.preventDefault();
        dragStart = e.lngLat;
        map.dragPan.disable();
        map.getCanvas().style.cursor = "crosshair";
      });

      map.on("mousemove", (e) => {
        if (!map || !dragStart) return;
        setBBoxFeature(dragStart, e.lngLat);
      });

      map.on("mouseup", (e) => {
        if (!map || !dragStart) return;
        const start = dragStart;
        dragStart = null;
        map.dragPan.enable();
        map.getCanvas().style.cursor = "";
        setBBoxFeature(start, e.lngLat);
        const south = Math.min(start.lat, e.lngLat.lat);
        const north = Math.max(start.lat, e.lngLat.lat);
        const west = Math.min(start.lng, e.lngLat.lng);
        const east = Math.max(start.lng, e.lngLat.lng);
        onBBoxChangeRef.current?.(south, west, north, east);
      });

      function setBBoxFeature(a: maplibregl.LngLat, b: maplibregl.LngLat) {
        const source = map?.getSource("bbox") as maplibregl.GeoJSONSource | undefined;
        source?.setData(bboxPolygon(a.lng, a.lat, b.lng, b.lat));
      }
    }

    init();
    return () => {
      cancelled = true;
      readyRef.current = false;
      mapRef.current = null;
      map?.remove();
    };
    // The map is created once; later marker/bbox updates go through effects.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Sync markers into the GeoJSON source and fit bounds to them.
  useEffect(() => {
    pushMarkersRef.current();
  }, [markers]);

  return (
    <div
      ref={containerRef}
      className={className ?? "h-96 w-full rounded-xl border border-border/80"}
    />
  );
}
