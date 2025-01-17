# Docker
This is a collection of Dockerfiles that build custom images that can be used to run a configurable cBioPortal instance.

## cBioPortal Database
[cbioportal-database.Dockerfile](./cbioportal-database.Dockerfile) can be used to build a mysql image that already contains studies. Dockerfile can also be configured by setting _DUMP_PATH_ argument at build time to load a custom dump file.
```shell
docker build -t cbioportal-database --build-arg DUMP_PATH=path/to/database_dump.sql -f /path/to/cbioportal-database.Dockerfile .
```
### Database dump
A github action has been set up that runs everytime the [data](../data) directory changes. It creates a new database dump file, rebuilds cbioportal-database image, and pushes to [DockerHub](https://hub.docker.com/repository/docker/cbioportal/cbioportal-dev/tags?name=database).
