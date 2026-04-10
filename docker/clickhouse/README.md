# ClickHouse Test Data Image

Pre-built ClickHouse image with the cBioPortal database schema and reference seed data. Used for e2e testing against the ClickHouse-only cBioPortal stack.

This uses the simplified ClickHouse-only approach from [cbioportal-docker-compose#72](https://github.com/cBioPortal/cbioportal-docker-compose/pull/72) — no MySQL, no Sling importer. The schema and seed SQL are loaded directly into ClickHouse via `docker-entrypoint-initdb.d` on first start.

## What's included

- **50 tables** — full ClickHouse schema from `cbioportal/cbioportal@add-clickhoue-database-schema-and-seed`
- **~44K genes** (`gene`, `gene_alias`)
- **~850 cancer types** (`type_of_cancer`)
- **3 reference genomes** (`reference_genome`)
- **~35K genesets** (`geneset`, `geneset_gene`, etc.)

**Not included:** test studies. For now, API endpoints for studies/samples/mutations return empty results. Test study data can be imported separately.

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

The build script downloads the latest `schema.sql` and `seed.sql.gz` from the cbioportal repo (if older than 1 day) and runs `docker build` to produce the image.

## CI

The GitHub Action at `.github/workflows/build-clickhouse-image.yml` automatically rebuilds and pushes the image when the build files or Dockerfile change.
