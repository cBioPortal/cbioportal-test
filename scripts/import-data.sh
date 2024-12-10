#!/bin/sh
set -e

DOCKER_COMPOSE_REPO="https://github.com/cbioportal/cbioportal-docker-compose.git"

# Get named arguments
. utils/parse_args.sh "$@"

# Check required args
if [ ! "$study_list" ] ; then
  echo "Missing required args. Usage: ./scripts/import-data.sh --study_list=/path/to/studies_list.txt"
  exit 1
else
  study_list=$(eval echo "$study_list")
fi

# Check study list file is correctly formatted
if [ "${study_list##*.}" != "txt" ]; then
  echo "Error: File '$study_list' must have a .txt extension."
  exit 1
fi

# Read study names from file
STUDY_NAMES=$(tr -s '[:space:]' '\n' < "$study_list" | awk '{if ($0 ~ /^[a-zA-Z0-9_-]+$/) print $0}' | sort | uniq)

# Create a temporary directory
ROOT_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
mkdir "$TEMP_DIR/study"
cd "$TEMP_DIR/study" || exit 1

# Check cbioportal is live at localhost:8080 and get portal version
printf "\nChecking cbioportal portal at localhost:8080 ...\n\n"
cd "$ROOT_DIR"
utils/check_connection.sh --url=localhost:8080
PORTAL_VERSION=$(docker inspect cbioportal-container | jq -r '.[0].Config.Image')

# Clone docker compose repo
git clone "$DOCKER_COMPOSE_REPO" "$TEMP_DIR/cbioportal-docker-compose"
cd "$TEMP_DIR/cbioportal-docker-compose"

# Download schema
docker run --rm -it $PORTAL_VERSION cat /cbioportal/db-scripts/cgds.sql > "$TEMP_DIR/cbioportal-docker-compose/data/cgds.sql"

# Download seed database
wget -O "$TEMP_DIR/cbioportal-docker-compose/data/seed.sql.gz" "https://github.com/cBioPortal/datahub/raw/master/seedDB/seedDB_hg19_archive/seed-cbioportal_hg19_v2.12.14.sql.gz"

# Download studies
printf "\nDownloading studies...\n\n"
for STUDY in ${STUDY_NAMES}; do
  wget -O "$TEMP_DIR/cbioportal-docker-compose/study/$STUDY".tar.gz "https://cbioportal-datahub.s3.amazonaws.com/${STUDY}.tar.gz"
  tar xvfz "$TEMP_DIR/cbioportal-docker-compose/study/$STUDY".tar.gz -C "$TEMP_DIR/cbioportal-docker-compose/study/"
done

# Import studies and restart portal
printf "\nImporting studies ...\n\n"
cd "$TEMP_DIR/cbioportal-docker-compose"
for STUDY in ${STUDY_NAMES}; do
  docker compose exec cbioportal metaImport.py -u http://cbioportal:8080 -s "study/$STUDY/" -o
done
docker compose restart cbioportal