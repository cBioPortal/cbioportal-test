# ClickHouse Test Data Image

Pre-built ClickHouse image with cBioPortal test data, mirroring `cbioportal/mysql:8.0-database-test` for the ClickHouse column store.

## What's included

- All 5 CI test studies: `ascn_test_study`, `study_es_0`, `study_hg38`, `teststudy_genepanels`, `lgg_ucsf_2014_test_generic_assay`
- All derived tables created by the Sling importer: `sample_derived`, `clinical_data_derived`, `genomic_event_derived`, `genetic_alteration_derived`, `clinical_event_derived`, `gene_panel_to_gene_derived`, `sample_to_gene_panel_derived`, `generic_assay_data_derived`
- Gene panels: `TESTPANEL1` (17 genes), `TESTPANEL2` (11 genes), `WES` (all genes)
- Full gene table (42K+ genes), cancer types, reference genomes

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
1. Starts `cbioportal/mysql:8.0-database-test` (pre-loaded MySQL)
2. Starts fresh `clickhouse/clickhouse-server:24.10`
3. Runs the Sling importer to sync MySQL → ClickHouse
4. Commits the ClickHouse container as a new image

## CI

The GitHub Action at `.github/workflows/build-clickhouse-image.yml` automatically rebuilds and pushes the image when the build script or test data changes.
