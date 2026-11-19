#!/bin/bash
# Build the cBioPortal ClickHouse test data image.
#
# This uses the simplified ClickHouse-only approach from
# cbioportal-docker-compose#72 (no docker compose with MySQL needed at
# *runtime*) but still imports test studies from the existing
# cbioportal/mysql:8.0-database-test image during *build time*, so the
# resulting image is fully populated and self-contained.
#
# Build flow:
# 1. Download the upstream ClickHouse schema + seed (genes, cancer types, etc.)
# 2. Build a base image that loads them via docker-entrypoint-initdb.d
# 3. Start MySQL (with test studies) + ClickHouse (from the base image)
# 4. Run the Sling importer to copy study data MySQL → ClickHouse
# 5. Snapshot the populated ClickHouse data and bake it into the final image
#
# Usage: ./build.sh [tag]
# Default tag: cbioportal/clickhouse-test:latest

set -euo pipefail

TAG="${1:-cbioportal/clickhouse-test:latest}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SCHEMA_URL="https://raw.githubusercontent.com/cBioPortal/cbioportal/refs/heads/add-clickhoue-database-schema-and-seed/src/main/resources/db-scripts/clickhouse/init/schema.sql"
SEED_URL="https://github.com/cBioPortal/cbioportal/raw/refs/heads/add-clickhoue-database-schema-and-seed/src/main/resources/db-scripts/clickhouse/init/seed-cbioportal_hg19_hg38_v2.14.5.sql.gz"

NETWORK="ch-build-$$"
BASE_IMAGE="cbioportal/clickhouse-test-base:build"

echo "=== Building ClickHouse test data image: $TAG ==="

