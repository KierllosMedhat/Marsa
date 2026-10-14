import uuid
from fastapi import APIRouter, Depends, HTTPException, status
import redis.asyncio as aioredis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_staff
from app.models.staff import Staff
from app.redis_client import get_redis
from app.schemas.staff import (
    LoginRequest,
    LoginResponse,
    MFASetupResponse,
    MFAVerifyRequest,
    StaffResponse,
    TokenRefreshRequest,
    TokenResponse,
)
from app.services.auth_service import auth_service

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/login", response_model=LoginResponse)
async def login(
    request: LoginRequest,
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """Authenticate staff using email and password. Returns tokens or prompts for MFA."""
    result = await db.execute(select(Staff).where(Staff.email == request.email))
    staff = result.scalar_one_or_none()

    if not staff or not auth_service.verify_password(staff.password_hash, request.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not staff.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Staff account is inactive",
        )

    # Check if MFA is required for this staff member
    if staff.mfa_enabled and staff.mfa_secret:
        mfa_token = auth_service.create_mfa_token(str(staff.staff_id))
        return LoginResponse(
            requires_mfa=True,
            mfa_token=mfa_token,
        )

    # Issue standard JWT tokens
    access_token = auth_service.create_access_token(
        data={"sub": str(staff.staff_id), "role": staff.role.value, "email": staff.email}
    )
    refresh_token = auth_service.create_refresh_token(str(staff.staff_id))
    await auth_service.store_refresh_token(redis, refresh_token, str(staff.staff_id))

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        requires_mfa=False,
    )


@router.post("/mfa/setup", response_model=MFASetupResponse)
async def setup_mfa(
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Generate and configure a TOTP secret for the authenticated staff member."""
    secret = auth_service.generate_mfa_secret()
    current_staff.mfa_secret = secret
    current_staff.mfa_enabled = True
    await db.commit()

    otpauth_url = auth_service.get_mfa_provisioning_uri(secret, current_staff.email)
    return MFASetupResponse(
        secret=secret,
        otpauth_url=otpauth_url,
    )


@router.post("/mfa/verify", response_model=TokenResponse)
async def verify_mfa(
    request: MFAVerifyRequest,
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """Verify TOTP code using an mfa_token and return full access and refresh tokens."""
    if not request.mfa_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Missing required mfa_token",
        )

    try:
        payload = auth_service.decode_token(request.mfa_token)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired MFA token: {e}",
        ) from e

    if payload.get("type") != "mfa_pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Token is not valid for MFA verification",
        )

    staff_id_str = payload.get("sub")
    staff = await db.get(Staff, uuid.UUID(staff_id_str))
    if not staff or not staff.mfa_secret:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="MFA is not configured for this account",
        )

    if not auth_service.verify_totp(staff.mfa_secret, request.code):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid MFA verification code",
        )

    access_token = auth_service.create_access_token(
        data={"sub": str(staff.staff_id), "role": staff.role.value, "email": staff.email}
    )
    refresh_token = auth_service.create_refresh_token(str(staff.staff_id))
    await auth_service.store_refresh_token(redis, refresh_token, str(staff.staff_id))

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_tokens(
    request: TokenRefreshRequest,
    db: AsyncSession = Depends(get_db),
    redis: aioredis.Redis = Depends(get_redis),
):
    """Exchange a valid refresh token for a new access token and rotated refresh token."""
    try:
        staff_id_str = await auth_service.verify_and_revoke_refresh_token(
            redis, request.refresh_token
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        ) from e

    staff = await db.get(Staff, uuid.UUID(staff_id_str))
    if not staff or not staff.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Staff member no longer active",
        )

    new_access_token = auth_service.create_access_token(
        data={"sub": str(staff.staff_id), "role": staff.role.value, "email": staff.email}
    )
    new_refresh_token = auth_service.create_refresh_token(str(staff.staff_id))
    await auth_service.store_refresh_token(redis, new_refresh_token, str(staff.staff_id))

    return TokenResponse(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
    )


@router.post("/logout", status_code=status.HTTP_200_OK)
async def logout(
    request: TokenRefreshRequest,
    redis: aioredis.Redis = Depends(get_redis),
):
    """Revoke refresh token in Redis upon staff logout."""
    await auth_service.revoke_refresh_token(redis, request.refresh_token)
    return {"message": "Successfully logged out"}


@router.get("/me", response_model=StaffResponse)
async def get_current_staff_info(
    current_staff: Staff = Depends(get_current_staff),
):
    """Return profile details for the currently authenticated staff member."""
    return current_staff
