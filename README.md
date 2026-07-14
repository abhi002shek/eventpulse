# EventPulse

EventPulse is a learning-focused event-booking application. Milestone 2A adds the local PostgreSQL database foundation and readiness endpoint.

## Current Scope

This milestone includes:

- FastAPI application entry point
- `GET /health`
- `GET /ready`
- environment-based settings
- standard-library JSON logging
- a central location for future exception handlers
- PostgreSQL 16-alpine for local development
- SQLAlchemy synchronous engine and session factory
- Alembic migration framework
- Ruff, Mypy, and Pytest configuration
- Pytest coverage for health and readiness

This milestone does not include event APIs, booking APIs, authentication, payments, cloud infrastructure, Kubernetes, Terraform, or frontend code.

## Requirements

- Python 3.12

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

## Alembic

Alembic reads database settings from the application configuration. There are no application tables yet in Milestone 2A.

Check the current migration version:

```bash
.venv/bin/alembic current
```

Run migrations:

```bash
.venv/bin/alembic upgrade head
```

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

## Validate

Run all checks from the repository root:

```bash
.venv/bin/ruff format --check .
.venv/bin/ruff check .
.venv/bin/mypy app
.venv/bin/alembic current
.venv/bin/alembic upgrade head
.venv/bin/pytest --cov=app --cov-report=term-missing --cov-report=xml
```