cleanup() {
  echo "Cleaning up..."
  docker rm -f ch-build-mysql ch-build-clickhouse ch-build-importer 2>/dev/null || true
  docker network rm "$NETWORK" 2>/dev/null || true
  [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR" || true
}
trap cleanup EXIT

# 1. Download schema + seed if missing or stale (>1 day old)
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

# 2. Build base image with schema + seed init scripts
echo "Building base image (schema + seed)..."
docker build -q -t "$BASE_IMAGE" "$SCRIPT_DIR"

# 3. Start MySQL (with test studies) + ClickHouse (base image)
docker network create "$NETWORK"

echo "Starting MySQL (cbioportal/mysql:8.0-database-test)..."
docker run -d --name ch-build-mysql --network "$NETWORK" \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_DATABASE=cbioportal \
  -e MYSQL_USER=cbio_user \
  -e MYSQL_PASSWORD=somepassword \
  cbioportal/mysql:8.0-database-test \
  --local-infile=1 >/dev/null

echo "Starting ClickHouse (base image with schema + seed)..."
docker run -d --name ch-build-clickhouse --network "$NETWORK" \
  -e CLICKHOUSE_DB=cbioportal \
  -e CLICKHOUSE_USER=cbio_user \
  -e CLICKHOUSE_PASSWORD=somepassword \
  "$BASE_IMAGE" >/dev/null

# Wait for MySQL via TCP from another container (inside-container readiness
# isn't enough — MySQL listens on socket before TCP).
echo "Waiting for MySQL to be ready (TCP)..."
MYSQL_READY=0
for i in $(seq 1 90); do
  if docker run --rm --network "$NETWORK" mysql:8.0 \
    mysql -hch-build-mysql -ucbio_user -psomepassword cbioportal -e "SELECT 1" >/dev/null 2>&1; then
    echo "  MySQL ready after $((i * 5))s"
    MYSQL_READY=1
    break
  fi
  sleep 5
done
if [ "$MYSQL_READY" -ne 1 ]; then
  echo "MySQL did not become ready within $((90 * 5))s" >&2
  exit 1
fi

# Wait for ClickHouse to finish loading the seed (gene table populated)
echo "Waiting for ClickHouse to finish loading seed..."
CH_READY=0
for i in $(seq 1 60); do
  ROWS=$(docker exec ch-build-clickhouse clickhouse-client --user cbio_user --password somepassword \
    -d cbioportal -q "SELECT count() FROM gene" 2>/dev/null || echo 0)
  if [ "${ROWS:-0}" -gt 0 ]; then
    echo "  ClickHouse seed loaded after $((i * 5))s ($ROWS genes)"
    CH_READY=1
    break
  fi
  sleep 5
done
if [ "$CH_READY" -ne 1 ]; then
  echo "ClickHouse seed did not finish loading within $((60 * 5))s" >&2
  exit 1
fi

# 4. Run Sling importer to copy study data MySQL → ClickHouse
# We start init.sh in detached mode (it ends with `tail -f /dev/null` so the
# container would otherwise run forever) and poll for the
# /workdir/init-complete.txt file that init.sh touches when done.
echo "Running Sling importer..."
TMPDIR=$(mktemp -d)
COMPOSE_DIR="$TMPDIR/compose"
git clone --depth 1 https://github.com/cBioPortal/cbioportal-docker-compose.git "$COMPOSE_DIR" >/dev/null 2>&1

# Extract the ClickHouse derived-table SQL scripts from the cbioportal image
SQLDIR="$TMPDIR/sql"
mkdir -p "$SQLDIR"
docker run --rm -v "$SQLDIR:/sql" cbioportal/cbioportal:6.4.1 \
  sh -c "cp /cbioportal/db-scripts/clickhouse/*.sql /sql/ 2>/dev/null"

docker run -d --name ch-build-importer --network "$NETWORK" \
  -e MYSQL_DB=cbioportal -e MYSQL_USER=cbio_user -e MYSQL_PASSWORD=somepassword \
  -e MYSQL_HOST=ch-build-mysql -e MYSQL_PORT=3306 \
  -e "MYSQL_SERVER_ADDITIONAL_ARGS=?useSSL=false&allowPublicKeyRetrieval=true" \
  -e CLICKHOUSE_DB=cbioportal -e CLICKHOUSE_USER=cbio_user -e CLICKHOUSE_PASSWORD=somepassword \
  -e CLICKHOUSE_HOST=ch-build-clickhouse -e CLICKHOUSE_PORT=9000 \
  -e CLICKHOUSE_MAX_MEM=1000000000 -e APP_CBIOPORTAL_CORE_BRANCH=main \
  -v "$COMPOSE_DIR/addon/clickhouse/init.sh:/workdir/init.sh" \
  -v "$COMPOSE_DIR/addon/clickhouse/sync-databases.sh:/workdir/sync-databases.sh" \
  -v "$SQLDIR:/workdir/sql" \
  cbioportal/clickhouse-importer:latest bash /workdir/init.sh >/dev/null

echo "Waiting for Sling import to complete (this can take a few minutes)..."
IMPORT_DONE=0
for i in $(seq 1 120); do
  if docker exec ch-build-importer test -f /workdir/init-complete.txt 2>/dev/null; then
    echo "  Import complete after $((i * 5))s"
    IMPORT_DONE=1
    break
  fi
  # Check the importer didn't crash
  if ! docker ps --filter "name=ch-build-importer" --format "{{.Names}}" | grep -q ch-build-importer; then
    echo "Importer container exited unexpectedly:" >&2
    docker logs ch-build-importer 2>&1 | tail -30 >&2
    exit 1
  fi
  sleep 5
done
docker logs ch-build-importer 2>&1 | tail -10
docker rm -f ch-build-importer >/dev/null 2>&1
if [ "$IMPORT_DONE" -ne 1 ]; then
  echo "Sling import did not finish within $((120 * 5))s" >&2
  exit 1
fi

# 5. Verify and snapshot
echo ""
echo "=== Verification ==="
docker exec ch-build-clickhouse clickhouse-client --user cbio_user --password somepassword \
  -d cbioportal -q "SELECT 'studies', count() FROM cancer_study FORMAT TabSeparated"
docker exec ch-build-clickhouse clickhouse-client --user cbio_user --password somepassword \
  -d cbioportal -q "SELECT 'samples', count() FROM sample_derived FORMAT TabSeparated"
docker exec ch-build-clickhouse clickhouse-client --user cbio_user --password somepassword \
  -d cbioportal -q "SELECT 'genes', count() FROM gene FORMAT TabSeparated"

# Stop ClickHouse cleanly and copy data out (volumes are not captured by
# docker commit, so we copy /var/lib/clickhouse out and bake it into a
# fresh image via docker build COPY).
echo ""
echo "Stopping ClickHouse and copying data out of volume..."
docker exec ch-build-clickhouse clickhouse-client --user cbio_user --password somepassword \
  -q "SYSTEM FLUSH LOGS" 2>/dev/null || true
docker stop ch-build-clickhouse >/dev/null

DATADIR="$TMPDIR/data"
mkdir -p "$DATADIR"
docker cp ch-build-clickhouse:/var/lib/clickhouse/. "$DATADIR/"

echo "Building final image as $TAG..."
cat > "$DATADIR/Dockerfile" <<'DEOF'
FROM clickhouse/clickhouse-server:24.5
COPY --chown=clickhouse:clickhouse . /var/lib/clickhouse/
ENV CLICKHOUSE_DB=cbioportal
ENV CLICKHOUSE_USER=cbio_user
ENV CLICKHOUSE_PASSWORD=somepassword
ENV CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1
DEOF
docker build -q -t "$TAG" "$DATADIR" >/dev/null

echo ""
echo "=== Done! ==="
docker images "$TAG" --format "{{.Repository}}:{{.Tag}} {{.Size}}"
echo ""
echo "Push with: docker push $TAG"
