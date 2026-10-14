import uuid
from typing import Any
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit import AuditLog


class AuditService:
    """Service to create audit log records. Never logs sensitive clinical notes."""

    @staticmethod
    async def log_event(
        db: AsyncSession,
        action: str,
        resource_type: str,
        staff_id: uuid.UUID | None = None,
        resource_id: uuid.UUID | None = None,
        ip_address: str | None = None,
        user_agent: str | None = None,
        details: dict[str, Any] | None = None,
    ) -> AuditLog:
        """Create and commit an audit log entry."""
        log_entry = AuditLog(
            staff_id=staff_id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            ip_address=ip_address,
            user_agent=user_agent,
            details=details or {},
        )
        db.add(log_entry)
        await db.commit()
        await db.refresh(log_entry)
        return log_entry


audit_service = AuditService()
