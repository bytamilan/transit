#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/scripts/start_backend.sh"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

stub_bin="$tmp_dir/bin"
mkdir -p "$stub_bin"

cat > "$stub_bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "${START_BACKEND_TEST_LOG}"
STUB

cat > "$stub_bin/make" <<'STUB'
#!/usr/bin/env bash
echo "make $*" >> "${START_BACKEND_TEST_LOG}"
STUB

cat > "$stub_bin/curl" <<'STUB'
#!/usr/bin/env bash
echo "curl $*" >> "${START_BACKEND_TEST_LOG}"
exit 0
STUB

chmod +x "$stub_bin/docker" "$stub_bin/make" "$stub_bin/curl"
log_file="$tmp_dir/commands.log"

PATH="$stub_bin:$PATH" \
START_BACKEND_TEST_LOG="$log_file" \
START_BACKEND_WAIT_SECONDS=1 \
"$script"

grep -F -- "docker compose -f deploy/compose/compose.yaml --env-file .env --profile supabase up -d --build" "$log_file" >/dev/null
grep -F -- "make db.migrate" "$log_file" >/dev/null
grep -F -- "make db.seed" "$log_file" >/dev/null
grep -F -- "curl" "$log_file" | grep -F -- "/healthz" >/dev/null
grep -F -- "curl" "$log_file" | grep -F -- "/readyz" >/dev/null

echo "start_backend.sh command flow passed"

: > "$log_file"
PATH="$stub_bin:$PATH" \
START_BACKEND_TEST_LOG="$log_file" \
"$script" --stop

grep -F -- "docker compose -f deploy/compose/compose.yaml --env-file .env --profile supabase down" "$log_file" >/dev/null
if grep -F -- "make db." "$log_file" >/dev/null; then
	echo "--stop must not run database commands" >&2
	exit 1
fi

echo "start_backend.sh --stop flow passed"
