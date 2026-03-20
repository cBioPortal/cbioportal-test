#!/bin/bash
# Build a ClickHouse Docker image pre-loaded with cBioPortal test data.
#
# This mirrors the cbioportal/mysql:8.0-database-test image but for ClickHouse.
# It starts MySQL (with pre-loaded test data), ClickHouse, runs the Sling
# importer to create all derived tables, then commits the result.
#
# Usage: ./build.sh [tag]
# Default tag: cbioportal/clickhouse:test-data

set -euo pipefail

TAG="${1:-cbioportal/clickhouse:test-data}"
NETWORK="ch-build-$$"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Building ClickHouse test data image: $TAG ==="

cleanup() {
  echo "Cleaning up..."
  docker rm -f ch-build-mysql ch-build-clickhouse 2>/dev/null || true
  docker network rm "$NETWORK" 2>/dev/null || true
}
trap cleanup EXIT

# Create isolated network
docker network create "$NETWORK"

# Start MySQL with pre-loaded test data
echo "Starting MySQL (cbioportal/mysql:8.0-database-test)..."
docker run -d --name ch-build-mysql --network "$NETWORK" \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=cbioportal \
  -e MYSQL_USER=cbio_user \
  -e MYSQL_PASSWORD=somepassword \
  cbioportal/mysql:8.0-database-test \
  --local-infile=1

# Start fresh ClickHouse
echo "Starting ClickHouse (clickhouse/clickhouse-server:24.10)..."
docker run -d --name ch-build-clickhouse --network "$NETWORK" \
  -e CLICKHOUSE_DB=cbioportal \
  -e CLICKHOUSE_USER=cbio_user \
  -e CLICKHOUSE_PASSWORD=somepassword \
  clickhouse/clickhouse-server:24.10

# Wait for MySQL
echo "Waiting for MySQL to be ready..."
for i in $(seq 1 90); do
  if docker exec ch-build-mysql mysql -ucbio_user -psomepassword cbioportal -e "SELECT 1" >/dev/null 2>&1; then
    echo "  MySQL ready after ${i}s"
    break
  fi
  sleep 2
done

# Wait for ClickHouse
echo "Waiting for ClickHouse to be ready..."
for i in $(seq 1 30); do
  if docker exec ch-build-clickhouse clickhouse-client --user cbio_user --password somepassword -q "SELECT 1" >/dev/null 2>&1; then
    echo "  ClickHouse ready after ${i}s"
    break
  fi
  sleep 2
done

# Extract ClickHouse SQL schema from cBioPortal image
echo "Extracting ClickHouse schema..."
TMPDIR=$(mktemp -d)
docker run --rm -v "$TMPDIR:/sql" cbioportal/cbioportal:6.4.1 \
  sh -c "cp /cbioportal/db-scripts/clickhouse/*.sql /sql/ 2>/dev/null"

# Clone cbioportal-docker-compose for the Sling init scripts
echo "Getting Sling init scripts..."
COMPOSE_DIR=$(mktemp -d)
git clone --depth 1 https://github.com/cBioPortal/cbioportal-docker-compose.git "$COMPOSE_DIR" 2>/dev/null

# Run Sling importer
echo "Running Sling importer (this takes ~2 minutes)..."
docker run --rm --network "$NETWORK" \
  -e MYSQL_DB=cbioportal -e MYSQL_USER=cbio_user -e MYSQL_PASSWORD=somepassword \
  -e MYSQL_HOST=ch-build-mysql -e MYSQL_PORT=3306 \
  -e "MYSQL_SERVER_ADDITIONAL_ARGS=?useSSL=false&allowPublicKeyRetrieval=true" \
  -e CLICKHOUSE_DB=cbioportal -e CLICKHOUSE_USER=cbio_user -e CLICKHOUSE_PASSWORD=somepassword \
  -e CLICKHOUSE_HOST=ch-build-clickhouse -e CLICKHOUSE_PORT=9000 \
  -e CLICKHOUSE_MAX_MEM=1000000000 -e APP_CBIOPORTAL_CORE_BRANCH=main \
  -v "$COMPOSE_DIR/addon/clickhouse/init.sh:/workdir/init.sh" \
  -v "$COMPOSE_DIR/addon/clickhouse/sync-databases.sh:/workdir/sync-databases.sh" \
  -v "$TMPDIR:/workdir/sql" \
  cbioportal/clickhouse-importer:latest bash /workdir/init.sh

# Verify
echo ""
echo "=== Verification ==="
docker exec ch-build-clickhouse clickhouse-client --user cbio_user --password somepassword \
  -d cbioportal -q "SELECT 'studies', count() FROM cancer_study FORMAT TabSeparated"
docker exec ch-build-clickhouse clickhouse-client --user cbio_user --password somepassword \
  -d cbioportal -q "SELECT 'samples', count() FROM sample_derived FORMAT TabSeparated"
docker exec ch-build-clickhouse clickhouse-client --user cbio_user --password somepassword \
  -d cbioportal -q "SELECT 'mutations', count() FROM genomic_event_derived FORMAT TabSeparated"
docker exec ch-build-clickhouse clickhouse-client --user cbio_user --password somepassword \
  -d cbioportal -q "SELECT 'clinical', count() FROM clinical_data_derived FORMAT TabSeparated"

# Commit
echo ""
echo "Committing image as $TAG..."
docker commit ch-build-clickhouse "$TAG"

# Cleanup temp dirs
rm -rf "$TMPDIR" "$COMPOSE_DIR"

echo ""
echo "=== Done! ==="
docker images "$TAG" --format "{{.Repository}}:{{.Tag}} {{.Size}}"
echo ""
echo "Push with: docker push $TAG"
