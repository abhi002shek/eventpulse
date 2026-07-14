from functools import lru_cache
from urllib.parse import quote_plus

from pydantic import Field, SecretStr
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
    database_host: str = Field(default="127.0.0.1", validation_alias="DATABASE_HOST")
    database_port: int = Field(default=5432, validation_alias="DATABASE_PORT")
    database_name: str = Field(default="eventpulse", validation_alias="DATABASE_NAME")
    database_user: str = Field(default="eventpulse", validation_alias="DATABASE_USER")
    database_password: SecretStr = Field(
        default=SecretStr("eventpulse_dev_password"),
        validation_alias="DATABASE_PASSWORD",
    )

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    @property
    def database_url(self) -> str:
        user = quote_plus(self.database_user)
        password = quote_plus(self.database_password.get_secret_value())
        host = self.database_host
        port = self.database_port
        name = quote_plus(self.database_name)
        return f"postgresql+psycopg://{user}:{password}@{host}:{port}/{name}"


@lru_cache
def get_settings() -> Settings:
    return Settings()
