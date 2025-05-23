#!/bin/sh
set -e

DOCKER_COMPOSE_REPO="https://github.com/cbioportal/cbioportal-docker-compose.git"

# Get named arguments
. utils/parse-args.sh "$@"

# Check required args
if [ ! "$studies" ]; then
  echo "Missing required args. Usage: ./scripts/import-data.sh --studies=/path/to/studies-dir"
  exit 1
else
  studies=$(eval echo "$studies")
fi

# Create a temporary directory
ROOT_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
mkdir "$TEMP_DIR/study"
cd "$TEMP_DIR/study" || exit 1

# Check cbioportal is live at localhost:8080 and get portal version
printf "\nChecking cbioportal portal at localhost:8080 ...\n\n"
cd "$ROOT_DIR"
utils/check-connection.sh --url=localhost:8080

# Clone docker compose repo
git clone "$DOCKER_COMPOSE_REPO" "$TEMP_DIR/cbioportal-docker-compose"
cd "$TEMP_DIR/cbioportal-docker-compose"

# Copy genesets to database container
STUDY_PATH=$(docker inspect cbioportal-container | jq -r '.[].Mounts[].Source' | grep 'study')
cp -r "$ROOT_DIR/data/genesets" "$STUDY_PATH/genesets"

# Copy studies to database container
find "$studies" -type d -mindepth 1 -maxdepth 1 | while read -r DIR; do
  STUDY_NAME=$(basename "$DIR")
  cp -r "$DIR" "$STUDY_PATH/$STUDY_NAME"
done

# Import genepanel data
cd "$TEMP_DIR/cbioportal-docker-compose"
docker compose exec cbioportal sh -c 'cd /core/scripts/ \
  && ./importGenePanel.pl --data /study/study_es_0/data_gene_panel_testpanel1.txt \
  && ./importGenePanel.pl --data /study/study_es_0/data_gene_panel_testpanel2.txt \
  && ./importGenesetData.pl --data /study/genesets/study_es_0_genesets.gmt --new-version msigdb_7.5.1 \
      --sup /study/genesets/study_es_0_supp-genesets.txt --confirm-delete-all-genesets-hierarchy-genesetprofiles\
  && ./importGenesetHierarchy.pl --data /study/genesets/study_es_0_tree.yaml'

# Load studies from given directory
cd "$TEMP_DIR/cbioportal-docker-compose"
docker compose restart cbioportal-database
for DIR in "$studies"/*/; do
  STUDY_NAME=$(basename "$DIR")
  docker compose exec -T cbioportal metaImport.py -u http://localhost:8080 -s "study/$STUDY_NAME/" -o
done
