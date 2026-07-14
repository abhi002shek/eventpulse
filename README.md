# EventPulse

EventPulse is a learning-focused event-booking application. Milestone 1 contains only a small locally runnable FastAPI application shell.

## Current Scope

This milestone includes:

- FastAPI application entry point
- `GET /health`
- environment-based settings
- standard-library JSON logging
- a central location for future exception handlers
- Ruff, Mypy, and Pytest configuration
- one Pytest test for the health endpoint

This milestone does not include PostgreSQL, SQLAlchemy, Alembic, Docker, event APIs, booking APIs, authentication, payments, cloud infrastructure, or frontend code.

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

## Validate

Run all checks from the repository root:

```bash
.venv/bin/ruff format --check .
.venv/bin/ruff check .
.venv/bin/mypy app
.venv/bin/pytest --cov=app --cov-report=term-missing --cov-report=xml
```
