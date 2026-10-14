import uuid
from datetime import datetime
from sqlalchemy import DateTime, ForeignKey, String, Text, Uuid, JSON
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, utcnow


class AuditLog(Base):
    """Audit log tracking system and sensitive patient record accesses (no clinical data)."""

    __tablename__ = "audit_log"

    log_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    staff_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("staff.staff_id"),
        nullable=True,
        index=True,
        comment="Staff member who performed the action (null if unauthenticated/public)",
    )
    action: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True,
        comment="Action performed: e.g. read_patient, create_patient, finalize_note",
    )
    resource_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True,
        comment="Resource type affected: e.g. patient, session_note, auth",
    )
    resource_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        nullable=True,
        index=True,
    )
    ip_address: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )
    user_agent: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
        index=True,
    )
    details: Mapped[dict | None] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"),
        nullable=True,
        comment="Structured metadata (MUST NOT contain clinical notes or sensitive patient health info)",
    )

    # Relationships
    staff = relationship("Staff", back_populates="audit_logs")
