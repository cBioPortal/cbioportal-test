#!/bin/bash
set -eo pipefail
clickhouse-client --user "${CLICKHOUSE_USER}" --password "${CLICKHOUSE_PASSWORD}" --database "${CLICKHOUSE_DB}" --multiquery < /data/schema.sql
