from datetime import datetime, timedelta, timezone
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_appointment_types_flow(
    client: AsyncClient,
    doctor_headers: dict[str, str],
):
    """Create and list appointment types."""
    payload = {
        "name_ar": "جلسة علاج نفسي أولية",
        "name_en": "Initial Psychiatric Evaluation",
        "duration_minutes": 60,
        "price_egp": 800.0,
        "is_active": True,
    }
    create_res = await client.post("/appointments/types", json=payload, headers=doctor_headers)
    assert create_res.status_code == 201
    type_id = create_res.json()["type_id"]

    list_res = await client.get("/appointments/types")
    assert list_res.status_code == 200
    types = list_res.json()
    assert any(t["type_id"] == type_id for t in types)


@pytest.mark.asyncio
async def test_public_booking_request_flow(
    client: AsyncClient,
    doctor_headers: dict[str, str],
):
    """Prospective patient submits public booking request, staff reviews requests."""
    # 1. Setup appointment type
    t_res = await client.post(
        "/appointments/types",
        json={
            "name_ar": "استشارة متابعة",
            "name_en": "Follow-up Consultation",
            "duration_minutes": 30,
            "price_egp": 500.0,
        },
        headers=doctor_headers,
    )
    type_id = t_res.json()["type_id"]

    # 2. Public submission (NO token required)
    booking_payload = {
        "name": "يوسف مصطفى",
        "phone": "01099887766",
        "email": "youssef@example.com",
        "type_id": type_id,
        "preferred_slot": (datetime.now(timezone.utc) + timedelta(days=2)).isoformat(),
        "notes": "يفضل الموعد بعد الساعة 5 مساء",
    }
    book_res = await client.post("/appointments/booking-requests", json=booking_payload)
    assert book_res.status_code == 201
    assert book_res.json()["status"] == "pending_match"

    # 3. Staff lists requests
    staff_list_res = await client.get("/appointments/booking-requests", headers=doctor_headers)
    assert staff_list_res.status_code == 200
    requests = staff_list_res.json()
    assert any(r["name"] == "يوسف مصطفى" for r in requests)
