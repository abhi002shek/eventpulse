# EventPulse

EventPulse is a learning-focused event-booking application. Milestone 2C adds booking creation, booking retrieval, and transactional event capacity protection.

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
- Ruff, Mypy, and Pytest configuration
- Pytest coverage for health, readiness, event reads, and bookings

This milestone does not include cancellation, refunds, payments, authentication, user accounts, cloud infrastructure, Kubernetes, Terraform, or frontend code.

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
