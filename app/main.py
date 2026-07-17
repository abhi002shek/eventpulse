from fastapi import FastAPI

from app.api.v1.router import router as api_v1_router
from app.configuration.settings import get_settings
from app.exceptions import register_exception_handlers
from app.health.routes import router as health_router
from app.logging_config import configure_logging
from app.metrics import MetricsAndLoggingMiddleware, render_metrics

settings = get_settings()
configure_logging(settings.log_level)

app = FastAPI(title=settings.app_name)
app.add_middleware(MetricsAndLoggingMiddleware)
register_exception_handlers(app)
app.include_router(health_router)
app.include_router(api_v1_router, prefix="/api/v1")
app.add_api_route("/metrics", render_metrics, methods=["GET"], include_in_schema=False)
