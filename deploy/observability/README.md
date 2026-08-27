# Observability (Phase 12)

What's wired into the code (`services/api/internal/telemetry`), and what's a
reference config here for you to point at a real backend — this directory
was never deployed or executed against a live collector/Grafana instance in
this session (no Docker throughout Phase 12; see `docs/PHASE_PLAN.md`).

## Traces

Every binary (`cmd/server`, `cmd/ingestor`, `cmd/tracker`, `cmd/exporter`)
calls `telemetry.Setup(ctx, serviceName)` at startup. `cmd/server` and
`cmd/exporter`'s HTTP servers are wrapped in `otelhttp.NewHandler`, so every
inbound request gets a span automatically; `cmd/tracker` and `cmd/exporter`
also emit one span per background tick (`tracker.process_open_assignments`,
`tracker.purge_old_pings`, `exporter.build_gtfs_zip`). `cmd/ingestor` gets
the SDK wired (participates in the same trace context propagation) but has
no explicit spans around `internal/ingest.Scheduler`'s per-feed sync loop
yet — that needs instrumenting the scheduler's internals, not just its
`main.go` call site, and was out of scope for this pass.

- **No `OTEL_EXPORTER_OTLP_ENDPOINT` set** (the `make dev` default): spans
  print to stdout as JSON. Useful to confirm tracing is actually wired
  without standing up a collector.
- **Set `OTEL_EXPORTER_OTLP_ENDPOINT`**: spans export via OTLP/HTTP to that
  collector. `otel-collector-config.yaml` is a reference collector config —
  receives OTLP, exports to your tracing backend (Tempo, Jaeger, or any
  OTLP-compatible one) plus a debug/logging exporter for local sanity
  checks. Point it at a real backend by editing the `exporters:` block.
- `OTEL_TRACES_SAMPLER_ARG` (0.0–1.0, default 1.0) controls the sampling
  ratio — turn this down before a high-traffic deployment.

## Structured logs

Nothing new here — every binary has logged via `slog.NewJSONHandler` since
Phase 2. `LOG_LEVEL` controls verbosity.

## Dashboards

`grafana/dashboards/transit-operations.json` — a Grafana dashboard backed
by a **Postgres datasource pointed at the same database the API uses**, not
by metrics scraped from a Prometheus pipeline (this codebase never wired a
metrics exporter, only traces — see above). Every panel is a direct SQL
query against tables that already exist:

- **API latency** (p50/p95 by endpoint) — `usage_events.latency_ms`.
- **API error rate** — `usage_events.status >= 400` over time.
- **Feed sync outcomes** — `sync_runs.status` (`success`/`partial`/`failed`)
  per adapter, over time.
- **Feed quarantine rate** — `feed_quarantine` row count over time, the
  concrete signal an upstream feed started breaking.
- **API key daily quota headroom** — `usage_summary_by_day` (the same
  SECURITY DEFINER function the portal's own `/admin/api-keys` usage chart
  calls) cross-referenced against `api_keys.quota_daily`.

Import into Grafana: **Dashboards → Import**, paste the JSON, and pick your
Postgres datasource when prompted (the JSON references a `${DS_POSTGRES}`
template variable rather than hardcoding a datasource UID).

## Alerting rules

`grafana/provisioning/alerting.yaml` — Grafana-managed alert rules
(provisioning-as-code, loaded from `/etc/grafana/provisioning/alerting/` on
Grafana startup), not Prometheus Alertmanager rules — again because the
signal source is Postgres, not a Prometheus scrape target. Rules:

1. **Feed sync failure spike** — more than 3 `failed` `sync_runs` for any
   one adapter in a rolling 15-minute window.
2. **Feed quarantine activity** — any `feed_quarantine` row in the last 5
   minutes (this table is empty in healthy operation; any row is worth a
   look).
3. **API p95 latency above 2s** — sustained for 10 minutes, any endpoint.
4. **API key exhausted its daily quota** — a key hits `quota_daily` before
   the day's window resets (a data-consumer integration silently going
   dark, not just a security signal).

Each rule's `condition` is a raw SQL query against the same tables the
dashboard reads — copy the datasource UID from your Grafana instance into
the `datasourceUid` field before provisioning (`REPLACE_WITH_DATASOURCE_UID`
placeholder in the file).

## What's not here

No Prometheus, no metrics exporter, no Tempo/Jaeger deployment, no Grafana
container in `deploy/compose/`. This directory is reference configuration
for wiring this codebase's traces and Postgres-backed operational data into
whatever observability stack an operator already runs (or stands up
separately) — not a self-contained observability stack of its own.
