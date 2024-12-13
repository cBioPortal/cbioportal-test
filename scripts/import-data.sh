#!/bin/sh
set -e

DOCKER_COMPOSE_REPO="https://github.com/cbioportal/cbioportal-docker-compose.git"

# Create a temporary directory
ROOT_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
mkdir "$TEMP_DIR/study"
cd "$TEMP_DIR/study" || exit 1

# Check cbioportal is live at localhost:8080 and get portal version
printf "\nChecking cbioportal portal at localhost:8080 ...\n\n"
cd "$ROOT_DIR"
utils/check-connection.sh --url=localhost:8080
PORTAL_VERSION=$(docker inspect cbioportal-container | jq -r '.[0].Config.Image')

# Clone docker compose repo
git clone "$DOCKER_COMPOSE_REPO" "$TEMP_DIR/cbioportal-docker-compose"
cd "$TEMP_DIR/cbioportal-docker-compose"

# Copy schema to database container
SCHEMA_PATH=$(docker inspect cbioportal-database-container | jq -r '.[].Mounts[].Source' | grep 'cgds.sql')
cp "$ROOT_DIR/data/cgds.sql" "$SCHEMA_PATH"

# Copy seed to database container
SEED_PATH=$(docker inspect cbioportal-database-container | jq -r '.[].Mounts[].Source' | grep 'seed.sql.gz')
cp "$ROOT_DIR/data/seed.sql.gz" "$SEED_PATH"

# Copy study and genesets to database container
STUDY_PATH=$(docker inspect cbioportal-container | jq -r '.[].Mounts[].Source' | grep 'study')
cp -r "$ROOT_DIR/data/study_es_0" "$STUDY_PATH/study_es_0"
cp -r "$ROOT_DIR/data/genesets" "$STUDY_PATH/genesets"

# Import genepanel data
cd "$TEMP_DIR/cbioportal-docker-compose"
docker compose exec cbioportal sh -c 'cd /core/scripts/ \
  && ./importGenePanel.pl --data /study/study_es_0/data_gene_panel_testpanel1.txt \
  && ./importGenePanel.pl --data /study/study_es_0/data_gene_panel_testpanel2.txt \
  && ./importGenesetData.pl --data /study/genesets/study_es_0_genesets.gmt --new-version msigdb_7.5.1 \
      --sup /study/genesets/study_es_0_supp-genesets.txt --confirm-delete-all-genesets-hierarchy-genesetprofiles\
  && ./importGenesetHierarchy.pl --data /study/genesets/study_es_0_tree.yaml'

# Load test study
cd "$TEMP_DIR/cbioportal-docker-compose"
docker compose restart cbioportal-database
docker compose exec cbioportal metaImport.py -u http://localhost:8080 -s "study/study_es_0/" -o