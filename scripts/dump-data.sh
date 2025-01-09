#!/bin/sh
set -e

# Get named arguments
. utils/parse-args.sh "$@"

# Check required args
if [ ! "$url" ] || [ ! "$out" ]; then
  echo "Missing required args. Usage: ./scripts/dump-data.sh --url=localhost:8080 --out=/output/path/to/database-dump.sql"
  exit 1
else
  out=$(eval echo "$out")
fi

ROOT_DIR=$(pwd)

# Check if instance is running at provided url
cd $ROOT_DIR
utils/check-connection.sh --url="$url" --interval=5 --max_retries=50

# Dump the instance data to provided out path
docker exec cbioportal-database-container sh -c 'mysqldump -u root -psomepassword cbioportal > /tmp/database_dump.sql'
docker cp cbioportal-database-container:/tmp/database_dump.sql "$out"
