#!/usr/bin/env bash
# Creates a Supabase Auth user for the seeded demo-metro agency and grants it
# the agency_admin role, so portal_shots.mjs (Task 19) can log in and
# capture the authenticated admin pages. Run only against a local
# `make dev-full` stack (already migrated + seeded) — never a real
# deployment. Reads JWT_SECRET/POSTGRES_PASSWORD from the environment (the
# same .env `make dev-full` uses).
set -euo pipefail
cd "$(dirname "$0")/../.."

: "${JWT_SECRET:?JWT_SECRET must be set — source .env first: set -a && source .env && set +a}"
: "${SUPABASE_URL:=http://localhost:9999}"
: "${DEMO_ADMIN_EMAIL:=demo-admin@transit.local}"
: "${DEMO_ADMIN_PASSWORD:=DemoAdmin123!}"
: "${DATABASE_URL:=postgres://postgres:${POSTGRES_PASSWORD:-postgres}@localhost:5432/postgres?sslmode=disable}"

SERVICE_ROLE_KEY="$(JWT_SECRET="$JWT_SECRET" python3 "$(dirname "$0")/mint_service_role_jwt.py")"

echo "Creating GoTrue user $DEMO_ADMIN_EMAIL..."
USER_ID=$(curl -sf -X POST "$SUPABASE_URL/admin/users" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$DEMO_ADMIN_EMAIL\",\"password\":\"$DEMO_ADMIN_PASSWORD\",\"email_confirm\":true}" \
  | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")

echo "Granting agency_admin role to $USER_ID for demo-metro..."
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<SQL
SET search_path TO transit, public, extensions, auth;
INSERT INTO user_roles (user_id, agency_id, role)
SELECT '$USER_ID'::uuid, id, 'agency_admin' FROM agencies WHERE slug = 'demo-metro'
ON CONFLICT DO NOTHING;
SQL

echo "Demo admin ready: $DEMO_ADMIN_EMAIL / $DEMO_ADMIN_PASSWORD"
