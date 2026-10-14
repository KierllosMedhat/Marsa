import enum
import uuid
from datetime import datetime
from sqlalchemy import Boolean, DateTime, Enum, String, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, utcnow


class StaffRole(str, enum.Enum):
    doctor = "doctor"
    receptionist = "receptionist"
    admin = "admin"


class Staff(Base):
    """Staff member account (doctor, receptionist, admin)."""

    __tablename__ = "staff"

    staff_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    role: Mapped[StaffRole] = mapped_column(
        Enum(StaffRole, name="staff_role_enum", native_enum=False),
        nullable=False,
        index=True,
    )
    name_ar: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Arabic full name / الاسم بالكامل بالعربية",
    )
    name_en: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="English full name / الاسم بالإنجليزية",
    )
    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        index=True,
        nullable=False,
    )
    phone: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )
    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Argon2id password hash",
    )
    mfa_secret: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="TOTP MFA secret key",
    )
    mfa_enabled: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
        nullable=False,
    )

    # Relationships
    created_patients = relationship(
        "Patient",
        back_populates="creator",
        foreign_keys="Patient.created_by",
    )
    audit_logs = relationship(
        "AuditLog",
        back_populates="staff",
    )
