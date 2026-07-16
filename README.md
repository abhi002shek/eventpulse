# EventPulse

EventPulse is a learning-focused event-booking application. Milestone 3A adds a production-style Docker image and complete local Docker Compose stack for the API and PostgreSQL.

## Current Scope

This milestone includes:

- FastAPI application entry point
- `GET /health`
- `GET /ready`
- `GET /api/v1/events`
- `GET /api/v1/events/{event_id}`
- `POST /api/v1/bookings`
- `GET /api/v1/bookings/{booking_id}`
- environment-based settings
- standard-library JSON logging
- a central location for future exception handlers
- PostgreSQL 16-alpine for local development
- SQLAlchemy synchronous engine and session factory
- Alembic migration framework
- Event SQLAlchemy model and read-only API routes
- Repeatable demonstration event seed command
- Booking SQLAlchemy model and API routes
- PostgreSQL row-level locking for booking capacity protection
- Production-style API Docker image
- Local Docker Compose stack with API and PostgreSQL
- Ruff, Mypy, and Pytest configuration
- Pytest coverage for health, readiness, event reads, and bookings

This milestone does not include cancellation, refunds, payments, authentication, user accounts, cloud infrastructure, Kubernetes, Terraform, or frontend code.

## Requirements

- Python 3.12
- Docker
- Docker Compose

## Local Setup

Create a virtual environment:

```bash
python3.12 -m venv .venv
```

Install development dependencies:

```bash
.venv/bin/python -m pip install -r requirements-dev.txt
```

Copy local environment defaults if needed:

```bash
cp .env.example .env
```

Only fake local values belong in `.env.example`. Do not commit real secrets.

## Start PostgreSQL

Start the local PostgreSQL service:

```bash
docker compose up -d postgres
```

Check service status:

```bash
docker compose ps
```

View PostgreSQL logs:

```bash
docker compose logs postgres
```

Stop services:

```bash
docker compose down
```

Reset local database data only when you intentionally want to delete it:

```bash
docker compose down -v
```

Warning: `docker compose down -v` deletes the local PostgreSQL volume and all local database data.

## Run With Docker Compose

The local Compose stack uses PostgreSQL and the EventPulse API container. PostgreSQL is bound to `127.0.0.1:5432`, and the API is bound to `127.0.0.1:8000`.

Start PostgreSQL first:

```bash
docker compose up -d postgres
```

Run migrations explicitly:

```bash
docker compose run --rm api alembic upgrade head
```

Start the API:

```bash
docker compose up -d api
```

Check service health:

```bash
docker compose ps
```

Seed demonstration events when needed:

```bash
docker compose run --rm api python -m app.scripts.seed_events
```

Stop the stack:

```bash
docker compose down
```

Reset local database data only when intentional:

```bash
docker compose down -v
```

Warning: `docker compose down -v` deletes the local PostgreSQL volume and all local database data.

## Alembic

Alembic reads database settings from the application configuration.

Check the current migration version:

```bash
.venv/bin/alembic current
```

Run migrations:

```bash
.venv/bin/alembic upgrade head
```

To test the latest downgrade and upgrade locally:

```bash
.venv/bin/alembic downgrade -1
.venv/bin/alembic upgrade head
```

## Seed Demonstration Events

Seed five repeatable demonstration events:

```bash
.venv/bin/python -m app.scripts.seed_events
```

The command is safe to run more than once. It uses fixed public UUID values and reports how many events were inserted and how many already existed.

## Run Locally

```bash
.venv/bin/uvicorn app.main:app --reload
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

Expected response:

```json
{
  "status": "healthy",
  "service": "eventpulse-api"
}
```

Readiness check:

```bash
curl http://127.0.0.1:8000/ready
```

Expected response when PostgreSQL is reachable:

```json
{
  "status": "ready",
  "dependencies": {
    "database": "available"
  }
}
```

List events:

```bash
curl http://127.0.0.1:8000/api/v1/events
```

Get one event by public UUID:

```bash
curl http://127.0.0.1:8000/api/v1/events/<PUBLIC_UUID>
```

Create a booking:

```bash
curl -i -X POST http://127.0.0.1:8000/api/v1/bookings \
  -H "Content-Type: application/json" \
  -d '{
    "event_id": "11111111-1111-4111-8111-111111111111",
    "customer_name": "Demo User",
    "customer_email": "demo@example.com",
    "quantity": 2
  }'
