# ClickHouse Test Data Image

Pre-built ClickHouse image with the cBioPortal database schema and reference seed data. Used for e2e testing against the ClickHouse-only cBioPortal stack.

This uses the simplified ClickHouse-only approach from [cbioportal-docker-compose#72](https://github.com/cBioPortal/cbioportal-docker-compose/pull/72) — no MySQL, no Sling importer. The schema and seed SQL are loaded directly into ClickHouse via `docker-entrypoint-initdb.d` on first start.

## What's included

- **50 tables** — full ClickHouse schema from `cbioportal/cbioportal@add-clickhoue-database-schema-and-seed`
- **~44K genes** (`gene`, `gene_alias`)
- **~850 cancer types** (`type_of_cancer`)
- **3 reference genomes** (`reference_genome`)
- **~35K genesets** (`geneset`, `geneset_gene`, etc.)

**Test studies included:** the build script imports the 5 CI test studies from `cbioportal/mysql:8.0-database-test` via Sling, so the final image has:
- 5 cancer studies
- 918 samples
- ~10,560 mutations
- ~7,767 clinical data records
- All derived tables (`sample_derived`, `clinical_data_derived`, `genomic_event_derived`, etc.)

## Usage

```yaml
# docker-compose.yml
services:
  clickhouse:
    image: cbioportal/clickhouse-test:latest
    ports:
      - "8123:8123"
      - "9000:9000"
```

```bash
# Or directly
docker run -d -p 8123:8123 -p 9000:9000 cbioportal/clickhouse-test:latest
```

Connect with: `clickhouse://cbio_user:somepassword@localhost:9000/cbioportal`

## Building

```bash
./build.sh [tag]
# Default: cbioportal/clickhouse-test:latest
```

The build script:
1. Downloads the latest `schema.sql` and `seed.sql.gz` from `cBioPortal/cbioportal@add-clickhoue-database-schema-and-seed`
2. Builds a base image with the schema + seed loaded via `docker-entrypoint-initdb.d`
3. Starts that ClickHouse container alongside `cbioportal/mysql:8.0-database-test`
4. Runs the Sling importer to copy test study data MySQL → ClickHouse
5. Snapshots the populated ClickHouse data and bakes it into the final image (works around the `VOLUME /var/lib/clickhouse` declaration that prevents `docker commit` from capturing data)

Build time: ~5 minutes (most of which is waiting for MySQL TCP).

## CI

The GitHub Action at `.github/workflows/build-clickhouse-image.yml` automatically rebuilds and pushes the image when the build files or Dockerfile change.
