# Backup & restore runbook

Transit's only stateful component is Postgres (the self-hosted
`supabase/postgres` container, per `docs/adr/0001-supabase-self-host-images.md`) —
`cmd/exporter`'s GTFS.zip output is derived data, rebuildable from Postgres
at any time, so it isn't part of the backup story below.

**Never executed this session** — no Docker/live Postgres available, so
every command here is written against the actual schema and tooling this
repo has, but not run end-to-end. Dry-run the restore steps against a
disposable database before trusting this runbook in a real incident.

## What to back up

Everything lives in one Postgres database, schema `transit` (plus
Supabase's own `auth`/`_realtime`/`extensions` schemas if you run the full
`dev-full` profile). A full `pg_dump` of the database covers it — there's
no object storage or other stateful service to back up separately.

## Backup

### Local / `make dev`

```
docker exec transit-db pg_dump -U postgres -Fc postgres > transit-$(date +%Y%m%d-%H%M%S).dump
```

(`-Fc` = custom format — smaller, supports parallel restore and
selective table restore, unlike plain SQL dumps.)

### Production (Kubernetes / the Helm chart's topology)

A scheduled `CronJob` running `pg_dump` against `DATABASE_URL`, piping the
output to the S3 bucket `deploy/terraform/modules/backup` provisions:

```yaml
# Reference — not yet added to deploy/helm/transit; see that chart's README
# for why Postgres itself isn't deployed by this chart yet.
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 3 * * *" # daily at 03:00 UTC — adjust to your RPO needs
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: postgres-backup # IRSA-annotated with the backup module's role ARN
          containers:
            - name: backup
              image: postgres:15
              command:
                - sh
                - -c
                - |
                  set -eu
                  pg_dump -Fc "$DATABASE_URL" > /tmp/backup.dump
                  aws s3 cp /tmp/backup.dump "s3://$BACKUP_BUCKET/$(date +%Y/%m/%d)/transit.dump"
              env:
                - { name: DATABASE_URL, valueFrom: { secretKeyRef: { name: transit-secrets, key: DATABASE_URL } } }
                - { name: BACKUP_BUCKET, value: "<from deploy/terraform environments/reference output>" }
          restartPolicy: OnFailure
```

Retention: `deploy/terraform/modules/backup`'s `retention_days` variable
(default 30) controls how long S3 keeps backup objects before expiring
them — that's your recovery-point-objective bound. Raise it if your RPO
requirements need longer retention than that.

## Restore

### From a local dump

```
# Against a fresh/empty database:
pg_restore -U postgres -d postgres --clean --if-exists transit-20260101-030000.dump
```

`--clean --if-exists` drops existing objects before recreating them, so
this is safe to run against a database that already has (possibly stale)
schema in it — it won't error on "already exists."

### From S3 (production)

```
aws s3 cp s3://<bucket>/2026/01/01/transit.dump ./transit.dump
pg_restore --dbname "$DATABASE_URL" --clean --if-exists transit.dump
```

### After restoring

1. Run `make db.migrate` (or the CronJob/init-container equivalent) —
   the dump is only as current as its backup time; any migration merged
   after that backup needs to be re-applied.
2. Verify RLS and role grants survived the restore: `pg_restore` restores
   role membership and `GRANT`s as recorded in the dump, but if the
   restore target is a *different* cluster (disaster recovery to a new
   environment, not just the same one), confirm the `transit_app` role
   and its password/connection details match what `DATABASE_URL` expects —
   `pg_dump`/`pg_restore` don't create the role itself, only what it owns
   and its grants.
3. Spot-check tenancy isolation didn't regress: run
   `services/api/internal/store/privilege_test.go` and
   `tenancy_test.go` (`go test -tags integration ./internal/store/...`)
   against the restored database before considering it production-ready
   again — these are exactly the tests that prove cross-agency isolation
   (build brief §12's "two agencies ... cannot see each other's data —
   proven by test, not by inspection").

## What this runbook does not cover

- **Point-in-time recovery** (WAL archiving/continuous backup) — this
  runbook is daily-snapshot-based (`pg_dump`), which bounds your RPO to
  "since the last daily backup," not "any point in time." A managed
  Postgres service with PITR, or `pgBackRest`/WAL-G against the
  self-hosted container, is the upgrade path if a tighter RPO is needed —
  not built this session.
- **Cross-region backup replication** for the multi-region SaaS topology —
  each region's backup bucket is independent; replicating backups
  cross-region for regional-failure DR isn't modelled in
  `deploy/terraform` yet.
