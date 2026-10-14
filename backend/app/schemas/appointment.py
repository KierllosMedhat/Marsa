from decimal import Decimal
import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.appointment import AppointmentStatus
from app.models.booking import BookingStatus


class AppointmentTypeBase(BaseModel):
    name_ar: str
    name_en: str | None = None
    duration_minutes: int = Field(..., gt=0)
    price_egp: Decimal = Field(..., ge=0)
    is_active: bool = True


class AppointmentTypeCreate(AppointmentTypeBase):
    pass


class AppointmentTypeResponse(AppointmentTypeBase):
    type_id: uuid.UUID
    model_config = ConfigDict(from_attributes=True)


class AppointmentCreate(BaseModel):
    patient_id: uuid.UUID | None = None
    booking_request_id: uuid.UUID | None = None
    type_id: uuid.UUID
    slot_start: datetime
    slot_end: datetime
    notes: str | None = None


class AppointmentResponse(BaseModel):
    appointment_id: uuid.UUID
    patient_id: uuid.UUID | None = None
    booking_request_id: uuid.UUID | None = None
    type_id: uuid.UUID
    slot_start: datetime
    slot_end: datetime
    status: AppointmentStatus
    hold_expires_at: datetime | None = None
    hold_session_key: str | None = None
    notes: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class BookingRequestCreate(BaseModel):
    name: str = Field(..., description="Applicant Name")
    phone: str = Field(..., description="Applicant Phone")
    email: EmailStr | None = None
    type_id: uuid.UUID
    preferred_slot: datetime | None = None
    notes: str | None = None


class BookingRequestResponse(BaseModel):
    request_id: uuid.UUID
    name: str
    phone: str
    email: str | None = None
    type_id: uuid.UUID
    preferred_slot: datetime | None = None
    status: BookingStatus
    matching_patient_id: uuid.UUID | None = None
    notes: str | None = None
    model_config = ConfigDict(from_attributes=True)


class AppointmentStatusUpdate(BaseModel):
    status: AppointmentStatus


class BookingMatchRequest(BaseModel):
    patient_id: uuid.UUID
