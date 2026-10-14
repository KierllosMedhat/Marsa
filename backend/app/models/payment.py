from decimal import Decimal
import enum
import uuid
from datetime import datetime
from sqlalchemy import DateTime, Enum, ForeignKey, Numeric, String, Uuid, JSON
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, utcnow


class PaymentMethod(str, enum.Enum):
    card = "card"
    vodafone_cash = "vodafone_cash"
    orange_cash = "orange_cash"
    etisalat_cash = "etisalat_cash"
    we_pay = "we_pay"
    fawry = "fawry"
    instapay_manual = "instapay_manual"
    cash = "cash"


class PaymentStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    failed = "failed"
    refunded = "refunded"
    manual_pending = "manual_pending"


class Payment(Base):
    """Payment transactions for appointments."""

    __tablename__ = "payments"

    payment_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    appointment_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("appointments.appointment_id"),
        nullable=False,
        index=True,
    )
    amount_egp: Mapped[Decimal] = mapped_column(
        Numeric(10, 2),
        nullable=False,
        comment="Amount in EGP / المبلغ بالجنيه المصري",
    )
    currency: Mapped[str] = mapped_column(
        String(10),
        default="EGP",
        nullable=False,
    )
    method: Mapped[PaymentMethod] = mapped_column(
        Enum(PaymentMethod, name="payment_method_enum", native_enum=False),
        nullable=False,
    )
    gateway_ref: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Payment gateway reference or transaction ID",
    )
    idempotency_key: Mapped[str | None] = mapped_column(
        String(255),
        unique=True,
        index=True,
        nullable=True,
        comment="Idempotency key to prevent double charging",
    )
    status: Mapped[PaymentStatus] = mapped_column(
        Enum(PaymentStatus, name="payment_status_enum", native_enum=False),
        nullable=False,
        default=PaymentStatus.pending,
        index=True,
    )
    confirmed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    gateway_response: Mapped[dict | None] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"),
        nullable=True,
        comment="Raw response from payment gateway / رد بوابة الدفع",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )

    # Relationships
    appointment = relationship("Appointment", back_populates="payments")
