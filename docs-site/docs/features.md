# Features

## Driver App (Flutter)

Mounted, always-on, near-zero-interaction terminal. The phone *is* the AVL
system: zero-touch GPS tracking, auto trip start/end, offline-first ping
queue. Confirming a duty is the only interaction a driver needs during a
shift — everything else (location reporting, trip/stop detection, occupancy
prompts) runs in the background.

## Rider App (Flutter, mobile + web)

Live vehicle map, nearby-stop arrivals, route shapes, a multimodal trip
planner, and an offline timetable fallback when connectivity drops.

## Data Portal + Admin Console (Next.js)

Two things in one app: an open-data portal (datasets, API keys, docs, usage)
for downstream consumers, and the operational back office — fleet, routes,
drivers, duty assignment, and a live dispatch board — for the agency's own
staff.

## Standards-compliant feeds

Publishable `GTFS.zip` and GTFS-Realtime (TripUpdates, VehiclePositions,
ServiceAlerts), plus GBFS — consumable by Google Maps, Moovit, Citymapper and
OpenTripPlanner with zero integration work, generated automatically from the
same data the portal and apps use.

## Multi-tenant by design

Every agency's identity, locale(s), currency, branding, map provider and
driver-ops policy is one JSON config document — nothing agency-specific is
hardcoded in the codebase. Roles are agency-scoped and server-owned (a
Supabase Auth custom access-token hook, never `user_metadata`), so one person
can hold different roles at different agencies.
