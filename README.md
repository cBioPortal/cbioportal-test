# cBioPortal Tests
This repo hosts the test-runner scripts that are used throughout cbioportal applications. The tests themselves vary from repo to repo, and are contained within the source code (e.g. cbioportal-frontend hosts specs for the frontend).

## Setup
Before running any of the scripts, make sure to export the required environment variables shown below. If you need access to default values, get in touch with [Zain](mailto:nasirz1@mskcc.org).
```shell
set -o allexport
export DOCKER_USERNAME=<docker-username>
export DOCKER_PASSWORD=<docker-password>
export DOCKER_IMAGE_CBIOPORTAL=<docker-compose-image-tag>
export DOCKER_TAG=<build-tag>
export DB_MYSQL_USERNAME=<mysql-username>
export DB_MYSQL_PASSWORD=<mysql-password>
export DB_MYSQL_URL=<mysql-url>
export DB_CLICKHOUSE_USERNAME=<clickhouse-username>
export DB_CLICKHOUSE_PASSWORD=<clickhouse-password>
export DB_CLICKHOUSE_URL=<clickhouse-url>
set +o allexport
```

## Usage
All [scripts](./scripts) are standalone and can be run independently. They can also be configured by setting the appropriate environment variables and flags.

### [build-push-image.sh](./scripts/build-push-image.sh)
Build a docker image using the source code provided. Optionally, push to cbioportal/cbioportal-dev repo on dockerhub if _--push=true._ The new image is tagged using environment variables: DOCKER_REPO:DOCKER_TAG

```shell
# To also push image to DockerHub, set --push=true. Default is false.
sh ./scripts/docker-compose.sh --src=/path/to/dockerfile --push=false
```

### [docker-compose.sh](./scripts/docker-compose.sh)
Start a cbioportal instance at localhost:8080. Set the appropriate environment variables to configure the database and docker image to use.

```shell
sh ./scripts/docker-compose.sh
```