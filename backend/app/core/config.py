from pathlib import Path

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


DEFAULT_SECRETS = {"change-this-in-production", "change-this-beacon-key", "replace-this-secret", "replace-this-beacon-key"}


class Settings(BaseSettings):
    app_name: str = "BLE Attendance API"
    app_env: str = "dev"
    debug: bool = True

    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "ble_attendance"
    db_user: str = "postgres"
    db_password: str = "postgres"
    database_url_override: str | None = None

    jwt_secret: str = "change-this-in-production"
    jwt_algorithm: str = "HS256"
    jwt_exp_minutes: int = 60 * 8

    beacon_server_key: str = "change-this-beacon-key"
    local_utc_offset_hours: int = 7

    model_config = SettingsConfigDict(
        env_file=str(Path(__file__).resolve().parents[2] / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @model_validator(mode="after")
    def require_real_secrets_outside_dev(self) -> "Settings":
        if self.app_env.lower() != "dev":
            weak = [
                name
                for name, value in (("JWT_SECRET", self.jwt_secret), ("BEACON_SERVER_KEY", self.beacon_server_key))
                if value in DEFAULT_SECRETS or len(value) < 16
            ]
            if weak:
                raise ValueError(f"APP_ENV={self.app_env}: phải đặt giá trị mạnh (>= 16 ký tự) cho {', '.join(weak)}")
        return self

    @property
    def database_url(self) -> str:
        if self.database_url_override:
            return self.database_url_override
        return (
            f"postgresql+psycopg://{self.db_user}:{self.db_password}"
            f"@{self.db_host}:{self.db_port}/{self.db_name}"
        )


settings = Settings()
