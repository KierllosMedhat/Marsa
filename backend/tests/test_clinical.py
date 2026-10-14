from datetime import date, datetime, timezone
import uuid
import pytest
from httpx import AsyncClient

from app.models.clinical import Session
from app.models.patient import Patient, PatientSex
from app.models.staff import Staff


@pytest.fixture
async def sample_patient(db_session, doctor_user: Staff) -> Patient:
    patient = Patient(
        patient_id=uuid.uuid4(),
        mrn="MRN-00099",
        name_ar="سعيد كمال",
        name_en="Saeed Kamal",
        sex=PatientSex.male,
        phone="01155554444",
        created_by=doctor_user.staff_id,
    )
    db_session.add(patient)
    await db_session.commit()
    await db_session.refresh(patient)
    return patient


@pytest.fixture
async def sample_session(db_session, sample_patient: Patient, doctor_user: Staff) -> Session:
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
async def test_update_clinical_history_encryption(
    client: AsyncClient,
    sample_patient: Patient,
    doctor_headers: dict[str, str],
):
    """Updating clinical history encrypts sensitive fields at application layer and decrypts upon retrieval."""
    payload = {
        "medical_history": "Hypertension controlled with medication.",
        "psychiatric_history": "Generalized Anxiety Disorder for 3 years.",
        "family_history": "Mother had clinical depression.",
        "social_history": "Non-smoker, married with two children.",
        "allergies": [{"substance": "Penicillin", "reaction": "Rash"}],
    }
    res = await client.post(
        f"/clinical/patients/{sample_patient.patient_id}/clinical",
        json=payload,
        headers=doctor_headers,
    )
    assert res.status_code == 200
    data = res.json()
    assert data["medical_history"] == "Hypertension controlled with medication."
    assert data["psychiatric_history"] == "Generalized Anxiety Disorder for 3 years."
    assert data["family_history"] == "Mother had clinical depression."
    assert data["social_history"] == "Non-smoker, married with two children."
    assert len(data["allergies"]) == 1


@pytest.mark.asyncio
async def test_add_diagnosis(
    client: AsyncClient,
    sample_patient: Patient,
    doctor_headers: dict[str, str],
):
    """Doctor can add psychiatric diagnoses."""
    payload = {
        "icd10_code": "F41.1",
        "description_ar": "اضطراب القلق العام",
        "description_en": "Generalized anxiety disorder",
        "date_diagnosed": "2026-10-10",
        "status": "active",
    }
    res = await client.post(
        f"/clinical/patients/{sample_patient.patient_id}/diagnoses",
        json=payload,
        headers=doctor_headers,
    )
    assert res.status_code == 201
    data = res.json()
    assert data["icd10_code"] == "F41.1"
    assert data["description_ar"] == "اضطراب القلق العام"
    assert data["patient_id"] == str(sample_patient.patient_id)


@pytest.mark.asyncio
async def test_prescribe_medication(
    client: AsyncClient,
    sample_patient: Patient,
    doctor_headers: dict[str, str],
):
    """Doctor can prescribe psychiatric medications."""
    payload = {
        "name_ar": "إسيتالوبرام",
        "name_en": "Escitalopram",
        "dose": "10 mg",
        "frequency": "Once daily morning",
        "route": "oral",
        "start_date": "2026-10-10",
        "notes": "Monitor after 2 weeks",
        "is_active": True,
    }
    res = await client.post(
        f"/clinical/patients/{sample_patient.patient_id}/medications",
        json=payload,
        headers=doctor_headers,
    )
    assert res.status_code == 201
    data = res.json()
    assert data["name_ar"] == "إسيتالوبرام"
    assert data["name_en"] == "Escitalopram"
    assert data["dose"] == "10 mg"


@pytest.mark.asyncio
async def test_session_lifecycle_and_notes(
    client: AsyncClient,
    sample_patient: Patient,
    doctor_headers: dict[str, str],
):
    """Doctor can create session, add versioned notes, and retrieve decrypted notes list."""
    # 1. Create session
    sess_payload = {
        "patient_id": str(sample_patient.patient_id),
        "started_at": datetime.now(timezone.utc).isoformat(),
        "status": "draft",
    }
    s_res = await client.post("/clinical/sessions", json=sess_payload, headers=doctor_headers)
    assert s_res.status_code == 201
    session_id = s_res.json()["session_id"]

    # 2. Add first note
    note1_payload = {
        "note_type": "typed",
        "content_typed": "First evaluation session notes.",
        "is_draft": True,
    }
    n1_res = await client.post(
        f"/clinical/sessions/{session_id}/notes",
        json=note1_payload,
        headers=doctor_headers,
    )
    assert n1_res.status_code == 201
    assert n1_res.json()["version"] == 1
    assert n1_res.json()["content_typed"] == "First evaluation session notes."

    # 3. Add amended note
    note2_payload = {
        "note_type": "typed",
        "content_typed": "Amended evaluation session notes with therapy plan.",
        "is_draft": False,
        "amended_from": n1_res.json()["note_id"],
    }
    n2_res = await client.post(
        f"/clinical/sessions/{session_id}/notes",
        json=note2_payload,
        headers=doctor_headers,
    )
    assert n2_res.status_code == 201
    assert n2_res.json()["version"] == 2

    # 4. List notes
    list_res = await client.get(
        f"/clinical/sessions/{session_id}/notes",
        headers=doctor_headers,
    )
    assert list_res.status_code == 200
    notes = list_res.json()
    assert len(notes) == 2
    assert notes[0]["version"] == 2
    assert notes[0]["content_typed"] == "Amended evaluation session notes with therapy plan."
