from datetime import date as DateType, datetime
import uuid
from pydantic import BaseModel, ConfigDict, Field

from app.models.clinical import DiagnosisStatus, NoteType, SessionStatus


class PatientClinicalUpdate(BaseModel):
    medical_history: str | None = None
    psychiatric_history: str | None = None
    family_history: str | None = None
    social_history: str | None = None
    history: str | None = None
    psychiatric_examinations: str | None = None
    physical_neurological_exam: str | None = None
    risk_assessment: str | None = None
    suicide_attempts: str | None = None
    admitted_before: str | None = None
    notes: str | None = None
    allergies: list | dict | None = None


class PatientClinicalResponse(BaseModel):
    patient_id: uuid.UUID
    medical_history: str | None = None
    psychiatric_history: str | None = None
    family_history: str | None = None
    social_history: str | None = None
    history: str | None = None
    psychiatric_examinations: str | None = None
    physical_neurological_exam: str | None = None
    risk_assessment: str | None = None
    suicide_attempts: str | None = None
    admitted_before: str | None = None
    notes: str | None = None
    allergies: list | dict | None = None
    updated_at: datetime
    updated_by: uuid.UUID

    model_config = ConfigDict(from_attributes=True)


class DiagnosisCreate(BaseModel):
    icd10_code: str | None = None
    description_ar: str = Field(..., description="Arabic diagnosis description")
    description_en: str | None = None
    date_diagnosed: DateType
    status: DiagnosisStatus = DiagnosisStatus.active


class DiagnosisUpdate(BaseModel):
    icd10_code: str | None = None
    description_ar: str | None = None
    description_en: str | None = None
    date_diagnosed: DateType | None = None
    status: DiagnosisStatus | None = None
    finalized_at: datetime | None = None


class DiagnosisResponse(BaseModel):
    diagnosis_id: uuid.UUID
    patient_id: uuid.UUID
    icd10_code: str | None = None
    description_ar: str
    description_en: str | None = None
    date_diagnosed: DateType
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
    duration: str | None = None
    date: DateType | None = None
    start_date: DateType | None = None
    end_date: DateType | None = None
    notes: str | None = None
    is_active: bool = True


class MedicationUpdate(BaseModel):
    name_ar: str | None = None
    name_en: str | None = None
    dose: str | None = None
    frequency: str | None = None
    route: str | None = None
    duration: str | None = None
    date: DateType | None = None
    start_date: DateType | None = None
    end_date: DateType | None = None
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
    duration: str | None = None
    date: DateType | None = None
    start_date: DateType | None = None
    end_date: DateType | None = None
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
    session_number: str | None = None
    chief_complaint: str | None = None
    sleep: str | None = None
    appetite: str | None = None
    mood: str | None = None
    anxiety: str | None = None
    suicidal_self_harm_assessment: str | None = None
    substance_use: str | None = None
    mental_status_examination: str | None = None
    diagnosis: str | None = None
    treatment_plan: str | None = None
    follow_up: str | None = None


class SessionUpdate(BaseModel):
    ended_at: datetime | None = None
    status: SessionStatus | None = None
    session_number: str | None = None
    chief_complaint: str | None = None
    sleep: str | None = None
    appetite: str | None = None
    mood: str | None = None
    anxiety: str | None = None
    suicidal_self_harm_assessment: str | None = None
    substance_use: str | None = None
    mental_status_examination: str | None = None
    diagnosis: str | None = None
    treatment_plan: str | None = None
    follow_up: str | None = None


class SessionResponse(BaseModel):
    session_id: uuid.UUID
    patient_id: uuid.UUID
    appointment_id: uuid.UUID | None = None
    started_at: datetime
    ended_at: datetime | None = None
    status: SessionStatus
    session_number: str | None = None
    chief_complaint: str | None = None
    sleep: str | None = None
    appetite: str | None = None
    mood: str | None = None
    anxiety: str | None = None
    suicidal_self_harm_assessment: str | None = None
    substance_use: str | None = None
    mental_status_examination: str | None = None
    diagnosis: str | None = None
    treatment_plan: str | None = None
    follow_up: str | None = None
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


class PatientFileCreate(BaseModel):
    file_name: str
    file_type: str
    file_location: str


class PatientFileResponse(BaseModel):
    file_id: uuid.UUID
    patient_id: uuid.UUID
    file_name: str
    file_type: str
    file_location: str
    created_at: datetime
    uploaded_by: uuid.UUID | None = None

    model_config = ConfigDict(from_attributes=True)


class PatientNoteCreate(BaseModel):
    note_text: str


class PatientNoteUpdate(BaseModel):
    note_text: str


class PatientNoteResponse(BaseModel):
    note_id: uuid.UUID
    patient_id: uuid.UUID
    note_text: str
    last_modified: datetime
    author_id: uuid.UUID | None = None

    model_config = ConfigDict(from_attributes=True)
