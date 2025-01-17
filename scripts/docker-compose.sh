#!/bin/sh

REPO_URL="https://github.com/cbioportal/cbioportal-docker-compose.git"

# Get named arguments
. utils/parse-args.sh "$@"

# Create a temporary directory and clone the repo
ROOT_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
git clone "$REPO_URL" "$TEMP_DIR/cbioportal-docker-compose"
cd "$TEMP_DIR/cbioportal-docker-compose" || exit 1

# Save environment variables that start with DOCKER or DB
echo "" >> .env
set | grep -e "^DOCKER" -e "^DB" -e "^APP" >> .env

# Run init script
./init.sh

# Start docker compose container. Also pass any additional compose extensions and optional docker compose args from the command line
if [ "$portal_type" ] && [ "$portal_type" = "web-and-data" ]; then
  docker compose -f docker-compose.yml $compose_extensions up $docker_args
elif [ "$portal_type" ] && [ "$portal_type" = "keycloak" ]; then
  # Run only keycloak instance
  docker compose -f docker-compose.yml -f dev/keycloak/keycloak.yml up keycloak -d

  # Wait for keycloak
  cd $ROOT_DIR
  utils/check-connection.sh --url=localhost:8081

  # Download idp metadata needed for cBioPortal
  cd $TEMP_DIR/cbioportal-docker-compose
  wget http://localhost:8081/auth/realms/cbio/protocol/saml/descriptor -O ./dev/keycloak/idp-metadata.xml

  # Start cBioPortal with keycloak attached
  docker compose -f docker-compose.yml -f dev/keycloak/keycloak.yml $compose_extensions up $docker_args
else
  docker compose -f docker-compose.yml -f dev/docker-compose.web.yml $compose_extensions up $docker_args
fi