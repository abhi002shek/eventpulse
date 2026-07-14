from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Environment-based application settings."""

    app_name: str = Field(default="EventPulse API", validation_alias="EVENTPULSE_APP_NAME")
    service_name: str = Field(
        default="eventpulse-api",
        validation_alias="EVENTPULSE_SERVICE_NAME",
    )
    environment: str = Field(default="local", validation_alias="EVENTPULSE_ENVIRONMENT")
    log_level: str = Field(default="INFO", validation_alias="EVENTPULSE_LOG_LEVEL")

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    return Settings()
