# Helm Chart

Phase 12 hardening deliverable (build brief §11). The chart lives in
`deploy/helm/transit/` — four `services/api` binaries (api, ingestor,
tracker, exporter — one image, `command:` selects the binary, mirroring
`deploy/compose/compose.yaml`'s pattern) plus the Next.js portal (its own
image, built from the new `apps/portal/Dockerfile`).

**Never installed against a real cluster this session** — no Docker, no
Kubernetes, no `helm` CLI available in this sandbox. The chart was authored
by hand against Helm's standard template conventions and cross-checked
against the actual container entrypoints/env vars/health endpoints each
binary exposes (`/healthz`, `/readyz` on the API; `/healthz` on the
exporter), but `helm lint` / `helm template` / `helm install --dry-run`
were never run. Treat it as a solid starting point to validate against a
real cluster, not a proven deployment artifact.

Before installing:
1. Build and push the two images (`services/api/Dockerfile`,
   `apps/portal/Dockerfile`) to a registry `values.yaml` can reach.
2. Create the `transit-secrets` Secret the chart references (see
   `templates/NOTES.txt` for the exact keys).
3. Apply migrations (`docs/runbooks/migrations.md`) before traffic hits the
   API — this chart doesn't run them for you.
4. `helm install transit deploy/helm/transit -f your-values.yaml`

Scaling notes: `ingestor` and `tracker` are pinned to `replicaCount: 1` in
`values.yaml` by design — `internal/ingest.Scheduler` and
`tracking.Service.ProcessOpenAssignments` aren't leader-elected or
idempotent-safe across concurrent runs yet. Scaling either beyond 1 without
adding that coordination first will double-poll feeds / double-process
duty assignments.
