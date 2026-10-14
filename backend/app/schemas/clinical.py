from datetime import date, datetime
import uuid
from pydantic import BaseModel, ConfigDict, Field

from app.models.clinical import DiagnosisStatus, NoteType, SessionStatus


class PatientClinicalUpdate(BaseModel):
    medical_history: str | None = None
    psychiatric_history: str | None = None
    family_history: str | None = None
    social_history: str | None = None
    allergies: list | dict | None = None


class PatientClinicalResponse(BaseModel):
    patient_id: uuid.UUID
    medical_history: str | None = None
    psychiatric_history: str | None = None
    family_history: str | None = None
    social_history: str | None = None
    allergies: list | dict | None = None
    updated_at: datetime
    updated_by: uuid.UUID

    model_config = ConfigDict(from_attributes=True)


class DiagnosisCreate(BaseModel):
    icd10_code: str | None = None
    description_ar: str = Field(..., description="Arabic diagnosis description")
    description_en: str | None = None
    date_diagnosed: date
    status: DiagnosisStatus = DiagnosisStatus.active


class DiagnosisUpdate(BaseModel):
    icd10_code: str | None = None
    description_ar: str | None = None
    description_en: str | None = None
    date_diagnosed: date | None = None
    status: DiagnosisStatus | None = None
    finalized_at: datetime | None = None


class DiagnosisResponse(BaseModel):
    diagnosis_id: uuid.UUID
    patient_id: uuid.UUID
    icd10_code: str | None = None
    description_ar: str
    description_en: str | None = None
    date_diagnosed: date
    status: DiagnosisStatus
    author_id: uuid.UUID
    created_at: datetime
    finalized_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class MedicationCreate(BaseModel):
    name_ar: str = Field(..., description="Arabic medication name")
    name_en: str | None = None
    dose: str | None = None
    frequency: str | None = None
    route: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    notes: str | None = None
    is_active: bool = True


class MedicationUpdate(BaseModel):
    name_ar: str | None = None
    name_en: str | None = None
    dose: str | None = None
    frequency: str | None = None
    route: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    notes: str | None = None
    is_active: bool | None = None


class MedicationResponse(BaseModel):
    medication_id: uuid.UUID
    patient_id: uuid.UUID
    name_ar: str
    name_en: str | None = None
    dose: str | None = None
    frequency: str | None = None
    route: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    notes: str | None = None
    prescribed_by: uuid.UUID
    is_active: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SessionCreate(BaseModel):
    patient_id: uuid.UUID
    appointment_id: uuid.UUID | None = None
    started_at: datetime
    ended_at: datetime | None = None
    status: SessionStatus = SessionStatus.draft


class SessionResponse(BaseModel):
    session_id: uuid.UUID
    patient_id: uuid.UUID
    appointment_id: uuid.UUID | None = None
    started_at: datetime
    ended_at: datetime | None = None
    status: SessionStatus
    created_by: uuid.UUID
    finalized_by: uuid.UUID | None = None
    finalized_at: datetime | None = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class SessionNoteCreate(BaseModel):
    note_type: NoteType = NoteType.typed
    content_typed: str | None = None
    content_ink_ref: str | None = None
    is_draft: bool = True
    amended_from: uuid.UUID | None = None


class SessionNoteResponse(BaseModel):
    note_id: uuid.UUID
    session_id: uuid.UUID
    note_type: NoteType
    content_typed: str | None = None
    content_ink_ref: str | None = None
    version: int
    is_draft: bool
    amended_from: uuid.UUID | None = None
    edited_at: datetime
    edited_by: uuid.UUID

    model_config = ConfigDict(from_attributes=True)
