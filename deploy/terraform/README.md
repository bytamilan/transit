# Terraform Modules

For managed-SaaS and regional multi-agency deployments (build brief §2).
Phase 12 hardening deliverable.

**Never run (`terraform init`/`plan`/`apply`/`validate`) this session** — no
Terraform CLI, no AWS credentials, no cloud account available in this
sandbox. Written by hand against standard AWS provider / module syntax and
cross-checked against `docs/adr/0001-supabase-self-host-images.md`'s actual
architecture, but not validated. Treat as a reviewed starting point, not a
proven deployment artifact — the same posture as `deploy/helm/`.

## Layout

```
modules/
  network/  — VPC, public/private subnets across AZs (wraps terraform-aws-modules/vpc)
  cluster/  — EKS cluster + managed node group + EBS CSI addon (wraps terraform-aws-modules/eks)
  backup/   — S3 bucket + KMS key + IRSA role for Postgres backup artifacts
environments/
  reference/ — composes the three modules into one region's worth of infra;
               a multi-region SaaS topology is this same module, once per
               region, each with its own name_prefix/state
```

## Why no managed-database module

Transit's Postgres isn't a vanilla database — it's the
`supabase/postgres` container (PostGIS, pg_cron, and Supabase's own
auth/realtime schema wiring baked in), which a managed service like RDS
can't run as-is. So this Terraform provisions the *infrastructure* Postgres
needs (an EKS cluster with the EBS CSI driver enabled, for a
StatefulSet-backed persistent volume) rather than a managed database
resource. **Deploying Postgres itself as a Kubernetes StatefulSet isn't
built yet** — `deploy/helm/transit` currently assumes an already-reachable
`DATABASE_URL`, the same way `deploy/compose/compose.yaml`'s `api` service
does. A `postgres` subchart/manifest is the natural next piece of work here.

## Usage

```
cd environments/reference
cp terraform.tfvars.example terraform.tfvars   # edit region/AZs/sizing
terraform init
terraform plan   # never run in this session — review carefully before apply
terraform apply
aws eks update-kubeconfig --name <cluster_name> --region <region>
helm install transit ../../../helm/transit -f your-values.yaml
```

## Multi-region SaaS topology

Run `environments/reference` once per region with distinct state
(`-backend-config` or a per-region workspace), each producing its own EKS
cluster + backup bucket. Cross-region concerns (global DNS/traffic routing,
cross-region backup replication, a shared control plane) aren't modelled
here — this is the per-region building block, not the whole topology.
