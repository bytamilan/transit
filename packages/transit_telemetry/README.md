# transit_telemetry (Dart)

Ping queue, map-matching, geofencing — the on-device tracking primitives for
the driver app (build brief §4.2). Works offline; server recomputes everything
from the raw trace.

Pure Dart, no Flutter dependency, fully unit tested (`dart test .`):

- `AdaptiveSampler` — moving/idle/near-stop ping interval, driven by agency config.
- `FixValidator` — rejects poor-accuracy, implausible-speed and teleport fixes.
- `GeoKalmanFilter` — smooths a jittery GPS trace before it reaches anything else.
- `ShapeMatcher` — projects fixes onto a trip shape with monotonic `shape_dist_traveled`.
- `TripTracker` — auto-start/stop-progression/auto-end state machine (GTFS-RT `VehiclePosition.current_status` vocabulary).
- `PingQueue` / `PingStorage` — a durable, storage-agnostic offline queue; the driver app supplies the persistence.
- `TelemetryEngine` — wires all of the above into the single `onRawFix()` entry point the driver app calls.

Everything this package produces is a *hint*. The server (Phase 8)
recomputes stop events and delay authoritatively from the raw ping trace —
see build brief §4.2 and the non-negotiables checklist in §12.
