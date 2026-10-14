import enum
import uuid
from datetime import datetime
from sqlalchemy import DateTime, Enum, ForeignKey, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, utcnow


class BookingStatus(str, enum.Enum):
    pending_match = "pending_match"
    matched = "matched"
    rejected = "rejected"


class BookingRequest(Base):
    """Public booking request submitted by patients or prospects (strictly non-clinical)."""

    __tablename__ = "booking_requests"

    request_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Applicant name / اسم مقدم الطلب",
    )
    phone: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
        comment="Applicant phone / رقم هاتف مقدم الطلب",
    )
    email: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )
    type_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("appointment_types.type_id"),
        nullable=False,
    )
    preferred_slot: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Requested appointment preferred time slot",
    )
    status: Mapped[BookingStatus] = mapped_column(
        Enum(BookingStatus, name="booking_status_enum", native_enum=False),
        nullable=False,
        default=BookingStatus.pending_match,
        index=True,
    )
    matching_patient_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("patients.patient_id"),
        nullable=True,
    )
    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Brief patient-supplied administrative note (no clinical content)",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )

    # Relationships
    appointment_type = relationship("AppointmentType", back_populates="booking_requests")
    matching_patient = relationship("Patient", foreign_keys=[matching_patient_id])
