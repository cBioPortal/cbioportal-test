#!/bin/sh

REPO_URL="https://github.com/cBioPortal/cbioportal.git"
DOCKER_REPO="cbioportal/cbioportal-dev"
PLATFORMS="linux/amd64,linux/arm64"
DOCKERFILE_PATH_WEB="docker/web/Dockerfile"
DOCKERFILE_PATH_WEB_DATA="docker/web-and-data/Dockerfile"
APP_PROPERTIES_PATH="src/main/resources/application.properties"

# Create a temporary directory and clone the repo
ROOT_DIR=$(pwd)
TEMP_DIR=$(mktemp -d)
git clone "$REPO_URL" "$TEMP_DIR/cbioportal"
cd "$TEMP_DIR/cbioportal" || exit 1

# Fetch the pull request and check it out
git fetch origin "pull/$PR_NUMBER/head:pr-$PR_NUMBER"
git checkout "pr-$PR_NUMBER"

# Create application.properties
cp "$APP_PROPERTIES_PATH.EXAMPLE" "$APP_PROPERTIES_PATH"

# Set tag based on PR number
TAG="pr-$PR_NUMBER"

# Login to DockerHub
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

#  Set up QEMU (for multi-platform builds)
docker pull docker.io/tonistiigi/binfmt:latest
docker run --rm --privileged docker.io/tonistiigi/binfmt:latest --install all

# Set up Docker Buildx
docker buildx use cbioportal-test > /dev/null || docker buildx create --name cbioportal-test --driver docker-container --use
docker buildx inspect --bootstrap --builder cbioportal-test

# Build and push Docker Image for 'web-and-data'
docker buildx build --push \
  --platform "$PLATFORMS" \
  --tag "$DOCKER_REPO:$TAG" \
  --file "$DOCKERFILE_PATH_WEB_DATA" \
  --cache-from type=gha \
  --cache-to type=gha \
  .

# Build and push Docker Image for 'web' with '-web-shenandoah' suffix
docker buildx build --push \
  --platform "$PLATFORMS" \
  --tag "$DOCKER_REPO:$TAG-web-shenandoah" \
  --file "$DOCKERFILE_PATH_WEB"  \
  --cache-from type=gha \
  --cache-to type=gha \
  .

# Cleanup
cd "$ROOT_DIR"
rm -rf "$TEMP_DIR"