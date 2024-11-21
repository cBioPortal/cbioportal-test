#!/bin/sh

REPO_URL="https://github.com/cBioPortal/cbioportal.git"
DOCKER_REPO="cbioportal/cbioportal-dev"
PLATFORMS="linux/amd64,linux/arm64"
DOCKERFILE_PATH_WEB="docker/web/Dockerfile"
DOCKERFILE_PATH_WEB_DATA="docker/web-and-data/Dockerfile"
APP_PROPERTIES_PATH="src/main/resources/application.properties"
TAG="cbioportal"

# Get named arguments
for ARGUMENT in "$@";
do
  key=$(echo "$ARGUMENT" | cut -f1 -d= )
  key_length=$(echo "$key" | awk '{print length}')
  key=$(echo "$key" | cut -d'-' -f3)
  value=$(echo "$ARGUMENT" | cut -c$((key_length + 2))-)
  export "$key"="$value"
done

# Check required args
if [ ! "$src" ]; then
  echo "Missing required args. Usage: ./scripts/build-push-image.sh --src=/path/to/src [--push=false]"
  exit 1
else
  src=$(eval echo $src)
fi

# Create a temporary directory and cp --src
ROOT_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
cp -r "$src" "$TEMP_DIR/cbioportal"
cd "$TEMP_DIR/cbioportal" || exit 1

# Create application.properties
cp "$APP_PROPERTIES_PATH.EXAMPLE" "$APP_PROPERTIES_PATH"

# Login to DockerHub if push=true
if [ "$push" ] && [ "$push" = "true" ]; then
  echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin;
fi

#  Set up QEMU (for multi-platform builds)
docker pull docker.io/tonistiigi/binfmt:latest
docker run --rm --privileged docker.io/tonistiigi/binfmt:latest --install all

# Set up Docker Buildx
docker buildx use cbioportal-test > /dev/null || docker buildx create --name cbioportal-test --driver docker-container --use
docker buildx inspect --bootstrap --builder cbioportal-test

# Check if --push=true
if [ "$push" = "true" ]; then
  PUSH_FLAG="--push";
else
  PUSH_FLAG="--load";
fi

# Custom configuration for circleci builds
if [ "$CI" = "true" ]; then
  PLATFORMS="linux/amd64"
fi

# Build Docker Image for 'web-and-data'. Push if --push=true
docker buildx build $PUSH_FLAG \
  --metadata-file web-and-data-metadata.json \
  --platform "$PLATFORMS" \
  --tag "$DOCKER_REPO:$TAG" \
  --file "$DOCKERFILE_PATH_WEB_DATA" \
  --cache-from type=gha \
  --cache-to type=gha \
  .

# Build Docker Image for 'web' with '-web-shenandoah' suffix. Push if --push=true
docker buildx build $PUSH_FLAG \
  --metadata-file "$ROOT_DIR"/web-metadata.json \
  --platform "$PLATFORMS" \
  --tag "$DOCKER_REPO:$TAG-web-shenandoah" \
  --file "$DOCKERFILE_PATH_WEB"  \
  --cache-from type=gha \
  --cache-to type=gha \
  .

# Cleanup
cd "$ROOT_DIR"
rm -rf "$TEMP_DIR"