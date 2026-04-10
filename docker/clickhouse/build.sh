#!/bin/bash
# Build the cBioPortal ClickHouse test data image.
#
# This uses the simplified ClickHouse-only approach from
# cbioportal-docker-compose#72 — no MySQL, no Sling importer.
# The image loads the base schema and seed data (genes, cancer types,
# reference genomes, genesets) via docker-entrypoint-initdb.d on first start.
#
# NOTE: This image contains reference data only. It does NOT contain test
# studies. The Go API is functional against this image (studies, samples,
# mutations endpoints return empty arrays — not errors).
#
# Usage: ./build.sh [tag]
# Default tag: cbioportal/clickhouse-test:latest

set -euo pipefail

TAG="${1:-cbioportal/clickhouse-test:latest}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SCHEMA_URL="https://raw.githubusercontent.com/cBioPortal/cbioportal/refs/heads/add-clickhoue-database-schema-and-seed/src/main/resources/db-scripts/clickhouse/init/schema.sql"
SEED_URL="https://github.com/cBioPortal/cbioportal/raw/refs/heads/add-clickhoue-database-schema-and-seed/src/main/resources/db-scripts/clickhouse/init/seed-cbioportal_hg19_hg38_v2.14.5.sql.gz"

echo "=== Building ClickHouse test data image: $TAG ==="

# Download the latest schema + seed if missing or stale (>1 day old)
refresh_file() {
  local file="$1"
  local url="$2"
  if [ ! -f "$file" ] || [ -n "$(find "$file" -mtime +1 2>/dev/null)" ]; then
    echo "Downloading $(basename "$file")..."
    curl -sfL -o "$file" "$url"
  fi
}

refresh_file "$SCRIPT_DIR/schema.sql" "$SCHEMA_URL"
refresh_file "$SCRIPT_DIR/seed.sql.gz" "$SEED_URL"

echo "Building image..."
docker build -t "$TAG" "$SCRIPT_DIR"

echo ""
echo "=== Done! ==="
docker images "$TAG" --format "{{.Repository}}:{{.Tag}} {{.Size}}"
echo ""
echo "Push with: docker push $TAG"
