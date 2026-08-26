-include .env
export

.DEFAULT_GOAL := help

COMPOSE := docker compose -f deploy/compose/compose.yaml --env-file .env

POSTGRES_PASSWORD ?= postgres
POSTGRES_DB ?= postgres
SEARCH_PATH ?= transit,public,extensions,auth
DB_URL ?= postgres://postgres:$(POSTGRES_PASSWORD)@localhost:5432/$(POSTGRES_DB)?sslmode=disable&search_path=$(SEARCH_PATH)
MIGRATIONS_DIR ?= $(PWD)/infra/supabase/migrations
SEED_DIR ?= $(PWD)/infra/supabase/seed

TEST_DB_IMAGE ?= supabase/postgres:15.8.1.044
TEST_DB_PORT ?= 5433
TEST_DB_PASSWORD ?= postgres
TEST_DB_URL ?= postgres://transit_app:transit_app@localhost:$(TEST_DB_PORT)/postgres?sslmode=disable&search_path=$(SEARCH_PATH)
MIGRATE_TEST_DB_URL ?= postgres://postgres:$(TEST_DB_PASSWORD)@localhost:$(TEST_DB_PORT)/postgres?sslmode=disable&search_path=$(SEARCH_PATH)

# Use the Postgres image itself for psql so macOS hosts do not need a local client.
# psql/libpq do not accept search_path as a URI parameter, so we keep this URL
# plain; seed/migration files set search_path explicitly.
DB_URL_DOCKER ?= postgres://postgres:$(POSTGRES_PASSWORD)@host.docker.internal:5432/$(POSTGRES_DB)?sslmode=disable
PSQL := docker run --rm -e PGPASSWORD=$(POSTGRES_PASSWORD) -v "$(PWD)/infra/supabase:/infra/supabase" $(TEST_DB_IMAGE) psql
TEST_PSQL := docker exec -e PGPASSWORD=$(TEST_DB_PASSWORD) transit-test-db psql

.PHONY: help dev down logs lint test gen db.migrate db.seed db.test

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

.env:
	@cp .env.example .env
	@echo "Created .env from .env.example — review it before a real deployment."

dev: .env ## Boot the core local stack (Postgres + PostGIS + API)
	$(COMPOSE) up --build

dev-full: ## Boot the full local stack including Supabase Auth, REST and Realtime
	$(COMPOSE) --profile supabase up --build

down: ## Stop the local stack and drop volumes
	$(COMPOSE) down -v

logs: ## Tail stack logs
	$(COMPOSE) logs -f

lint: ## Lint Go, Dart and portal code
	cd services/api && go vet ./...
	-melos run lint
	-pnpm -C apps/portal lint

test: ## Run Go unit tests (no database required)
	cd services/api && go test -short ./...

gen: ## Regenerate server & client types from contracts/openapi.yaml
	@echo "TODO(phase 4): oapi-codegen (Go) + openapi-generator (Dart) from contracts/openapi.yaml"

db.build: ## Build the migration runner binary
	cd services/api && go build -o bin/migrate ./cmd/migrate

db.migrate: db.build ## Apply all pending migrations to DATABASE_URL
	cd services/api && DATABASE_URL="$(DB_URL)" MIGRATIONS_DIR="$(MIGRATIONS_DIR)" ./bin/migrate up

db.seed: ## Apply seed fixtures to DATABASE_URL (idempotent)
	$(PSQL) "$(DB_URL_DOCKER)" -f "/infra/supabase/seed/demo_agencies.sql"

db.reset: db.build ## Drop and recreate the database at DATABASE_URL
	cd services/api && DATABASE_URL="$(DB_URL)" ./bin/migrate reset

db.test: db.build ## Start a test PostGIS container, migrate, seed, run integration tests, then stop
	@echo "Starting test database on port $(TEST_DB_PORT)..."
	@docker run --rm -d \
		--name transit-test-db \
		-e POSTGRES_PASSWORD=$(TEST_DB_PASSWORD) \
		-v "$(PWD)/infra/supabase:/infra/supabase" \
		-p $(TEST_DB_PORT):5432 \
		$(TEST_DB_IMAGE) > /dev/null
	@echo "Waiting for Postgres to be ready..."
	@for i in $$(seq 1 60); do \
		if docker exec -e PGPASSWORD=$(TEST_DB_PASSWORD) transit-test-db psql \
			"postgres://postgres:$(TEST_DB_PASSWORD)@localhost/postgres?sslmode=disable" \
			-c "SELECT 1;" > /dev/null 2>&1; then \
			echo "Postgres ready"; \
			break; \
		fi; \
		sleep 1; \
	done
	cd services/api && DATABASE_URL="$(MIGRATE_TEST_DB_URL)" MIGRATIONS_DIR="$(MIGRATIONS_DIR)" ./bin/migrate up
	$(TEST_PSQL) "postgres://postgres:$(TEST_DB_PASSWORD)@localhost/postgres?sslmode=disable" -f "/infra/supabase/seed/demo_agencies.sql"
	cd services/api && DATABASE_URL="$(TEST_DB_URL)" go test -tags integration ./internal/store/...
	@docker stop transit-test-db > /dev/null
	@echo "Test database stopped."
