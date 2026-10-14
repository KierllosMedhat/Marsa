from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration loaded from environment variables or .env file."""

    database_url: str = "postgresql+asyncpg://marsa_user:marsa_password@localhost:5432/marsa_dev"
    redis_url: str = "redis://localhost:6379/0"
    jwt_private_key: str = ""
    jwt_public_key: str = ""
    jwt_algorithm: str = "RS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 30
    argon2_memory_cost: int = 65536
    argon2_time_cost: int = 3
    argon2_parallelism: int = 4
    environment: str = "development"
    timezone: str = "Africa/Cairo"
    encryption_key: str = ""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def formatted_jwt_private_key(self) -> str:
        """Ensure newline escaping in private key string is converted to actual newlines."""
        if self.jwt_private_key:
            return self.jwt_private_key.replace("\\n", "\n").strip()
        return ""

    @property
    def formatted_jwt_public_key(self) -> str:
        """Ensure newline escaping in public key string is converted to actual newlines."""
        if self.jwt_public_key:
            return self.jwt_public_key.replace("\\n", "\n").strip()
        return ""


@lru_cache
def get_settings() -> Settings:
    """Return a cached singleton instance of application settings."""
    return Settings()
