# Modular E2E Testing

Self-contained end-to-end testing for cBioPortal with swappable components.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  FRONTEND   │     │   BACKEND   │     │  DATABASE   │
│  (SWS/nginx)│◄───►│   (Java)    │◄───►│ (ClickHouse)│
│   :80       │     │   :8080     │     │   :9000     │
└──────┬──────┘     └─────────────┘     └─────────────┘
       │
┌──────┴──────┐
│   PROXY     │  Caddy - routes /api/* to backend
│   :80       │         routes /* to frontend
└──────┬──────┘
       │
┌──────┴──────┐
│ TEST RUNNER │  Chrome + WebDriverIO + specs
│             │  Points at proxy:80
└─────────────┘
```

## Quick Start

```bash
# Download the compose file and run all tests
curl -O https://raw.githubusercontent.com/cBioPortal/cbioportal-test/main/docker-compose.e2e.yml
docker compose -f docker-compose.e2e.yml run test-runner

# Results in ./e2e-results/
```

## Swap Components

```bash
# Test a frontend PR
FRONTEND_IMAGE=cbioportal/frontend:pr-1234 \
  docker compose -f docker-compose.e2e.yml run test-runner

# Test with different data
DB_IMAGE=cbioportal/clickhouse:genie-data \
  docker compose -f docker-compose.e2e.yml run test-runner

# Run only specific tests
SPEC_PATTERN="./local/specs/core/patientview.spec.js" \
  docker compose -f docker-compose.e2e.yml run test-runner

# Run remote tests against production
SPEC_PATTERN="./remote/specs/**/*.spec.js" \
CBIOPORTAL_URL=https://www.cbioportal.org \
  docker compose -f docker-compose.e2e.yml run test-runner
```

## Images

| Image | Source | Description |
|---|---|---|
| `cbioportal/frontend:latest` | cbioportal-frontend | Static web server + built React app |
| `cbioportal/cbioportal:latest` | cbioportal | Java backend (default) |
| `cbioportal/clickhouse-test:latest` | cbioportal-test | ClickHouse with 5 test studies |
| `cbioportal/e2e-runner:latest` | cbioportal-frontend | Chrome + WebDriverIO + test specs |

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `BACKEND_IMAGE` | `cbioportal/cbioportal:6.4.1` | Backend Docker image |
| `FRONTEND_IMAGE` | `cbioportal/frontend:latest` | Frontend Docker image |
| `DB_IMAGE` | `cbioportal/clickhouse-test:latest` | Database Docker image |
| `RUNNER_IMAGE` | `cbioportal/e2e-runner:latest` | Test runner Docker image |
| `SPEC_PATTERN` | `./local/specs/**/*.spec.js` | Which test specs to run |
| `SKIP_KEYCLOAK` | `true` | Skip Keycloak login flow |
| `E2E_PORT` | `80` | Port for the proxy |
