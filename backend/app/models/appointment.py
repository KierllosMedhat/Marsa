from decimal import Decimal
import enum
import uuid
from datetime import datetime
from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, Numeric, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, utcnow


class AppointmentStatus(str, enum.Enum):
    available = "available"
    held = "held"
    confirmed = "confirmed"
    cancelled = "cancelled"
    no_show = "no_show"
    completed = "completed"


class AppointmentType(Base):
    """Clinic appointment types (e.g. Initial Assessment, Therapy Session, Follow-up)."""

    __tablename__ = "appointment_types"

    type_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    name_ar: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Type name in Arabic / نوع الموعد بالعربية",
    )
    name_en: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Type name in English / نوع الموعد بالإنجليزية",
    )
    duration_minutes: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="Session duration in minutes / مدة الجلسة بالدقائق",
    )
    price_egp: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
        comment="Price in Egyptian Pounds / السعر بالجنيه المصري",
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )

    # Relationships
    appointments = relationship("Appointment", back_populates="appointment_type")
    booking_requests = relationship("BookingRequest", back_populates="appointment_type")


class Appointment(Base):
    """Scheduled clinic appointments."""

    __tablename__ = "appointments"

    appointment_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    patient_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("patients.patient_id"),
        nullable=True,
        index=True,
        comment="Patient ID (null indicates unmatched public booking slot)",
    )
    booking_request_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("booking_requests.request_id"),
        nullable=True,
        index=True,
    )
    type_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("appointment_types.type_id"),
        nullable=False,
    )
    slot_start: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )
    slot_end: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    status: Mapped[AppointmentStatus] = mapped_column(
        Enum(AppointmentStatus, name="appointment_status_enum", native_enum=False),
        nullable=False,
        default=AppointmentStatus.available,
        index=True,
    )
    hold_expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Expiry timestamp for temporary slot hold",
    )
    hold_session_key: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Redis key for holding this slot during checkout",
    )
    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
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
    patient = relationship("Patient", back_populates="appointments")
    appointment_type = relationship("AppointmentType", back_populates="appointments")
    booking_request = relationship("BookingRequest", foreign_keys=[booking_request_id])
    session = relationship("Session", back_populates="appointment", uselist=False)
    payments = relationship("Payment", back_populates="appointment")
