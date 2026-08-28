#!/usr/bin/env bash
# Builds a static ReDoc page from contracts/openapi.yaml for the docs site.
set -euo pipefail
cd "$(dirname "$0")/../.."

mkdir -p docs-site/docs/api
npx --yes @redocly/cli build-docs contracts/openapi.yaml -o docs-site/docs/api/index.html
