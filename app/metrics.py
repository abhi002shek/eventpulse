import logging
import time
from collections.abc import Awaitable, Callable
from uuid import uuid4

from fastapi import Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp

logger = logging.getLogger(__name__)

HTTP_REQUESTS_TOTAL = Counter(
    "eventpulse_http_requests_total",
    "Total HTTP requests handled by EventPulse.",
    ["method", "path", "status_code"],
)
HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "eventpulse_http_request_duration_seconds",
    "HTTP request duration in seconds.",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)
HTTP_REQUESTS_IN_PROGRESS = Gauge(
    "eventpulse_http_requests_in_progress",
    "HTTP requests currently being processed.",
    ["method", "path"],
)
DATABASE_READINESS_LATENCY_SECONDS = Histogram(
    "eventpulse_database_readiness_latency_seconds",
    "Database readiness check latency in seconds.",
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0),
)
DATABASE_FAILURES_TOTAL = Counter(
    "eventpulse_database_failures_total",
    "Database operation failures observed by EventPulse.",
    ["operation"],
)
BOOKINGS_TOTAL = Counter(
    "eventpulse_bookings_total",
    "Booking creation outcomes.",
    ["result"],
)


def render_metrics() -> Response:
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


def observe_database_readiness(duration_seconds: float, succeeded: bool) -> None:
    DATABASE_READINESS_LATENCY_SECONDS.observe(duration_seconds)
    if not succeeded:
        DATABASE_FAILURES_TOTAL.labels(operation="readiness").inc()


def record_booking_result(result: str) -> None:
    BOOKINGS_TOTAL.labels(result=result).inc()


def _route_path(request: Request) -> str:
    route = request.scope.get("route")
    path = getattr(route, "path", None)
    if isinstance(path, str):
        return path
    return request.url.path


class MetricsAndLoggingMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)

    async def dispatch(
        self,
        request: Request,
        call_next: Callable[[Request], Awaitable[Response]],
    ) -> Response:
        method = request.method
        request_id = request.headers.get("x-request-id", str(uuid4()))
        start = time.perf_counter()
        path = request.url.path
        status_code = 500

        HTTP_REQUESTS_IN_PROGRESS.labels(method=method, path=path).inc()
        try:
            response = await call_next(request)
            status_code = response.status_code
            response.headers["X-Request-ID"] = request_id
            return response
        finally:
            duration_seconds = time.perf_counter() - start
            route_path = _route_path(request)
            if route_path != path:
                HTTP_REQUESTS_IN_PROGRESS.labels(method=method, path=path).dec()
                HTTP_REQUESTS_IN_PROGRESS.labels(method=method, path=route_path).inc()

            HTTP_REQUESTS_IN_PROGRESS.labels(method=method, path=route_path).dec()
            HTTP_REQUESTS_TOTAL.labels(
                method=method,
                path=route_path,
                status_code=str(status_code),
            ).inc()
            HTTP_REQUEST_DURATION_SECONDS.labels(method=method, path=route_path).observe(
                duration_seconds
            )
            logger.info(
                "HTTP request completed",
                extra={
                    "method": method,
                    "path": route_path,
                    "status_code": status_code,
                    "duration_ms": round(duration_seconds * 1000, 3),
                    "request_id": request_id,
                },
            )
