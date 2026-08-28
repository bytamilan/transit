# Deploying the dev/staging cloud environment

A shared, cloud-hosted environment for integration testing, demoing to a
real agency, or QA — as opposed to [local development](deploy-local.md) on
your own machine, or [production](deploy-production.md) serving real
riders/drivers. Built from the same two artifacts production uses
(`deploy/terraform`, `deploy/helm`), with looser settings selected by
Terraform's `environment` variable.

> **Status**: `deploy/terraform` and `deploy/helm` were authored by hand
> against standard Terraform/Helm conventions and cross-checked against the
> actual code they deploy, but neither has been run against a real AWS
> account or Kubernetes cluster (see each directory's own README). Treat
> this guide as a reviewed starting point — dry-run every step
> (`terraform plan`, `helm template` / `helm install --dry-run`) before
> trusting it, and expect to fix small things on the first real run.

## What you're deploying

| Layer | Tool | What it provisions |
|---|---|---|
| Infrastructure | `deploy/terraform/environments/reference` | VPC, EKS cluster + node group, S3 backup bucket + IRSA role |
| Application | `deploy/helm/transit` | `api`, `ingestor`, `tracker`, `exporter` Deployments + the `portal` Deployment, onto that cluster |

There is **no managed-database resource** — Transit's Postgres is the
`supabase/postgres` container (PostGIS, pg_cron, Supabase's auth/realtime
schema wiring baked in), which a service like RDS can't run as-is. Terraform
provisions the EKS cluster with the EBS CSI driver enabled (for a future
StatefulSet-backed PV), but **Postgres itself as a Kubernetes workload isn't
built yet** — both the Helm chart and `deploy/compose/compose.yaml` assume
an already-reachable `DATABASE_URL`. For a dev/staging environment, the
simplest path today is a Postgres instance you stand up yourself (a small
EC2 instance running `supabase/postgres`, or any Postgres 15+ with
PostGIS/pg_cron) and point `DATABASE_URL` at it — see [What's missing
below](#whats-missing-before-a-first-real-run).

## Prerequisites

- AWS account + credentials with permission to create VPCs, EKS clusters,
  IAM roles, S3 buckets
- Terraform CLI (`~> 1.x`, AWS provider `~> 5.0`)
- `aws` CLI, `kubectl`, `helm` (3.x)
- A container registry both images can be pushed to and the cluster can
  pull from (this repo's own CI pushes to GHCR — see
  [Upgrading & releasing](upgrading.md))
- A reachable Postgres instance (see above) with migrations applied

## 1. Provision infrastructure with Terraform

```sh
cd deploy/terraform/environments/reference
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` for this environment:

```hcl
aws_region         = "eu-west-1"
environment        = "staging"          # loosens NAT redundancy + allows a public EKS API endpoint
availability_zones = ["eu-west-1a", "eu-west-1b"]

node_desired_size = 3
node_min_size     = 2
node_max_size     = 6

backup_retention_days = 30

tags = { Owner = "platform-team" }
```

`environment = "staging"` (the default) sets `single_nat_gateway = true`
(one shared NAT instead of one per AZ — cheaper, less HA) and
`cluster_endpoint_public_access = true` (the EKS API server is reachable
from your laptop without a VPN/bastion) — both intentionally looser than
production. See [Production](deploy-production.md) for what flips.

**State storage**: no Terraform backend is pre-configured — add one before
your first `apply` so state isn't only on your laptop:

```sh
terraform init \
  -backend-config="bucket=<your-tfstate-bucket>" \
  -backend-config="key=transit/staging/terraform.tfstate" \
  -backend-config="region=eu-west-1"
```

(or a `backend` block in a `backend.tf` you add — either works; this repo
doesn't ship one, since the right bucket/key is deployment-specific.)

Then:

```sh
terraform init
terraform plan     # review carefully — this creates real billable AWS resources
terraform apply
```

Useful outputs (`deploy/terraform/environments/reference/outputs.tf`):

```sh
terraform output cluster_name
terraform output cluster_endpoint
terraform output backup_bucket_name
terraform output kubeconfig_command   # ready-to-run `aws eks update-kubeconfig ...`
```

Point `kubectl`/`helm` at the new cluster:

```sh
$(terraform output -raw kubeconfig_command)
# equivalent to: aws eks update-kubeconfig --name <cluster_name> --region eu-west-1
```

## 2. Build and push the application images

Terraform gives you a cluster; it doesn't build or push images. For a
staging deploy ahead of a tagged release, build directly from your branch:

```sh
docker build -t <your-registry>/transit-api:staging -f services/api/Dockerfile services/api
docker push <your-registry>/transit-api:staging

docker build -t <your-registry>/transit-portal:staging -f apps/portal/Dockerfile .
docker push <your-registry>/transit-portal:staging
```

(Built from the repo root for the portal image — it's a pnpm workspace
member, not a standalone package; see the `Dockerfile`'s own comment.)

For a build already tagged and pushed by CI, see [Upgrading &
releasing](upgrading.md) instead — `ghcr.io/<owner>/transit-api:vX.Y.Z`
and `ghcr.io/<owner>/transit-portal:vX.Y.Z`.

## 3. Create the cluster secret

The Helm chart never templates secrets from `values.yaml` — create the
Kubernetes Secret it references out-of-band:

```sh
kubectl create namespace transit   # or your chosen namespace

kubectl create secret generic transit-secrets -n transit \
  --from-literal=DATABASE_URL='postgres://transit_app:...@<your-postgres-host>:5432/postgres?sslmode=require&search_path=transit,public,extensions,auth' \
  --from-literal=JWT_SECRET='<generate a real secret>' \
  --from-literal=SUPABASE_ANON_KEY='<from your auth deployment, if running one>'
```

Optional keys the chart also reads if present: `GOTRUE_ADMIN_URL`,
`SUPABASE_SERVICE_ROLE_KEY`.

## 4. Apply migrations before deploying the API

**The Helm chart does not run migrations for you.** Run them against the
staging `DATABASE_URL` before the API deployment can serve real traffic:

```sh
cd services/api
DATABASE_URL='<the same URL you put in transit-secrets>' \
  MIGRATIONS_DIR=$PWD/../../infra/supabase/migrations \
  go run ./cmd/migrate up
```

(or build `./bin/migrate` once and reuse it — see `make db.build`.) See
[Migrations](migrations.md) for the full runbook.

## 5. Install the Helm chart

Create a `values-staging.yaml` overriding the chart's defaults for this
environment:

```yaml
image:
  repository: <your-registry>/transit-api
  tag: "staging"
portalImage:
  repository: <your-registry>/transit-portal
  tag: "staging"

portal:
  env:
    nextPublicApiBaseUrl: "https://api-staging.transit.example"
    nextPublicExporterBaseUrl: "https://exports-staging.transit.example"
    nextPublicSupabaseUrl: "https://auth-staging.transit.example"

ingress:
  enabled: true
  className: "<your ingress class, e.g. nginx or alb>"
  api:
    host: api-staging.transit.example
  exporter:
    host: exports-staging.transit.example
  portal:
    host: admin-staging.transit.example
```

```sh
helm install transit deploy/helm/transit -n transit -f values-staging.yaml
```

Dry-run first if this is your first time touching this environment:

```sh
helm template transit deploy/helm/transit -n transit -f values-staging.yaml
helm install transit deploy/helm/transit -n transit -f values-staging.yaml --dry-run
```

Watch it come up:

```sh
kubectl get pods -n transit -w
```

No ingress yet? Port-forward instead:

```sh
kubectl port-forward -n transit svc/transit-api 8080:8080
```

## 6. Verify

```sh
curl https://api-staging.transit.example/healthz
curl https://api-staging.transit.example/v0/agencies/demo-metro   # if you seeded demo data
```

## What's missing before a first real run

Be upfront with whoever's provisioning this that these gaps exist today —
none are hard blockers, but each needs a decision before go-live:

- **No Postgres deployment in the chart or Terraform.** You need to stand
  one up yourself (self-managed EC2 running `supabase/postgres`, or any
  Postgres 15+ with PostGIS + pg_cron) and manage its backups/upgrades
  separately from everything in this repo, until a `postgres` subchart
  exists.
- **No Terraform backend pre-wired.** You must add `-backend-config` (or a
  `backend.tf`) yourself before a real `apply`, per step 1 above.
- **Neither `deploy/terraform` nor `deploy/helm` has been run against a
  real account/cluster.** `terraform plan` and `helm template` are not
  optional dry runs here — they're how you catch the first real bugs.

## Next steps

- [Deploying to production](deploy-production.md) — what's stricter for a
  real, customer-facing environment
- [Upgrading & releasing](upgrading.md) — rolling a new image tag out to
  this environment
- [Backup & restore](backup-restore.md)
- `deploy/observability/README.md` — wiring traces once you have a
  collector
