#!/bin/bash
set -eo pipefail
gunzip -c /data/seed.sql.gz | clickhouse-client --user "${CLICKHOUSE_USER}" --password "${CLICKHOUSE_PASSWORD}" --database "${CLICKHOUSE_DB}" --multiquery
