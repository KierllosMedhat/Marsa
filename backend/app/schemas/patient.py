from datetime import date, datetime
import uuid
from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.patient import PatientSex
from app.schemas.clinical import (
    DiagnosisResponse,
    MedicationResponse,
    PatientClinicalResponse,
    PatientFileResponse,
    PatientNoteResponse,
)


class PatientBase(BaseModel):
    name_ar: str = Field(..., description="Patient Arabic full name")
    name_en: str | None = Field(default=None, description="Patient English full name")
    dob: date | None = None
    sex: PatientSex = PatientSex.prefer_not_to_say
    national_id: str | None = Field(default=None, description="National ID plaintext (will be encrypted)")
    phone: str | None = None
    email: EmailStr | None = None
    address: str | None = None
    emergency_contact: dict | None = None
    occupation: str | None = None
    marital_status: str | None = None
    children: str | None = None
    first_session_date: date | None = None
    last_session_date: date | None = None


class PatientCreate(PatientBase):
    pass


class PatientUpdate(BaseModel):
    name_ar: str | None = None
    name_en: str | None = None
    dob: date | None = None
    sex: PatientSex | None = None
    national_id: str | None = None
    phone: str | None = None
    email: EmailStr | None = None
    address: str | None = None
    emergency_contact: dict | None = None
    occupation: str | None = None
    marital_status: str | None = None
    children: str | None = None
    first_session_date: date | None = None
    last_session_date: date | None = None


class PatientReceptionistResponse(BaseModel):
    """Limited view for receptionists: demographic & contact info only."""
    patient_id: uuid.UUID
    mrn: str
    name_ar: str
    name_en: str | None = None
    phone: str | None = None
    email: str | None = None
    occupation: str | None = None
    marital_status: str | None = None

    model_config = ConfigDict(from_attributes=True)


class PatientSummaryResponse(BaseModel):
    """Non-clinical summary accessible by both doctors and receptionists."""
    patient_id: uuid.UUID
    mrn: str
    name_ar: str
    name_en: str | None = None
    dob: date | None = None
    sex: PatientSex
    phone: str | None = None
    email: str | None = None
    address: str | None = None
    emergency_contact: dict | None = None
    occupation: str | None = None
    marital_status: str | None = None
    children: str | None = None
    first_session_date: date | None = None
    last_session_date: date | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PatientDoctorResponse(BaseModel):
    """Comprehensive patient record visible only to doctors, including decrypted clinical records."""
    patient_id: uuid.UUID
    mrn: str
    name_ar: str
    name_en: str | None = None
    dob: date | None = None
    sex: PatientSex
    national_id: str | None = None
    phone: str | None = None
    email: str | None = None
    address: str | None = None
    emergency_contact: dict | None = None
    occupation: str | None = None
    marital_status: str | None = None
    children: str | None = None
    first_session_date: date | None = None
    last_session_date: date | None = None
    created_by: uuid.UUID
    created_at: datetime
    updated_at: datetime
    clinical_record: PatientClinicalResponse | None = None
    diagnoses: list[DiagnosisResponse] = []
    medications: list[MedicationResponse] = []
    files: list[PatientFileResponse] = []
    notes: list[PatientNoteResponse] = []

    model_config = ConfigDict(from_attributes=True)


class PatientCreateResponse(BaseModel):
    """Response returned upon patient registration, with non-blocking duplicate alerts."""
    patient: PatientSummaryResponse
    warnings: list[str] = []
    possible_duplicates: list[PatientReceptionistResponse] = []
