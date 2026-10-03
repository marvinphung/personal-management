from functools import lru_cache
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "backend/.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    database_url: str = Field(
        default="postgresql://postgres:postgres@localhost:5432/postgres?sslmode=disable"
    )
    database_schema: str = Field(default="qlt")
    dedup_key: str = Field(
        default="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    )
    environment: str = Field(default="development")
    host: str = Field(default="0.0.0.0")
    port: int = Field(default=8000)

    session_lifetime_days: int = Field(default=30)
    widget_token_lifetime_days: int = Field(default=90)

    def is_production(self) -> bool:
        return self.environment.lower() == "production"

    def is_test(self) -> bool:
        return self.environment.lower() == "test"

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


@lru_cache
def get_settings() -> Settings:
    return Settings()
