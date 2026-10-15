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
    SessionCreate,
    SessionNoteCreate,
    SessionNoteResponse,
    SessionResponse,
)
from app.services.audit_service import audit_service
from app.utils.encryption import decrypt_field, encrypt_field

router = APIRouter(prefix="/clinical", tags=["Clinical Records"])


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
        allergies=clinical.allergies,
        updated_at=clinical.updated_at,
        updated_by=clinical.updated_by,
    )


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


@router.post(
    "/patients/{patient_id}/medications",
    response_model=MedicationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def prescribe_medication(
    patient_id: uuid.UUID,
    payload: MedicationCreate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Prescribe a psychiatric medication for a patient."""
    patient = await db.get(Patient, patient_id)
    if not patient or patient.deleted_at is not None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Patient not found")

    med = Medication(
        patient_id=patient_id,
        name_ar=payload.name_ar,
        name_en=payload.name_en,
        dose=payload.dose,
        frequency=payload.frequency,
        route=payload.route,
        start_date=payload.start_date,
        end_date=payload.end_date,
        notes=payload.notes,
        prescribed_by=current_staff.staff_id,
        is_active=payload.is_active,
    )
    db.add(med)
    await db.commit()
    await db.refresh(med)

    await audit_service.log_event(
        db=db,
        action="prescribe_medication",
        resource_type="medication",
        staff_id=current_staff.staff_id,
        resource_id=med.medication_id,
    )

    return med


@router.post("/sessions", response_model=SessionResponse, status_code=status.HTTP_201_CREATED)
async def create_session(
    payload: SessionCreate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Create a clinical therapy or consultation session."""
    session = Session(
        patient_id=payload.patient_id,
        appointment_id=payload.appointment_id,
        started_at=payload.started_at,
        ended_at=payload.ended_at,
        status=payload.status,
        created_by=current_staff.staff_id,
    )
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session


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
    """Create a confidential clinical session note (AES-256-GCM encrypted).

    RESTRICTED TO DOCTORS ONLY. Receptionists will receive HTTP 403 Forbidden.
    """
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
