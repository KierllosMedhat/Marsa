import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db, utcnow
from app.dependencies import require_role
from app.models.clinical import (
    Diagnosis,
    Medication,
    PatientClinical,
    PatientFile,
    PatientNote,
    Session,
    SessionNote,
)
from app.models.patient import Patient
from app.models.staff import Staff, StaffRole
from app.schemas.clinical import (
    DiagnosisCreate,
    DiagnosisResponse,
    MedicationCreate,
    MedicationResponse,
    PatientClinicalResponse,
    PatientClinicalUpdate,
    PatientFileCreate,
    PatientFileResponse,
    PatientNoteCreate,
    PatientNoteResponse,
    SessionCreate,
    SessionNoteCreate,
    SessionNoteResponse,
    SessionResponse,
    SessionUpdate,
)
from app.services.audit_service import audit_service
from app.utils.encryption import decrypt_field, encrypt_field

router = APIRouter(prefix="/clinical", tags=["Clinical Records"])


# ==========================================
# Patient Sensitive Clinical History
# ==========================================

@router.put(
    "/patients/{patient_id}/clinical",
    response_model=PatientClinicalResponse,
)
@router.post(
    "/patients/{patient_id}/clinical",
    response_model=PatientClinicalResponse,
)
async def update_patient_clinical_history(
    patient_id: uuid.UUID,
    payload: PatientClinicalUpdate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Create or update patient sensitive clinical history (AES-256-GCM encrypted)."""
    patient = await db.get(Patient, patient_id)
    if not patient or patient.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    clinical = await db.get(PatientClinical, patient_id)
    if not clinical:
        clinical = PatientClinical(
            patient_id=patient_id,
            updated_by=current_staff.staff_id,
        )
        db.add(clinical)

    if payload.medical_history is not None:
        clinical.medical_history = encrypt_field(payload.medical_history)
    if payload.psychiatric_history is not None:
        clinical.psychiatric_history = encrypt_field(payload.psychiatric_history)
    if payload.family_history is not None:
        clinical.family_history = encrypt_field(payload.family_history)
    if payload.social_history is not None:
        clinical.social_history = encrypt_field(payload.social_history)
    if payload.history is not None:
        clinical.history = encrypt_field(payload.history)
    if payload.psychiatric_examinations is not None:
        clinical.psychiatric_examinations = encrypt_field(payload.psychiatric_examinations)
    if payload.physical_neurological_exam is not None:
        clinical.physical_neurological_exam = encrypt_field(payload.physical_neurological_exam)
    if payload.risk_assessment is not None:
        clinical.risk_assessment = encrypt_field(payload.risk_assessment)
    if payload.suicide_attempts is not None:
        clinical.suicide_attempts = encrypt_field(payload.suicide_attempts)
    if payload.admitted_before is not None:
        clinical.admitted_before = encrypt_field(payload.admitted_before)
    if payload.notes is not None:
        clinical.notes = encrypt_field(payload.notes)
    if payload.allergies is not None:
        clinical.allergies = payload.allergies

    clinical.updated_by = current_staff.staff_id
    clinical.updated_at = utcnow()

    await db.commit()
    await db.refresh(clinical)

    await audit_service.log_event(
        db=db,
        action="update_clinical_history",
        resource_type="patient_clinical",
        staff_id=current_staff.staff_id,
        resource_id=patient_id,
    )

    return PatientClinicalResponse(
        patient_id=clinical.patient_id,
        medical_history=decrypt_field(clinical.medical_history) if clinical.medical_history else None,
        psychiatric_history=decrypt_field(clinical.psychiatric_history) if clinical.psychiatric_history else None,
        family_history=decrypt_field(clinical.family_history) if clinical.family_history else None,
        social_history=decrypt_field(clinical.social_history) if clinical.social_history else None,
        history=decrypt_field(clinical.history) if clinical.history else None,
        psychiatric_examinations=decrypt_field(clinical.psychiatric_examinations) if clinical.psychiatric_examinations else None,
        physical_neurological_exam=decrypt_field(clinical.physical_neurological_exam) if clinical.physical_neurological_exam else None,
        risk_assessment=decrypt_field(clinical.risk_assessment) if clinical.risk_assessment else None,
        suicide_attempts=decrypt_field(clinical.suicide_attempts) if clinical.suicide_attempts else None,
        admitted_before=decrypt_field(clinical.admitted_before) if clinical.admitted_before else None,
        notes=decrypt_field(clinical.notes) if clinical.notes else None,
        allergies=clinical.allergies,
        updated_at=clinical.updated_at,
        updated_by=clinical.updated_by,
    )


# ==========================================
# Diagnoses
# ==========================================

@router.post(
    "/patients/{patient_id}/diagnoses",
    response_model=DiagnosisResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_diagnosis(
    patient_id: uuid.UUID,
    payload: DiagnosisCreate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Add a psychiatric or medical diagnosis to a patient record."""
    patient = await db.get(Patient, patient_id)
    if not patient or patient.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    diagnosis = Diagnosis(
        patient_id=patient_id,
        icd10_code=payload.icd10_code,
        description_ar=payload.description_ar,
        description_en=payload.description_en,
        date_diagnosed=payload.date_diagnosed,
        status=payload.status,
        author_id=current_staff.staff_id,
    )
    db.add(diagnosis)
    await db.commit()
    await db.refresh(diagnosis)

    await audit_service.log_event(
        db=db,
        action="add_diagnosis",
        resource_type="diagnosis",
        staff_id=current_staff.staff_id,
        resource_id=diagnosis.diagnosis_id,
    )

    return diagnosis


# ==========================================
# Medications
# ==========================================

@router.post(
    "/patients/{patient_id}/medications",
    response_model=MedicationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_medication(
    patient_id: uuid.UUID,
    payload: MedicationCreate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Add a psychiatric prescription / medication to a patient record."""
    patient = await db.get(Patient, patient_id)
    if not patient or patient.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    medication = Medication(
        patient_id=patient_id,
        name_ar=payload.name_ar,
        name_en=payload.name_en,
        dose=payload.dose,
        frequency=payload.frequency,
        route=payload.route,
        duration=payload.duration,
        date=payload.date,
        start_date=payload.start_date,
        end_date=payload.end_date,
        notes=payload.notes,
        is_active=payload.is_active,
        prescribed_by=current_staff.staff_id,
    )
    db.add(medication)
    await db.commit()
    await db.refresh(medication)

    await audit_service.log_event(
        db=db,
        action="prescribe_medication",
        resource_type="medication",
        staff_id=current_staff.staff_id,
        resource_id=medication.medication_id,
    )

    return medication


# ==========================================
# Clinical Sessions
# ==========================================

@router.post(
    "/sessions",
    response_model=SessionResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_session(
    payload: SessionCreate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Start or create a psychiatric clinical session."""
    patient = await db.get(Patient, payload.patient_id)
    if not patient or patient.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    session = Session(
        patient_id=payload.patient_id,
        appointment_id=payload.appointment_id,
        started_at=payload.started_at,
        ended_at=payload.ended_at,
        status=payload.status,
        session_number=payload.session_number,
        chief_complaint=payload.chief_complaint,
        sleep=payload.sleep,
        appetite=payload.appetite,
        mood=payload.mood,
        anxiety=payload.anxiety,
        suicidal_self_harm_assessment=payload.suicidal_self_harm_assessment,
        substance_use=payload.substance_use,
        mental_status_examination=payload.mental_status_examination,
        diagnosis=payload.diagnosis,
        treatment_plan=payload.treatment_plan,
        follow_up=payload.follow_up,
        created_by=current_staff.staff_id,
    )
    db.add(session)

    # Update patient's first_session_date or last_session_date
    session_date = payload.started_at.date()
    if patient.first_session_date is None:
        patient.first_session_date = session_date
    patient.last_session_date = session_date

    await db.commit()
    await db.refresh(session)

    await audit_service.log_event(
        db=db,
        action="create_session",
        resource_type="session",
        staff_id=current_staff.staff_id,
        resource_id=session.session_id,
    )

    return session


@router.put("/sessions/{session_id}", response_model=SessionResponse)
@router.patch("/sessions/{session_id}", response_model=SessionResponse)
async def update_session(
    session_id: uuid.UUID,
    payload: SessionUpdate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Update clinical session assessment and psychiatric evaluation."""
    session = await db.get(Session, session_id)
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    if payload.ended_at is not None:
        session.ended_at = payload.ended_at
    if payload.status is not None:
        session.status = payload.status
        if payload.status == "finalized":
            session.finalized_by = current_staff.staff_id
            session.finalized_at = utcnow()
    if payload.session_number is not None:
        session.session_number = payload.session_number
    if payload.chief_complaint is not None:
        session.chief_complaint = payload.chief_complaint
    if payload.sleep is not None:
        session.sleep = payload.sleep
    if payload.appetite is not None:
        session.appetite = payload.appetite
    if payload.mood is not None:
        session.mood = payload.mood
    if payload.anxiety is not None:
        session.anxiety = payload.anxiety
    if payload.suicidal_self_harm_assessment is not None:
        session.suicidal_self_harm_assessment = payload.suicidal_self_harm_assessment
    if payload.substance_use is not None:
        session.substance_use = payload.substance_use
    if payload.mental_status_examination is not None:
        session.mental_status_examination = payload.mental_status_examination
    if payload.diagnosis is not None:
        session.diagnosis = payload.diagnosis
    if payload.treatment_plan is not None:
        session.treatment_plan = payload.treatment_plan
    if payload.follow_up is not None:
        session.follow_up = payload.follow_up

    await db.commit()
    await db.refresh(session)
    return session


# ==========================================
# Session Notes (Typed & Handwritten)
# ==========================================

@router.post(
    "/sessions/{session_id}/notes",
    response_model=SessionNoteResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_session_note(
    session_id: uuid.UUID,
    payload: SessionNoteCreate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Create a confidential clinical session note (AES-256-GCM encrypted)."""
    session = await db.get(Session, session_id)
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    encrypted_content = (
        encrypt_field(payload.content_typed) if payload.content_typed else None
    )

    # Determine version
    res = await db.execute(
        select(SessionNote.version)
        .where(SessionNote.session_id == session_id)
        .order_by(SessionNote.version.desc())
    )
    latest_version = res.scalars().first() or 0
    next_version = latest_version + 1

    note = SessionNote(
        session_id=session_id,
        note_type=payload.note_type,
        content_typed=encrypted_content,
        content_ink_ref=payload.content_ink_ref,
        version=next_version,
        is_draft=payload.is_draft,
        amended_from=payload.amended_from,
        edited_by=current_staff.staff_id,
    )
    db.add(note)
    await db.commit()
    await db.refresh(note)

    await audit_service.log_event(
        db=db,
        action="create_session_note",
        resource_type="session_note",
        staff_id=current_staff.staff_id,
        resource_id=note.note_id,
        details={"version": note.version, "is_draft": note.is_draft},
    )

    return SessionNoteResponse(
        note_id=note.note_id,
        session_id=note.session_id,
        note_type=note.note_type,
        content_typed=decrypt_field(note.content_typed) if note.content_typed else None,
        content_ink_ref=note.content_ink_ref,
        version=note.version,
        is_draft=note.is_draft,
        amended_from=note.amended_from,
        edited_at=note.edited_at,
        edited_by=note.edited_by,
    )


@router.get(
    "/sessions/{session_id}/notes",
    response_model=list[SessionNoteResponse],
)
async def list_session_notes(
    session_id: uuid.UUID,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve all decrypted session notes for a clinical session."""
    session = await db.get(Session, session_id)
    if not session:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Session not found")

    res = await db.execute(
        select(SessionNote)
        .where(SessionNote.session_id == session_id)
        .order_by(SessionNote.version.desc())
    )
    notes = res.scalars().all()

    return [
        SessionNoteResponse(
            note_id=n.note_id,
            session_id=n.session_id,
            note_type=n.note_type,
            content_typed=decrypt_field(n.content_typed) if n.content_typed else None,
            content_ink_ref=n.content_ink_ref,
            version=n.version,
            is_draft=n.is_draft,
            amended_from=n.amended_from,
            edited_at=n.edited_at,
            edited_by=n.edited_by,
        )
        for n in notes
    ]


# ==========================================
# Patient Files & Attachments
# ==========================================

@router.get(
    "/patients/{patient_id}/files",
    response_model=list[PatientFileResponse],
)
async def list_patient_files(
    patient_id: uuid.UUID,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve clinical attachments and files for a patient."""
    res = await db.execute(
        select(PatientFile)
        .where(PatientFile.patient_id == patient_id)
        .order_by(PatientFile.created_at.desc())
    )
    return res.scalars().all()


@router.post(
    "/patients/{patient_id}/files",
    response_model=PatientFileResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_patient_file(
    patient_id: uuid.UUID,
    payload: PatientFileCreate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Attach a clinical report, lab, or scan record to a patient."""
    patient = await db.get(Patient, patient_id)
    if not patient or patient.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    file_entry = PatientFile(
        patient_id=patient_id,
        file_name=payload.file_name,
        file_type=payload.file_type,
        file_location=payload.file_location,
        uploaded_by=current_staff.staff_id,
    )
    db.add(file_entry)
    await db.commit()
    await db.refresh(file_entry)

    await audit_service.log_event(
        db=db,
        action="add_patient_file",
        resource_type="patient_file",
        staff_id=current_staff.staff_id,
        resource_id=file_entry.file_id,
    )

    return file_entry


# ==========================================
# Patient Quick Notes
# ==========================================

@router.get(
    "/patients/{patient_id}/notes",
    response_model=list[PatientNoteResponse],
)
async def list_patient_notes(
    patient_id: uuid.UUID,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve doctor's quick notes for a patient."""
    res = await db.execute(
        select(PatientNote)
        .where(PatientNote.patient_id == patient_id)
        .order_by(PatientNote.last_modified.desc())
    )
    return res.scalars().all()


@router.post(
    "/patients/{patient_id}/notes",
    response_model=PatientNoteResponse,
    status_code=status.HTTP_201_CREATED,
)
async def add_patient_note(
    patient_id: uuid.UUID,
    payload: PatientNoteCreate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Add a quick clinical note to a patient profile."""
    patient = await db.get(Patient, patient_id)
    if not patient or patient.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    note_entry = PatientNote(
        patient_id=patient_id,
        note_text=payload.note_text,
        author_id=current_staff.staff_id,
    )
    db.add(note_entry)
    await db.commit()
    await db.refresh(note_entry)

    await audit_service.log_event(
        db=db,
        action="add_patient_note",
        resource_type="patient_note",
        staff_id=current_staff.staff_id,
        resource_id=note_entry.note_id,
    )

    return note_entry


@router.delete(
    "/patients/{patient_id}/notes/{note_id}",
    status_code=status.HTTP_200_OK,
)
async def delete_patient_note(
    patient_id: uuid.UUID,
    note_id: uuid.UUID,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Delete a quick clinical note."""
    note = await db.get(PatientNote, note_id)
    if not note or note.patient_id != patient_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Note not found")

    await db.delete(note)
    await db.commit()
    return {"message": "Note deleted successfully"}
