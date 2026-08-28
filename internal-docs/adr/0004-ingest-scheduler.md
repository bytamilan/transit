# ADR 0004: Ingest Scheduler Architecture

## Status
Accepted

## Context
Phase 3 introduces upstream feed adapters (GTFS static, GTFS realtime, and later
SIRI). Each adapter decodes a different upstream format and normalises
it into the canonical transit schema. We need a process that:

1. Knows which feeds are configured for each agency.
2. Runs static imports on demand and realtime polls on a fixed interval.
3. Records every run, its diagnostics, and quarantines malformed payloads.
4. Survives a single bad feed without stopping the whole worker.

## Decision
Use an in-process Go scheduler backed by `time.Ticker`.

- A `Registry` maps adapter names (`gtfs_static`, `gtfs_rt`, …) to `Adapter`
  implementations.
- A `Scheduler` loads enabled rows from `transit.feeds`, looks up the adapter, and
  starts a per-feed goroutine. Realtime feeds run on their adapter-defined
  `IntervalSeconds` ticker; static feeds run once per catalogue reload.
- Sync results are written to `transit.sync_runs`; failures go to
  `transit.feed_quarantine`.
- The catalogue is reloaded every 5 minutes (configurable via `RELOAD_INTERVAL`).

The scheduler is exposed as `cmd/ingestor`, deployed as a separate Compose
service that shares the API image but overrides the command to `/ingestor`.

## Consequences
- Simple: no external scheduler (Airflow/Cron) is required for Phase 3.
- Observable: every poll and every error is stored in Postgres.
- Isolated: quarantine captures bad feeds without crashing the scheduler.
- Limitation: the scheduler runs on a single node; horizontal scaling and
  feed-level locking are deferred to Phase 4/5.

## Alternatives Considered
- **External cron / Airflow**: adds infrastructure complexity we do not need
  yet.
- **Database-driven job queue**: powerful, but overkill for the current scope.

## Phase 4 Considerations
Move to a distributed worker queue (e.g. temporal.io, NATS, or Postgres-backed
queue) with per-feed leases and back-pressure.
