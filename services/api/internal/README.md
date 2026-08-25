# Internal Packages

| Package | Responsibility |
|---|---|
| `adapters/` | One package per upstream standard (gtfs_static, gtfs_rt, siri, netex, transxchange, gbfs, datamall, manual); each implements the `Adapter` interface and normalises into GTFS (build brief §5) |
| `ingest/` | Scheduling, normalisation, dedupe. Upsert by natural key — never truncate-and-reload |
| `gtfs/` | Canonical model, validation, export. CI runs MobilityData `gtfs-validator` against fixtures |
| `httpapi/` | Handlers, auth (Supabase JWT + hashed API key), centralised table-driven RBAC, quotas |
| `store/` | sqlc-generated queries — never hand-write SQL in handlers |
| `tracking/` | Server-side map-matching, stop events, delays. Authoritative over client-derived events |
| `dispatch/` | Duties, assignments, conflict detection, licence-expiry gating, handover state machine |
| `fusion/` | Merge crowdsourced + official signals. Every field carries `source` + `confidence`; never silently blended |
| `planner/` | RAPTOR over the in-memory timetable — not Dijkstra on a road graph |
