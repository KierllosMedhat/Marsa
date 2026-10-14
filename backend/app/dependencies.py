import uuid
from typing import Callable
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.staff import Staff, StaffRole
from app.services.auth_service import auth_service

security_bearer = HTTPBearer(auto_error=False)


async def get_current_staff(
    credentials: HTTPAuthorizationCredentials | None = Security(security_bearer),
    db: AsyncSession = Depends(get_db),
) -> Staff:
    """FastAPI dependency to extract and authenticate the current staff member from Bearer token."""
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication credentials were not provided",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = credentials.credentials
    try:
        payload = auth_service.decode_token(token)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        ) from e

    token_type = payload.get("type")
    if token_type != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type: access token required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    staff_id_str = payload.get("sub")
    if not staff_id_str:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: missing subject claim",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        staff_id = uuid.UUID(staff_id_str)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid staff ID in token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from e

    staff = await db.get(Staff, staff_id)
    if not staff or not staff.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Staff account not found or deactivated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return staff


def require_role(*roles: StaffRole) -> Callable:
    """FastAPI dependency factory enforcing staff role permissions.

    Raises HTTP 403 (Forbidden) if staff role does not match, preserving
    auditability so unauthorized roles know the resource exists but is denied.
    """
    async def role_checker(
        current_staff: Staff = Depends(get_current_staff),
    ) -> Staff:
        if current_staff.role not in roles:
            allowed = ", ".join(r.value for r in roles)
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access forbidden: requires one of [{allowed}], your role is '{current_staff.role.value}'",
            )
        return current_staff

    return role_checker
