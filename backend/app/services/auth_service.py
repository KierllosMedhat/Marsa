from datetime import datetime, timedelta, timezone
import hashlib
from typing import Any
from argon2 import PasswordHasher
from argon2.exceptions import VerificationError, VerifyMismatchError
from argon2.low_level import Type
from jose import ExpiredSignatureError, JWTError, jwt
import pyotp
import redis.asyncio as aioredis

from app.config import get_settings


class AuthService:
    """Authentication service providing password hashing, JWT management, and MFA."""

    def __init__(self):
        settings = get_settings()
        self.settings = settings
        self.hasher = PasswordHasher(
            time_cost=settings.argon2_time_cost,
            memory_cost=settings.argon2_memory_cost,
            parallelism=settings.argon2_parallelism,
            type=Type.ID,
        )

    def hash_password(self, password: str) -> str:
        """Hash a plaintext password using Argon2id."""
        return self.hasher.hash(password)

    def verify_password(self, password_hash: str, password: str) -> bool:
        """Verify a plaintext password against an Argon2id hash."""
        try:
            return self.hasher.verify(password_hash, password)
        except (VerificationError, VerifyMismatchError):
            return False

    def create_access_token(self, data: dict[str, Any], expires_delta: timedelta | None = None) -> str:
        """Create a signed RS256 JWT access token."""
        to_encode = data.copy()
        now = datetime.now(timezone.utc)
        if expires_delta:
            expire = now + expires_delta
        else:
            expire = now + timedelta(minutes=self.settings.access_token_expire_minutes)

        to_encode.update({
            "iat": now,
            "exp": expire,
            "type": "access",
        })
        return jwt.encode(
            to_encode,
            self.settings.formatted_jwt_private_key,
            algorithm=self.settings.jwt_algorithm,
        )

    def create_refresh_token(self, staff_id: str, expires_delta: timedelta | None = None) -> str:
        """Create a signed RS256 JWT refresh token."""
        now = datetime.now(timezone.utc)
        if expires_delta:
            expire = now + expires_delta
        else:
            expire = now + timedelta(days=self.settings.refresh_token_expire_days)

        to_encode = {
            "sub": str(staff_id),
            "iat": now,
            "exp": expire,
            "type": "refresh",
        }
        return jwt.encode(
            to_encode,
            self.settings.formatted_jwt_private_key,
            algorithm=self.settings.jwt_algorithm,
        )

    def create_mfa_token(self, staff_id: str) -> str:
        """Create a short-lived token to authenticate MFA code submission."""
        now = datetime.now(timezone.utc)
        expire = now + timedelta(minutes=5)
        to_encode = {
            "sub": str(staff_id),
            "iat": now,
            "exp": expire,
            "type": "mfa_pending",
        }
        return jwt.encode(
            to_encode,
            self.settings.formatted_jwt_private_key,
            algorithm=self.settings.jwt_algorithm,
        )

    def decode_token(self, token: str) -> dict[str, Any]:
        """Decode and verify an RS256 JWT token."""
        try:
            payload = jwt.decode(
                token,
                self.settings.formatted_jwt_public_key,
                algorithms=[self.settings.jwt_algorithm],
            )
            return payload
        except ExpiredSignatureError as e:
            raise ValueError("Token has expired") from e
        except JWTError as e:
            raise ValueError(f"Invalid token: {e}") from e

    @staticmethod
    def hash_refresh_token(token: str) -> str:
        """Compute SHA-256 hash of a refresh token for Redis lookup."""
        return hashlib.sha256(token.encode("utf-8")).hexdigest()

    async def store_refresh_token(
        self,
        redis: aioredis.Redis,
        token: str,
        staff_id: str,
        ttl_days: int | None = None,
    ) -> None:
        """Store the hash of a refresh token in Redis with an expiration TTL."""
        token_hash = self.hash_refresh_token(token)
        ttl = (ttl_days or self.settings.refresh_token_expire_days) * 86400
        key = f"refresh:{token_hash}"
        await redis.setex(key, ttl, str(staff_id))

    async def verify_and_revoke_refresh_token(
        self,
        redis: aioredis.Redis,
        token: str,
    ) -> str:
        """Verify refresh token signature and presence in Redis, then revoke it for rotation."""
        payload = self.decode_token(token)
        if payload.get("type") != "refresh":
            raise ValueError("Provided token is not a refresh token")

        staff_id = payload.get("sub")
        if not staff_id:
            raise ValueError("Invalid refresh token subject")

        token_hash = self.hash_refresh_token(token)
        key = f"refresh:{token_hash}"
        stored_staff_id = await redis.get(key)
        if not stored_staff_id or stored_staff_id != staff_id:
            raise ValueError("Refresh token is invalid or has been revoked")

        # Revoke immediately to enforce one-time use rotation
        await redis.delete(key)
        return staff_id

    async def revoke_refresh_token(self, redis: aioredis.Redis, token: str) -> bool:
        """Revoke a refresh token from Redis (e.g. on logout)."""
        token_hash = self.hash_refresh_token(token)
        key = f"refresh:{token_hash}"
        deleted = await redis.delete(key)
        return deleted > 0

    @staticmethod
    def generate_mfa_secret() -> str:
        """Generate a new random TOTP base32 secret."""
        return pyotp.random_base32()

    @staticmethod
    def get_mfa_provisioning_uri(secret: str, email: str) -> str:
        """Generate an otpauth URI for QR code scanning in authenticator apps."""
        totp = pyotp.TOTP(secret)
        return totp.provisioning_uri(name=email, issuer_name="مرساة")

    @staticmethod
    def verify_totp(secret: str, code: str) -> bool:
        """Verify a 6-digit TOTP code against the secret key (allows +/- 30s window)."""
        totp = pyotp.TOTP(secret)
        return totp.verify(code, valid_window=1)


auth_service = AuthService()
