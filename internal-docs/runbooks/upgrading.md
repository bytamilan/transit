# Upgrading & releasing

How a code change goes from merged on `main` to running in staging and
production. Covers versioning, the release pipeline, and the actual
upgrade steps for a running deployment.

## Versioning

There's no repo-wide semantic version and **no automated version
bumping**. `.github/workflows/release.yml` doesn't infer a version from
commit messages (this repo doesn't enforce Conventional Commits) — **a
human decides the next `vX.Y.Z` tag and pushes it.** If commit-driven
versioning is wanted later, `release-please` or similar is the natural
next step; it isn't built today.

There's also no persisted `CHANGELOG.md` — each release's changelog is
generated at release time from `git log` since the previous tag, and lives
only in that release's GitHub Release notes (see below).

## The release pipeline

Triggered by pushing a tag matching `v*.*.*`:

```sh
git tag v1.3.0
git push origin v1.3.0
```

`.github/workflows/release.yml` then:

1. **`build-and-push`** — builds and pushes two images to GHCR:
   - `ghcr.io/<owner>/transit-api` from `services/api/Dockerfile` (context
     `services/api`) — this single image contains all five binaries
     (`server`, `ingestor`, `feedcheck`, `tracker`, `exporter`); which one
     runs is selected by `command:` at deploy time, not by the image tag.
   - `ghcr.io/<owner>/transit-portal` from `apps/portal/Dockerfile`
     (context `.`, the repo root — it's a pnpm workspace member)

   Each image is tagged three ways: the exact semver (`v1.3.0`), the
   `major.minor` (`v1.3`), and the commit `sha`. Auth is via
   `secrets.GITHUB_TOKEN` — no separate registry credential needed.

2. **`changelog-and-release`** — diffs `git log` between this tag and the
   previous one (`git describe --tags --abbrev=0`), and creates a GitHub
   Release whose body lists every commit since the last tag plus both new
   image references.

**There is no automated deployment step.** The pipeline stops at "images
pushed, release drafted." Actually rolling those images out to a running
cluster is the manual `helm upgrade` below — nothing in this repo does
that for you today.

## Upgrading a running environment (staging or production)

Order matters — follow this sequence, don't skip ahead to the `helm
upgrade` step:

### 1. Check what's in this release

Read the GitHub Release notes for the tag you're deploying — the commit
list tells you whether this release includes a migration
(`infra/supabase/migrations/NNNN_*.sql` files touched) or is code-only.

### 2. Take a backup

Before any production upgrade that includes a migration. See [Backup &
restore](backup-restore.md). Skip this only for a code-only release with
no schema change and no data risk you're aware of — when in doubt, back up
anyway; it's cheap insurance.

### 3. Apply pending migrations

```sh
cd services/api
DATABASE_URL='<target environment's DATABASE_URL>' \
  MIGRATIONS_DIR=$PWD/../../infra/supabase/migrations \
  go run ./cmd/migrate up
```

`cmd/migrate` tracks applied migrations in `transit.schema_migrations` and
skips ones already run — safe to run this even if you're not sure whether
a given migration already landed. Every migration in this repo is written
to be additive and forward-compatible with the *previous* API version
(new tables/columns/functions, never a breaking rename in the same
migration) specifically so this step can run **before** the new image is
live without breaking the currently-running old version. If a release's
migration genuinely isn't backward-compatible, that's called out in the
release notes and needs a maintenance window instead of this normal flow
— see [Deploying to production §5](deploy-production.md#5-migrations--ordering-matters).

See [Migrations](migrations.md) for the full rules migrations in this repo
follow, and how to roll one back if it turns out to be bad.

### 4. Roll out the new images

```sh
helm upgrade transit deploy/helm/transit -n transit \
  -f values-<environment>.yaml \
  --set image.tag=v1.3.0 \
  --set portalImage.tag=v1.3.0
```

Helm performs a rolling update per Deployment — `api` and `portal` (2+
replicas by default) roll pod-by-pod with no downtime; `ingestor`,
`tracker`, and `exporter` (pinned to `replicaCount: 1`) have a brief gap
while their single pod restarts. That gap is normally fine (the ingestor
picks back up on its next `RELOAD_INTERVAL` tick, the tracker on its next
`TRACKER_TICK_INTERVAL`), but avoid upgrading during a known high-traffic
window if you want to minimize it.

### 5. Watch the rollout

```sh
kubectl rollout status -n transit deployment/transit-api
kubectl get pods -n transit -w
```

### 6. Verify

```sh
curl https://<api-host>/healthz
curl https://<api-host>/readyz
```

Spot-check whatever the release notes said changed — this repo has no
automated post-deploy smoke test, so a manual check against the actual
feature/fix in the release is the closest thing to one.

## Rolling back

**Application code**: re-run `helm upgrade` with the previous tag —
`--set image.tag=v1.2.0 --set portalImage.tag=v1.2.0`. GHCR keeps every
tagged image, so any previous release is always pullable. Or use Helm's
own history:

```sh
helm rollback transit -n transit
```

**A bad migration**: there's no automated rollback — write a new forward
migration that reverses the change (see [Migrations §Rolling back a bad
migration](migrations.md#rolling-back-a-bad-migration-once-its-live)). For
anything involving data-loss risk, restore from backup instead of trying
to migrate your way out — see [Backup & restore](backup-restore.md).

## Upgrading the Flutter apps and app-store distribution

Neither `driver_app` nor `rider_app` has an automated build/publish step in
this repo — CI only runs `flutter analyze` and `flutter test` on every
push/PR (`.github/workflows/ci.yml`'s `flutter` job, matrixed over both
apps). Cutting a release build and publishing to the Play Store / App
Store / TestFlight is a manual step outside this repo today:

```sh
cd apps/driver_app   # or apps/rider_app
flutter build apk --release     # Android
flutter build ios --release     # iOS (not yet exercised on a real device — see the app's README)
```

Bump each app's version in its own `pubspec.yaml` (`version: 0.1.0+1` —
`<semver>+<build number>`) as part of that release; it isn't tied to the
`vX.Y.Z` tags the backend/portal images use.

## Upgrading infrastructure itself (Terraform, EKS version, Helm chart)

This is a different axis from an application release — changing the
`cluster` module's `cluster_version`, node instance types, or the chart's
own templates. Treat it with the same care as a production migration:

1. Run `terraform plan` (or `helm template` for chart changes) against
   staging first, and actually apply it there before touching production.
2. For an EKS version bump specifically, check AWS's own EKS upgrade
   guidance for add-on compatibility (`coredns`, `kube-proxy`, `vpc-cni`,
   the EBS CSI driver — all managed by `modules/cluster`) before bumping
   `cluster_version`.
3. Apply to production during a maintenance window if the change touches
   the node group (a node group replacement drains and reschedules every
   pod) — not required for most `values.yaml`-only Helm changes, which
   roll out pod-by-pod like any other `helm upgrade`.

## Next steps

- [Deploying the dev/staging cloud environment](deploy-dev-staging.md)
- [Deploying to production](deploy-production.md)
- [Migrations](migrations.md)
- [Backup & restore](backup-restore.md)