```

Get one booking by public UUID:

```bash
curl http://127.0.0.1:8000/api/v1/bookings/<BOOKING_UUID>
```

## Validate

Run all checks from the repository root:

```bash
.venv/bin/ruff format --check .
.venv/bin/ruff check .
.venv/bin/mypy app
.venv/bin/alembic upgrade head
.venv/bin/alembic current
.venv/bin/alembic downgrade -1
.venv/bin/alembic upgrade head
.venv/bin/pytest --cov=app --cov-report=term-missing --cov-report=xml
```

Validate the container stack:

```bash
docker compose config
docker compose build --no-cache api
docker image inspect eventpulse-api:local
docker compose down
docker compose up -d postgres
docker compose run --rm api alembic upgrade head
docker compose up -d api
docker compose ps
docker compose run --rm api python -m app.scripts.seed_events
docker compose run --rm api python -m app.scripts.seed_events
curl -i http://127.0.0.1:8000/health
curl -i http://127.0.0.1:8000/ready
curl -i http://127.0.0.1:8000/api/v1/events
```

## CI and Security

GitHub Actions CI validates formatting, linting, type checking, Alembic migrations, the PostgreSQL-backed test suite, and a production Docker image build. The CI test command enforces the current minimum coverage gate of 70%.

The security workflow runs Gitleaks against committed Git history and runs Trivy filesystem and image scans. Trivy blocks HIGH and CRITICAL findings while ignoring unfixed vulnerabilities for the initial policy. The image is built for validation but is not pushed to any registry.

All external GitHub Actions are pinned to immutable full commit SHAs. The Trivy action uses a fixed Trivy CLI version and disables the action cache path.

## SonarQube

SonarQube analysis runs only for trusted pushes to `main` or manual `workflow_dispatch` runs. Pull requests do not run on the EC2 self-hosted runner.

The workflow uses the `eventpulse-sonar` self-hosted runner, runs the PostgreSQL-backed test suite, writes `coverage.xml`, and sends that coverage report to the SonarQube server. It waits for the SonarQube quality gate and fails when the scanner cannot reach SonarQube, analysis fails, tests fail, coverage is below 70%, or the quality gate is red.

SonarQube complements the existing CI, Gitleaks, and Trivy checks. The SonarQube UI remains reachable only through an SSH tunnel to the EC2 host.

## Secure Image Publishing

The secure publishing workflow publishes EventPulse images to `ghcr.io/abhi002shek/eventpulse` only for published releases or manual workflow dispatch.

The workflow builds the production image once, scans that image with Trivy before pushing, and stops before publishing if the HIGH/CRITICAL image gate fails. Approved images are pushed with an immutable `sha-${GITHUB_SHA}` tag, and release/manual version tags are added only when explicitly allowed. No `latest` tag is published.

After pushing, the workflow records the exact digest, generates an SPDX JSON SBOM, uploads the SBOM as a workflow artifact, creates GitHub build provenance, signs the digest with Cosign keyless signing, verifies the signature, and checks the pulled digest still runs as `10001:10001`.

Use digest-based references for verification and deployment. See `docs/runbooks/image-verification.md` for pull, SBOM, provenance and Cosign verification commands.

## Local Kubernetes Packaging

The Helm chart for local Kubernetes validation lives in `deploy/helm/eventpulse`.

The default chart values deploy the verified immutable image digest:

```text
ghcr.io/abhi002shek/eventpulse@sha256:76571b0ad6961c7ea7c72d9c3dc81b6014e22be2ceefb26a7157ea607b80e224
```

The chart includes non-root API Pods, dropped Linux capabilities, `RuntimeDefault` seccomp, read-only root filesystem, resource requests and limits, startup/readiness/liveness probes, migration and seed Jobs, ConfigMap and Secret separation, HPA, PDB and default-deny NetworkPolicies.

Kind scripts live in `ops/kind`:

```bash
ops/kind/create-cluster.sh
ops/kind/deploy.sh
ops/kind/validate.sh
ops/kind/destroy.sh
```

The included PostgreSQL deployment is only for local Kind validation. It is not the final production database architecture; AWS RDS is expected in a later AWS milestone. See `docs/runbooks/local-kubernetes-deployment.md` for the full workflow.

Equivalent local checks:

```bash
.venv/bin/ruff format --check .
.venv/bin/ruff check .
.venv/bin/mypy app
.venv/bin/pytest --cov=app --cov-report=term-missing --cov-report=xml --cov-fail-under=70
docker build --pull --tag eventpulse-api:ci-test .
docker image inspect eventpulse-api:ci-test
```

The workflows still need to run on GitHub before their remote execution can be considered verified.
