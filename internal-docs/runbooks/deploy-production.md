# Deploying to production

Everything specific to a real, customer-facing (real riders, real drivers)
production environment, on top of [Deploying the dev/staging cloud
environment](deploy-dev-staging.md) — read that first; this document only
covers what's *different* for production.

> **Status**: `deploy/terraform` and `deploy/helm` were authored by hand,
> cross-checked against the code they deploy, but never installed against a
> real AWS account or Kubernetes cluster (see each directory's own README
> and `internal-docs/PHASE_PLAN.md`'s Phase 12 notes). **Do not point these
> at production without first dry-running every step
> (`terraform plan`, `helm template`/`--dry-run`) against a staging
> environment and confirming it behaves as expected.** Treat this as a
> reviewed starting point, not a proven production artifact.

## Before you start: the non-technical gate

If this deployment will track real drivers, read [Onboarding a new
agency §0](../onboarding/README.md#before-you-start-the-works-councilunion-consultation-read-this-first)
first. Several jurisdictions legally require works-council/union
consultation before continuous-shift driver location tracking goes live —
this is a process step that needs to happen *before* rollout, and nothing
in the codebase gates production traffic on it.

## 1. Infrastructure: what `environment = "production"` changes

Same `deploy/terraform/environments/reference` module as staging, different
`terraform.tfvars`:

```hcl
aws_region         = "eu-west-1"
environment        = "production"
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]   # 3 AZs for real HA

node_desired_size = 3
node_min_size     = 2
node_max_size     = 6

backup_retention_days = 30   # raise this if your RPO needs longer than 30 days

tags = { Owner = "platform-team" }
```

`environment = "production"` flips two things in the `network` and
`cluster` modules:

- **`single_nat_gateway = false`** — one NAT gateway per AZ instead of one
  shared NAT, so a single AZ's NAT failure doesn't take down outbound
  traffic for every AZ.
- **`cluster_endpoint_public_access = false`** — the EKS API server is
  **not** reachable from the public internet; administer it from a
  bastion/VPN/CI runner inside the VPC instead of directly from your
  laptop, unlike staging.

Use a **separate Terraform state** from staging — a different
`-backend-config` key (e.g. `transit/production/terraform.tfstate`), not
just a different `terraform.tfvars` against the same state. This repo's
module is the per-region building block for a multi-region SaaS topology;
running staging and production against the same state risks one
`terraform apply` clobbering the other.

```sh
cd deploy/terraform/environments/reference
terraform init -backend-config="key=transit/production/terraform.tfstate" -backend-config=...
terraform plan    # scrutinize this closely — production infra changes
terraform apply
```

## 2. Postgres

As in staging, there is no managed-database Terraform resource or Helm
subchart yet — you provision and operate Postgres yourself. For
production specifically:

- Run the exact `supabase/postgres:15.8.1.044` image pinned everywhere
  else in this repo (ADR 0001) — not a vanilla Postgres image. It bundles
  PostGIS, pg_cron, and the Supabase auth/realtime schema wiring the rest
  of the stack expects.
- Put it on infrastructure with automated failover/HA if your uptime
  requirements need it — this repo provisions the EKS cluster with the EBS
  CSI driver enabled specifically so a future StatefulSet-backed PV could
  live here, but that workload isn't built yet. Until it is, a managed EC2
  instance (or a self-managed HA Postgres cluster you already operate) is
  the pragmatic choice.
- Enforce `sslmode=require` (or stronger) on `DATABASE_URL` in production
  — the local/staging examples in this repo use `sslmode=disable`
  deliberately for zero-friction local dev; don't carry that into
  production.
- Set up the backup CronJob (§4 below) **before** go-live.

## 3. Build, sign, and deploy application images

Don't build ad-hoc images for production the way staging's quick-iteration
flow does. Use a tagged release built by CI — see [Upgrading &
releasing](upgrading.md) for the full flow. In short:

```sh
git tag v1.2.0
git push origin v1.2.0
```

`.github/workflows/release.yml` builds and pushes
`ghcr.io/<owner>/transit-api:v1.2.0` and
`ghcr.io/<owner>/transit-portal:v1.2.0`, and drafts a GitHub Release with
the commit log since the previous tag.

## 4. Secrets

Same mechanism as staging (`kubectl create secret generic transit-secrets
...`), but for production:

- Generate `JWT_SECRET` and `SECRET_KEY_BASE` fresh — never reuse a
  staging value in production, and never use the placeholder values from
  `.env.example` (`change-me-in-production` is exactly that — a
  placeholder, not a value to actually ship with).
- Use your cloud provider's secret manager (AWS Secrets Manager + the
  Secrets Store CSI driver, or equivalent) to inject `transit-secrets`
  rather than a one-off `kubectl create secret` command left in shell
  history, if your compliance posture requires it.
- Rotate `JWT_SECRET` on a schedule appropriate to your risk posture — this
  invalidates all outstanding sessions when rotated, so coordinate the
  rotation with a maintenance window or a dual-secret rollover if you need
  zero-downtime rotation (not built into GoTrue's config here — plan for
  it operationally).

## 5. Migrations — ordering matters

Exactly as in staging: **the Helm chart does not apply migrations for
you.** In production specifically, sequence this carefully around a
release:

1. Take a backup first (§4 of [Backup & restore](backup-restore.md) if you
   haven't already run the daily CronJob at least once).
2. Apply migrations against production `DATABASE_URL` — migrations in this
   repo are forward-only and written to be safe to apply ahead of the code
   that uses them (additive: new tables/columns/functions), per
   [Migrations](migrations.md)'s rules. Apply migrations *before* rolling
   out the new API image, not after.
3. Roll out the new image (§6 below).

If a migration in a given release is **not** purely additive (e.g. it
removes a column an old API version still reads), that release needs a
brief maintenance window or a two-step rollout (deploy code that stops
using the column first, then migrate) — decide this per-release, not by
default.

## 6. Rolling out with Helm

```sh
helm upgrade transit deploy/helm/transit -n transit \
  -f values-production.yaml \
  --set image.tag=v1.2.0 \
  --set portalImage.tag=v1.2.0
```

Production `values-production.yaml` differences worth being deliberate
about, beyond the registry/tag/hostnames already covered in staging:

```yaml
api:
  replicaCount: 3            # default is 2 — size to your real traffic
  resources:
    requests: { cpu: 250m, memory: 256Mi }
    limits:   { cpu: 1000m, memory: 512Mi }

portal:
  replicaCount: 3

config:
  otelExporterOTLPEndpoint: "https://<your-collector>"   # empty = stdout-only, fine for staging, not production
  otelTracesSamplerArg: "0.2"   # turn sampling down from the 1.0 dev default under real traffic volume

ingress:
  enabled: true
  tls:
    - secretName: transit-tls
      hosts: [api.transit.example, exports.transit.example, admin.transit.example]
```

**Do not scale `ingestor` or `tracker` past `replicaCount: 1`.** This is
pinned in `values.yaml` by design, not an oversight —
`internal/ingest.Scheduler` and `tracking.Service.ProcessOpenAssignments`
aren't leader-elected or safe for concurrent execution. A second replica
of either double-polls feeds or double-processes duty assignments. If you
need more throughput here, that requires adding coordination in the Go
code first, not just a `values.yaml` change.

If you scale `exporter` beyond `replicaCount: 1`, its GTFS.zip output
volume must become `ReadWriteMany` (e.g. EFS on EKS) — the chart's default
`persistence.accessMode: ReadWriteOnce` only works for a single replica.

## 7. Verify before declaring it live

- `curl https://api.transit.example/healthz` and `/readyz`
- Confirm TLS is actually terminating correctly (not just that ingress
  resolves) if this is a new domain
- Run a restore drill against this environment's backup at least once —
  see [Backup & restore](backup-restore.md)'s restore steps — **the first
  time you test a restore procedure should not be during an actual
  incident**
- Spot-check tenancy isolation on the real database: the integration
  tests in `services/api/internal/store/privilege_test.go` and
  `tenancy_test.go` are exactly what proves two agencies can't see each
  other's data
- Review `internal-docs/SECURITY_REVIEW.md` against your actual deployment
  (roles, RLS, audit logging) — it documents what's proven by test in this
  codebase, not what's true of your specific configuration

## 8. Observability

Traces are wired into every binary already (`internal/telemetry`); nothing
is exported anywhere until you point it somewhere:

```yaml
config:
  otelExporterOTLPEndpoint: "https://<your-collector>"
```

`deploy/observability/otel-collector-config.yaml` is a reference collector
config (OTLP in, your tracing backend out). The Grafana dashboard
(`deploy/observability/grafana/dashboards/transit-operations.json`) and
alert rules (`grafana/provisioning/alerting.yaml`) both query **Postgres
directly** (API latency, error rate, feed sync outcomes, quarantine
activity, API key quota headroom) — there's no Prometheus/metrics pipeline
in this repo, so point Grafana's datasource at your production database
(a read replica, ideally, not the primary) rather than standing up a
metrics scrape target that doesn't exist yet.

## Next steps

- [Upgrading & releasing](upgrading.md) — rolling out subsequent releases
- [Backup & restore](backup-restore.md)
- [Migrations](migrations.md)
