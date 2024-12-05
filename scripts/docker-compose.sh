#!/bin/sh

REPO_URL="https://github.com/cbioportal/cbioportal-docker-compose.git"

# Get named arguments
. utils/parse_args.sh "$@"

# Create a temporary directory and clone the repo
ROOT_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
git clone "$REPO_URL" "$TEMP_DIR/cbioportal-docker-compose"
cd "$TEMP_DIR/cbioportal-docker-compose" || exit 1

# Save environment variables that start with DOCKER or DB
echo "" >> .env
set | grep -e "^DOCKER" -e "^DB" >> .env

# Run init script
./init.sh

# Start docker compose container. Also pass any option docker compose args from the command line
if [ "$portal_type" ] && [ "$portal_type" = "web-and-data" ]; then
  docker compose up $docker_args
else
  docker compose -f docker-compose.yml -f dev/docker-compose.web.yml up $docker_args
fi

# Cleanup
cd "$ROOT_DIR"
rm -rf "$TEMP_DIR"