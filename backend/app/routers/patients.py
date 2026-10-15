import uuid
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db, utcnow
from app.dependencies import get_current_staff, require_role
from app.models.clinical import PatientClinical
from app.models.patient import Patient
from app.models.staff import Staff, StaffRole
from app.schemas.clinical import (
    DiagnosisResponse,
    MedicationResponse,
    PatientClinicalResponse,
)
from app.schemas.patient import (
    PatientCreate,
    PatientCreateResponse,
    PatientDoctorResponse,
    PatientReceptionistResponse,
    PatientSummaryResponse,
    PatientUpdate,
)
from app.services.audit_service import audit_service
from app.utils.encryption import decrypt_field, encrypt_field

router = APIRouter(prefix="/patients", tags=["Patients"])


async def generate_next_mrn(db: AsyncSession) -> str:
    """Generate the next auto-incremented MRN in the format MRN-00001."""
    result = await db.execute(select(func.count(Patient.patient_id)))
    count = (result.scalar_one() or 0) + 1
    while True:
        candidate_mrn = f"MRN-{count:05d}"
        check = await db.execute(select(Patient.patient_id).where(Patient.mrn == candidate_mrn))
        if check.scalar_one_or_none() is None:
            return candidate_mrn
        count += 1


def build_doctor_patient_response(patient: Patient) -> PatientDoctorResponse:
    """Helper to assemble a complete doctor view with decrypted sensitive fields."""
    decrypted_nid = decrypt_field(patient.national_id) if patient.national_id else None

    clinical_resp = None
    if patient.clinical_record:
        cr = patient.clinical_record
        clinical_resp = PatientClinicalResponse(
            patient_id=cr.patient_id,
            medical_history=decrypt_field(cr.medical_history) if cr.medical_history else None,
            psychiatric_history=decrypt_field(cr.psychiatric_history) if cr.psychiatric_history else None,
            family_history=decrypt_field(cr.family_history) if cr.family_history else None,
            social_history=decrypt_field(cr.social_history) if cr.social_history else None,
            allergies=cr.allergies,
            updated_at=cr.updated_at,
            updated_by=cr.updated_by,
        )

    diagnoses_resp = [DiagnosisResponse.model_validate(d) for d in (patient.diagnoses or [])]
    medications_resp = [MedicationResponse.model_validate(m) for m in (patient.medications or [])]

    return PatientDoctorResponse(
        patient_id=patient.patient_id,
        mrn=patient.mrn,
        name_ar=patient.name_ar,
        name_en=patient.name_en,
        dob=patient.dob,
        sex=patient.sex,
        national_id=decrypted_nid,
        phone=patient.phone,
        email=patient.email,
        address=patient.address,
        emergency_contact=patient.emergency_contact,
        created_by=patient.created_by,
        created_at=patient.created_at,
        updated_at=patient.updated_at,
        clinical_record=clinical_resp,
        diagnoses=diagnoses_resp,
        medications=medications_resp,
    )


