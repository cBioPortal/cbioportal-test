#!/bin/sh

REPO_URL="https://github.com/zainasir/cbioportal-docker-compose.git"

# Create a temporary directory and clone the repo
ROOT_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
git clone "$REPO_URL" "$TEMP_DIR/cbioportal-docker-compose"
cd "$TEMP_DIR/cbioportal-docker-compose" || exit 1

# Save environment variables
set | grep -e "DOCKER" -e "DB" >> .env

# Run init script
./init.sh

# Start docker compose container
docker compose -f docker-compose.yml -f dev/docker-compose.web.yml up

# Cleanup
cd "$ROOT_DIR"
rm -rf "$TEMP_DIR"