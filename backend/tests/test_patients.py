import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_create_patient_doctor(client: AsyncClient, doctor_headers: dict[str, str]):
    """Doctor can create a patient with demographic information."""
    payload = {
        "name_ar": "طارق محمود عبد الله",
        "name_en": "Tarek Mahmoud Abdullah",
        "dob": "1990-05-15",
        "sex": "male",
        "national_id": "29005151234567",
        "phone": "01001234567",
        "email": "tarek@example.com",
        "address": "القاهرة، المعادي",
    }
    response = await client.post("/patients", json=payload, headers=doctor_headers)
    assert response.status_code == 201
    data = response.json()
    assert "patient" in data
    assert data["patient"]["name_ar"] == "طارق محمود عبد الله"
    assert data["patient"]["mrn"].startswith("MRN-")
    assert len(data["warnings"]) == 0
    assert len(data["possible_duplicates"]) == 0


@pytest.mark.asyncio
async def test_create_patient_receptionist(client: AsyncClient, receptionist_headers: dict[str, str]):
    """Receptionist can create a patient with basic demographic data."""
    payload = {
        "name_ar": "فاطمة حسن علي",
        "name_en": "Fatma Hassan Ali",
        "dob": "1995-10-20",
        "sex": "female",
        "phone": "01209876543",
        "email": "fatma@example.com",
    }
    response = await client.post("/patients", json=payload, headers=receptionist_headers)
    assert response.status_code == 201
    data = response.json()
    assert data["patient"]["name_ar"] == "فاطمة حسن علي"
    assert data["patient"]["mrn"].startswith("MRN-")


@pytest.mark.asyncio
async def test_duplicate_detection_warning(client: AsyncClient, receptionist_headers: dict[str, str]):
    """Duplicate detection flags potential matches by phone or Arabic name without hard blocking."""
    # 1. Create first patient
    first_payload = {
        "name_ar": "كريم سامي رضوان",
        "phone": "01122334455",
    }
    res1 = await client.post("/patients", json=first_payload, headers=receptionist_headers)
    assert res1.status_code == 201

    # 2. Create second patient with same phone number
    second_payload = {
        "name_ar": "كريم رضوان",
        "phone": "01122334455",
    }
    res2 = await client.post("/patients", json=second_payload, headers=receptionist_headers)
    assert res2.status_code == 201
    data2 = res2.json()
    assert len(data2["warnings"]) > 0
    assert "matching phone or Arabic name" in data2["warnings"][0]
    assert len(data2["possible_duplicates"]) >= 1
    assert data2["possible_duplicates"][0]["name_ar"] == "كريم سامي رضوان"


@pytest.mark.asyncio
async def test_mrn_auto_generation_format(client: AsyncClient, doctor_headers: dict[str, str]):
    """MRN is generated sequentially in MRN-00001 format."""
    p1 = await client.post(
        "/patients",
        json={"name_ar": "المريض الأول", "phone": "01000000001"},
        headers=doctor_headers,
    )
    p2 = await client.post(
        "/patients",
        json={"name_ar": "المريض الثاني", "phone": "01000000002"},
        headers=doctor_headers,
    )
    assert p1.status_code == 201
    assert p2.status_code == 201

    mrn1 = p1.json()["patient"]["mrn"]
    mrn2 = p2.json()["patient"]["mrn"]
    assert mrn1.startswith("MRN-")
    assert mrn2.startswith("MRN-")
    # Verify 5-digit padding format
    assert len(mrn1.split("-")[1]) == 5
    assert len(mrn2.split("-")[1]) == 5
    assert int(mrn2.split("-")[1]) > int(mrn1.split("-")[1])


@pytest.mark.asyncio
async def test_soft_delete(client: AsyncClient, doctor_headers: dict[str, str]):
    """Soft-deleted patients are hidden from standard listings and detail queries."""
    # 1. Create patient
    create_res = await client.post(
        "/patients",
        json={"name_ar": "مريض للحذف", "phone": "01055556666"},
        headers=doctor_headers,
    )
    patient_id = create_res.json()["patient"]["patient_id"]

    # 2. Soft delete patient
    del_res = await client.delete(f"/patients/{patient_id}", headers=doctor_headers)
    assert del_res.status_code == 200

    # 3. Reading deleted patient detail returns 404
    detail_res = await client.get(f"/patients/{patient_id}", headers=doctor_headers)
    assert detail_res.status_code == 404

    # 4. Search query omits deleted patient
    search_res = await client.get("/patients?q=للحذف", headers=doctor_headers)
    assert search_res.status_code == 200
    assert len(search_res.json()) == 0


@pytest.mark.asyncio
async def test_search_returns_role_appropriate_fields(
    client: AsyncClient,
    doctor_headers: dict[str, str],
    receptionist_headers: dict[str, str],
):
    """Search results filter fields based on user role (doctor gets full, receptionist gets contact info)."""
    # 1. Create a patient
    create_res = await client.post(
        "/patients",
        json={
            "name_ar": "عمر خالد الشامي",
            "name_en": "Omar Khaled El-Shamy",
            "dob": "1988-12-01",
            "phone": "01077778888",
            "email": "omar@example.com",
            "address": "مدينة نصر",
        },
        headers=doctor_headers,
    )
    assert create_res.status_code == 201

    # 2. Doctor searches: receives complete schema including diagnoses and clinical records
    doc_search = await client.get("/patients?q=عمر", headers=doctor_headers)
    assert doc_search.status_code == 200
    doc_data = doc_search.json()
    assert len(doc_data) >= 1
    doc_item = doc_data[0]
    assert "diagnoses" in doc_item
    assert "medications" in doc_item
    assert "clinical_record" in doc_item
    assert doc_item["address"] == "مدينة نصر"

    # 3. Receptionist searches: receives strictly non-clinical fields (id, mrn, names, phone, email)
    rec_search = await client.get("/patients?q=عمر", headers=receptionist_headers)
    assert rec_search.status_code == 200
    rec_data = rec_search.json()
    assert len(rec_data) >= 1
    rec_item = rec_data[0]
    assert "patient_id" in rec_item
    assert "mrn" in rec_item
    assert "name_ar" in rec_item
    assert "phone" in rec_item
    assert "email" in rec_item
    # Sensitive or clinical fields MUST NOT be present
    assert "diagnoses" not in rec_item
    assert "medications" not in rec_item
    assert "clinical_record" not in rec_item
    assert "medical_history" not in rec_item
    assert "address" not in rec_item
