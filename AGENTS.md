# EventPulse Agent Instructions

## Project objective

Build EventPulse, a secure event-booking application that will eventually demonstrate DevOps, DevSecOps, Kubernetes, GitOps, observability and multi-cloud engineering practices.

AWS will be the primary transactional cloud.

Google Cloud will host the asynchronous analytics platform.

The project must remain understandable to a DevOps engineer who is learning application development.

## Current phase

Only work on the currently requested phase.

Do not create AWS, GCP, Kubernetes, Terraform, Helm, Argo CD or observability components until explicitly requested.

The first phase is a locally runnable application using:

- Python 3.12
- FastAPI
- PostgreSQL
- SQLAlchemy
- Alembic
- Pytest
- Docker
- Docker Compose

## Working rules

1. Inspect the existing repository before changing files.
2. Explain the proposed implementation before making major changes.
3. Keep changes small and reviewable.
4. Do not redesign unrelated parts of the repository.
5. Do not silently add tools, frameworks or cloud services.
6. Do not use placeholder code when a working implementation is practical.
7. Never place credentials, tokens or secrets in source code.
8. Never commit `.env` files containing real secrets.
9. Use pinned dependency versions.
10. Use clear names and avoid unnecessary abstraction.
11. Prefer simple production-quality code over complex architecture.
12. Do not make Git commits unless explicitly requested.

## Application architecture

The initial application should use a modular monolith.

Do not create unnecessary microservices during the local development phase.

Expected modules:

- events
- bookings
- health
- database
- configuration
- logging

## API requirements

The initial API will provide:

- `GET /health`
- `GET /ready`
- `GET /api/v1/events`
- `GET /api/v1/events/{event_id}`
- `POST /api/v1/bookings`
- `GET /api/v1/bookings/{booking_id}`

Use versioned API paths for business endpoints.

Health and readiness endpoints should not be versioned.

## Coding standards

- Use type hints.
- Use Pydantic models for request and response validation.
- Separate API routes, business logic and database access.
- Use central exception handling.
- Use structured logging.
- Do not log passwords, tokens, email addresses or sensitive booking data.
- Use UTC timestamps.
- Use UUIDs for public booking identifiers.
- Validate all external input.
- Return appropriate HTTP status codes.

## Security requirements

- No hardcoded secrets.
- Configuration must be read from environment variables.
- Database credentials must not appear in logs.
- Container must run as a non-root user.
- Dockerfile must use a small trusted base image.
- Docker image must not contain development files or test caches.
- Do not expose the PostgreSQL port publicly.
- Avoid unnecessary system packages.
- Record security decisions in `docs/decisions` when requested.

## Testing requirements

Use Pytest.

Tests must be understandable and cover:

- health endpoint
- readiness endpoint
- event listing
- unknown event
- successful booking
- invalid booking
- duplicate or conflicting booking
- database failure behaviour

Tests must follow Arrange, Act, Assert.

Do not write tests that only mock everything and prove no meaningful behaviour.

Initial minimum coverage target: 70%.

## Commands

Install dependencies:

```bash
python -m pip install -r requirements-dev.txt
```

Run formatting check:

```bash
ruff format --check .
```

Run linting:

```bash
ruff check .
```

Run type checking:

```bash
mypy app
```

Run tests:

```bash
pytest --cov=app --cov-report=term-missing --cov-report=xml
```

Run locally:

```bash
uvicorn app.main:app --reload
```

Run containers:

```bash
docker compose up --build
```

Stop containers:

```bash
docker compose down
```

## Validation before completion

Before reporting that a task is complete:

1. Run applicable formatting checks.
2. Run linting.
3. Run tests.
4. Report which commands were run.
5. Report the result of each command.
6. Clearly identify anything that could not be validated.
7. Summarize changed files.
8. Do not claim success when commands failed.

## Documentation requirements

Keep README instructions executable and current.

Architecture decisions should explain:

- context
- decision
- alternatives considered
- trade-offs
- consequences

Do not exaggerate scale, reliability or performance results.

Only document metrics we have actually measured.
