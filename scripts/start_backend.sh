#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

compose_file="deploy/compose/compose.yaml"
env_file=".env"
api_base_url="${API_BASE_URL:-http://localhost:8080}"
wait_seconds="${START_BACKEND_WAIT_SECONDS:-60}"

if [[ ! -f "$env_file" ]]; then
	if [[ ! -f ".env.example" ]]; then
		echo "error: .env.example is missing" >&2
		exit 1
	fi
	cp .env.example "$env_file"
	echo "Created .env from .env.example. Review it before using the stack outside local development."
fi

command -v docker >/dev/null 2>&1 || { echo "error: docker is required" >&2; exit 1; }
command -v make >/dev/null 2>&1 || { echo "error: make is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "error: curl is required" >&2; exit 1; }

echo "Starting Transit backend containers..."
docker compose -f "$compose_file" --env-file "$env_file" --profile supabase up -d --build

echo "Applying database migrations..."
make db.migrate

echo "Loading demo seed data..."
make db.seed

wait_for_api() {
	local endpoint="$1"
	local deadline=$((SECONDS + wait_seconds))

	while (( SECONDS < deadline )); do
		if curl -fsS --max-time 3 "$api_base_url$endpoint" >/dev/null 2>&1; then
			return 0
		fi
		sleep 1
	done

	echo "error: API did not become healthy at $api_base_url$endpoint" >&2
	docker compose -f "$compose_file" --env-file "$env_file" logs --tail=80 api >&2 || true
	return 1
}

echo "Waiting for API health..."
wait_for_api "/healthz"
wait_for_api "/readyz"

echo
echo "Transit backend is ready:"
echo "  API:  $api_base_url"
echo "  Auth: http://localhost:9999"
echo "  DB:   localhost:5432"
