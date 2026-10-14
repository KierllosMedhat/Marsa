from datetime import datetime, timezone
import uuid
import pytest
from httpx import AsyncClient

from app.models.clinical import Session
from app.models.patient import Patient, PatientSex
from app.models.staff import Staff


@pytest.fixture
async def sample_patient(db_session, doctor_user: Staff) -> Patient:
    """Create a sample patient in the database."""
    patient = Patient(
        patient_id=uuid.uuid4(),
        mrn="MRN-00001",
        name_ar="محمد إبراهيم",
        name_en="Mohamed Ibrahim",
        dob=None,
        sex=PatientSex.male,
        phone="01099998888",
        created_by=doctor_user.staff_id,
    )
    db_session.add(patient)
    await db_session.commit()
    await db_session.refresh(patient)
    return patient


@pytest.fixture
async def sample_session(db_session, sample_patient: Patient, doctor_user: Staff) -> Session:
    """Create a sample clinical session in the database."""
    sess = Session(
        session_id=uuid.uuid4(),
        patient_id=sample_patient.patient_id,
        started_at=datetime.now(timezone.utc),
        created_by=doctor_user.staff_id,
    )
    db_session.add(sess)
    await db_session.commit()
    await db_session.refresh(sess)
    return sess


@pytest.mark.asyncio
async def test_receptionist_cannot_access_full_patient_detail(
    client: AsyncClient,
    sample_patient: Patient,
    receptionist_headers: dict[str, str],
):
    """CRITICAL: Receptionist GET /patients/{id} must return HTTP 403 Forbidden."""
    res = await client.get(
        f"/patients/{sample_patient.patient_id}",
        headers=receptionist_headers,
    )
    assert res.status_code == 403
    assert "Access forbidden" in res.json()["detail"]


@pytest.mark.asyncio
async def test_receptionist_can_access_patient_summary_without_clinical_data(
    client: AsyncClient,
    sample_patient: Patient,
    receptionist_headers: dict[str, str],
):
    """Receptionist GET /patients/{id}/summary returns 200 with strictly non-clinical fields."""
    res = await client.get(
        f"/patients/{sample_patient.patient_id}/summary",
        headers=receptionist_headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["patient_id"] == str(sample_patient.patient_id)
    assert data["mrn"] == "MRN-00001"
    assert data["name_ar"] == "محمد إبراهيم"
    # Ensure clinical fields are NOT present
    assert "clinical_record" not in data
    assert "diagnoses" not in data
    assert "medications" not in data
    assert "medical_history" not in data


@pytest.mark.asyncio
async def test_receptionist_cannot_create_session_note(
    client: AsyncClient,
    sample_session: Session,
    receptionist_headers: dict[str, str],
):
    """CRITICAL: Receptionist cannot create a clinical session note (returns 403 Forbidden)."""
    payload = {
        "note_type": "typed",
        "content_typed": "Patient reported feelings of anxiety during evaluation.",
        "is_draft": True,
    }
    res = await client.post(
        f"/clinical/sessions/{sample_session.session_id}/notes",
        json=payload,
        headers=receptionist_headers,
    )
    assert res.status_code == 403
    assert "Access forbidden" in res.json()["detail"]


@pytest.mark.asyncio
async def test_doctor_can_access_all_endpoints(
    client: AsyncClient,
    sample_patient: Patient,
    sample_session: Session,
    doctor_headers: dict[str, str],
):
    """Doctor has authorized access to full patient details and session notes."""
    # 1. Doctor reads full patient record
    detail_res = await client.get(
        f"/patients/{sample_patient.patient_id}",
        headers=doctor_headers,
    )
    assert detail_res.status_code == 200
    assert detail_res.json()["patient_id"] == str(sample_patient.patient_id)

    # 2. Doctor creates session note
    note_payload = {
        "note_type": "typed",
        "content_typed": "Doctor clinical evaluation notes.",
        "is_draft": True,
    }
    note_res = await client.post(
        f"/clinical/sessions/{sample_session.session_id}/notes",
        json=note_payload,
        headers=doctor_headers,
    )
    assert note_res.status_code == 201
    assert note_res.json()["content_typed"] == "Doctor clinical evaluation notes."


@pytest.mark.asyncio
async def test_public_unauthenticated_cannot_access_staff_endpoints(
    client: AsyncClient,
    sample_patient: Patient,
):
    """Unauthenticated requests without token cannot access staff-protected endpoints (returns 401)."""
    endpoints = [
        ("GET", "/auth/me"),
        ("GET", "/patients"),
        ("GET", f"/patients/{sample_patient.patient_id}"),
        ("GET", f"/patients/{sample_patient.patient_id}/summary"),
        ("GET", "/appointments"),
        ("GET", "/appointments/booking-requests"),
    ]
    for method, path in endpoints:
        res = await client.request(method, path)
        assert res.status_code == 401, f"Expected 401 for {method} {path}, got {res.status_code}"
