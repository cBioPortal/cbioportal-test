# cBioPortal ClickHouse test data image
# Uses the simplified ClickHouse-only approach from cbioportal-docker-compose#72.
# Includes the base schema and seed data (genes, cancer types, reference genomes).
# Test studies are NOT included — this is the base image for e2e testing.
FROM clickhouse/clickhouse-server:24.5

# Install the schema and seed files into /data
COPY schema.sql /data/schema.sql
COPY seed.sql.gz /data/seed.sql.gz
COPY load_schema.sh /docker-entrypoint-initdb.d/001_load_schema.sh
COPY load_seed.sh /docker-entrypoint-initdb.d/002_load_seed.sh

ENV CLICKHOUSE_DB=cbioportal
ENV CLICKHOUSE_USER=cbio_user
ENV CLICKHOUSE_PASSWORD=somepassword
ENV CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1