@router.post("", response_model=PatientCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_patient(
    payload: PatientCreate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.receptionist, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Register a new patient with duplicate checking and auto-generated MRN.

    Accessible by both doctors and receptionists (collects basic demographic info).
    """
    # Duplicate detection: check for existing non-deleted patients with identical phone or similar name
    duplicate_query = select(Patient).where(
        Patient.deleted_at.is_(None),
        or_(
            Patient.phone == payload.phone if payload.phone else False,
            Patient.name_ar == payload.name_ar,
        ),
    )
    dup_res = await db.execute(duplicate_query)
    potential_duplicates = dup_res.scalars().all()

    warnings: list[str] = []
    possible_duplicates: list[PatientReceptionistResponse] = []
    if potential_duplicates:
        warnings.append(
            f"Found {len(potential_duplicates)} existing patient(s) with matching phone or Arabic name."
        )
        possible_duplicates = [
            PatientReceptionistResponse.model_validate(p) for p in potential_duplicates
        ]

    # Encrypt national ID if supplied
    encrypted_nid = encrypt_field(payload.national_id) if payload.national_id else None

    # Generate MRN
    mrn = await generate_next_mrn(db)

    new_patient = Patient(
        mrn=mrn,
        name_ar=payload.name_ar,
        name_en=payload.name_en,
        dob=payload.dob,
        sex=payload.sex,
        national_id=encrypted_nid,
        phone=payload.phone,
        email=payload.email,
        address=payload.address,
        emergency_contact=payload.emergency_contact,
        created_by=current_staff.staff_id,
    )
    db.add(new_patient)
    await db.commit()
    await db.refresh(new_patient)

    # Audit logging (no clinical content)
    await audit_service.log_event(
        db=db,
        action="create_patient",
        resource_type="patient",
        staff_id=current_staff.staff_id,
        resource_id=new_patient.patient_id,
        details={"mrn": new_patient.mrn, "created_by_role": current_staff.role.value},
    )

    summary = PatientSummaryResponse.model_validate(new_patient)
    return PatientCreateResponse(
        patient=summary,
        warnings=warnings,
        possible_duplicates=possible_duplicates,
    )


@router.get("", response_model=list[Any])
async def list_patients(
    q: str | None = Query(None, description="Search query by name, phone, or MRN"),
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """Search and list patients. Responses are strictly differentiated by staff role:

    - Doctor: full patient object including clinical subrecords
    - Receptionist: non-clinical contact summary only (id, mrn, name_ar, name_en, phone, email)
    """
    stmt = (
        select(Patient)
        .where(Patient.deleted_at.is_(None))
        .options(
            selectinload(Patient.clinical_record),
            selectinload(Patient.diagnoses),
            selectinload(Patient.medications),
        )
        .order_by(Patient.created_at.desc())
    )

    if q:
        search_pattern = f"%{q.strip()}%"
        stmt = stmt.where(
            or_(
                Patient.name_ar.ilike(search_pattern),
                Patient.name_en.ilike(search_pattern),
                Patient.phone.ilike(search_pattern),
                Patient.mrn.ilike(search_pattern),
            )
        )

    result = await db.execute(stmt)
    patients = result.scalars().all()

    if current_staff.role in (StaffRole.doctor, StaffRole.admin):
        return [build_doctor_patient_response(p) for p in patients]
    else:
        # Receptionist role gets strictly sanitized fields
        return [PatientReceptionistResponse.model_validate(p) for p in patients]


@router.get("/{patient_id}", response_model=PatientDoctorResponse)
async def get_patient_detail(
    patient_id: uuid.UUID,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve full psychiatric patient record. RESTRICTED TO DOCTORS ONLY (403 for receptionists)."""
    stmt = (
        select(Patient)
        .where(Patient.patient_id == patient_id, Patient.deleted_at.is_(None))
        .options(
            selectinload(Patient.clinical_record),
            selectinload(Patient.diagnoses),
            selectinload(Patient.medications),
        )
    )
    result = await db.execute(stmt)
    patient = result.scalar_one_or_none()

    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found",
        )

    await audit_service.log_event(
        db=db,
        action="read_patient",
        resource_type="patient",
        staff_id=current_staff.staff_id,
        resource_id=patient.patient_id,
    )

    return build_doctor_patient_response(patient)


@router.get("/{patient_id}/summary", response_model=PatientSummaryResponse)
async def get_patient_summary(
    patient_id: uuid.UUID,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.receptionist, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Retrieve non-clinical patient summary. Accessible by both receptionists and doctors."""
    stmt = select(Patient).where(Patient.patient_id == patient_id, Patient.deleted_at.is_(None))
    result = await db.execute(stmt)
    patient = result.scalar_one_or_none()

    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found",
        )

    return PatientSummaryResponse.model_validate(patient)


@router.put("/{patient_id}", response_model=PatientDoctorResponse)
@router.patch("/{patient_id}", response_model=PatientDoctorResponse)
async def update_patient(
    patient_id: uuid.UUID,
    payload: PatientUpdate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin, StaffRole.receptionist)),
    db: AsyncSession = Depends(get_db),
):
    """Update patient demographic and contact information."""
    stmt = (
        select(Patient)
        .where(Patient.patient_id == patient_id, Patient.deleted_at.is_(None))
        .options(
            selectinload(Patient.clinical_record),
            selectinload(Patient.diagnoses),
            selectinload(Patient.medications),
        )
    )
    result = await db.execute(stmt)
    patient = result.scalar_one_or_none()

    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found",
        )

    if payload.name_ar is not None:
        patient.name_ar = payload.name_ar
    if payload.name_en is not None:
        patient.name_en = payload.name_en
    if payload.dob is not None:
        patient.dob = payload.dob
    if payload.sex is not None:
        patient.sex = payload.sex
    if payload.national_id is not None:
        patient.national_id = encrypt_field(payload.national_id) if payload.national_id else None
    if payload.phone is not None:
        patient.phone = payload.phone
    if payload.email is not None:
        patient.email = payload.email
    if payload.address is not None:
        patient.address = payload.address
    if payload.emergency_contact is not None:
        patient.emergency_contact = payload.emergency_contact

    patient.updated_at = utcnow()
    await db.commit()
    await db.refresh(patient)

    await audit_service.log_event(
        db=db,
        action="update_patient",
        resource_type="patient",
        staff_id=current_staff.staff_id,
        resource_id=patient.patient_id,
    )

    return build_doctor_patient_response(patient)


@router.delete("/{patient_id}", status_code=status.HTTP_200_OK)
async def soft_delete_patient(
    patient_id: uuid.UUID,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a patient record by setting deleted_at timestamp."""
    stmt = select(Patient).where(Patient.patient_id == patient_id, Patient.deleted_at.is_(None))
    result = await db.execute(stmt)
    patient = result.scalar_one_or_none()

    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found",
        )

    patient.deleted_at = utcnow()
    await db.commit()

    await audit_service.log_event(
        db=db,
        action="delete_patient",
        resource_type="patient",
        staff_id=current_staff.staff_id,
        resource_id=patient.patient_id,
        details={"type": "soft_delete"},
    )

    return {"message": f"Patient {patient.mrn} successfully soft-deleted"}
