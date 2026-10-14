from decimal import Decimal
import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict, Field

from app.models.payment import PaymentMethod, PaymentStatus


class PaymentCreate(BaseModel):
    appointment_id: uuid.UUID
    amount_egp: Decimal = Field(..., gt=0)
    currency: str = "EGP"
    method: PaymentMethod
    gateway_ref: str | None = None
    idempotency_key: str | None = None


class PaymentResponse(BaseModel):
    payment_id: uuid.UUID
    appointment_id: uuid.UUID
    amount_egp: Decimal
    currency: str
    method: PaymentMethod
    gateway_ref: str | None = None
    idempotency_key: str | None = None
    status: PaymentStatus
    confirmed_at: datetime | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
