from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(
            Path(__file__).resolve().parents[2].parent / ".env",
            Path(__file__).resolve().parents[2] / ".env",
        ),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    database_url: str = Field(
        default="postgresql://postgres:postgres@localhost:5432/postgres?sslmode=disable"
    )
    database_schema: str = Field(default="qlt", pattern=r"^[A-Za-z_][A-Za-z0-9_]*$")
    dedup_key: str = Field(
        default="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    )
    environment: str = Field(default="development")
    host: str = Field(default="0.0.0.0")
    port: int = Field(default=8000)

    # NATS JetStream Settings
    nats_url: str = Field(default="nats://localhost:4222")
    nats_user: str | None = Field(default=None)
    nats_password: str | None = Field(default=None)
    nats_credentials_file: str | None = Field(default=None)
    nats_stream_prefix: str = Field(default="QLT")
    nats_storage_type: str = Field(default="file")
    nats_max_bytes: int = Field(default=1024 * 1024 * 1024)  # 1 GiB
    nats_max_msg_size: int = Field(default=64 * 1024)  # 64 KiB
    nats_publish_timeout_seconds: float = Field(default=3.0)
    nats_reconnect_time_wait_seconds: float = Field(default=1.0)
    nats_max_reconnect_attempts: int = Field(default=60)
    nats_duplicate_window_seconds: int = Field(default=86400)  # 24h
    nats_host: str = Field(default="127.0.0.1")
    nats_monitor_listen: str = Field(default="127.0.0.1:8222")
    nats_store_dir: str | None = Field(default=None)

    # Coordination & Workers
    outbox_worker_poll_interval_seconds: float = Field(default=1.0)
    outbox_worker_batch_size: int = Field(default=50)
    outbox_worker_lease_seconds: int = Field(default=30)
    realtime_chunk_threshold_bytes: int = Field(default=256 * 1024)

    # Push Notification Adapters
    apns_enabled: bool = Field(default=False)
    fcm_enabled: bool = Field(default=False)
    apns_key_id: str | None = None
    apns_team_id: str | None = None
    apns_topic: str | None = None
    apns_private_key_file: str | None = None
    fcm_project_id: str | None = None
    fcm_service_account_file: str | None = None

    session_lifetime_days: int = Field(default=30)
    widget_token_lifetime_days: int = Field(default=90)

    # Optional local/demo seed account. Keep real credentials out of committed files.
    demo_user_username: str = Field(default="demo")
    demo_user_password: str | None = Field(default=None)

    def is_production(self) -> bool:
        return self.environment.lower() == "production"

    def is_test(self) -> bool:
        return self.environment.lower() == "test"

    def get_stream_name(self) -> str:
        """Returns stream name formatted with environment."""
        env = self.environment.upper()
        return f"{self.nats_stream_prefix}_{env}_PENDING_V1"

    def get_subject_prefix(self) -> str:
        """Returns subject prefix formatted with environment."""
        env = self.environment.lower()
        return f"qlt.{env}.pending"

    def assert_test_database(self) -> None:
        """Reject non-test database URLs before any destructive operation."""
        url = self.database_url.lower()
        if not self.is_test():
            raise RuntimeError(
                f"Destructive operation forbidden outside test environment (current: {self.environment})"
            )
        if "supabase" in url or "pooler" in url or "prod" in url:
            raise RuntimeError(
                "Destructive operation rejected: DSN appears to target a cloud/production database"
            )
        if "qlt_test" not in url and "test" not in url and "5433" not in url:
            raise RuntimeError(
                f"Destructive operation rejected: DSN does not look like an isolated test database ({url})"
            )

    def assert_test_nats(self) -> None:
        """Reject destructive broker operations outside isolated test prefix/environment."""
        if not self.is_test():
            raise RuntimeError(
                f"Destructive broker operation forbidden outside test environment (current: {self.environment})"
            )
        stream_name = self.get_stream_name()
        if "TEST" not in stream_name:
            raise RuntimeError(
                f"Destructive broker operation rejected: stream name does not contain TEST ({stream_name})"
            )
        from urllib.parse import urlparse

        if urlparse(self.nats_url).hostname not in ("localhost", "127.0.0.1", "::1"):
            raise RuntimeError("Backend tests require a local isolated NATS broker")


@lru_cache
def get_settings() -> Settings:
    return Settings()
