.DEFAULT_GOAL := help

COMPOSE := docker compose -f deploy/compose/compose.yaml --env-file .env

.PHONY: help dev down logs lint test gen

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

dev: ## Boot the full local stack (Postgres + PostGIS, API)
	$(COMPOSE) up --build

down: ## Stop the local stack and drop volumes
	$(COMPOSE) down -v

logs: ## Tail stack logs
	$(COMPOSE) logs -f

lint: ## Lint Go, Dart and portal code
	cd services/api && go vet ./...
	-melos run lint
	-pnpm -C apps/portal lint

test: ## Run Dart, Go and portal test suites
	cd services/api && go test ./...
	-melos run test
	-pnpm -C apps/portal test

gen: ## Regenerate server & client types from contracts/openapi.yaml
	@echo "TODO(phase 4): oapi-codegen (Go) + openapi-generator (Dart) from contracts/openapi.yaml"
