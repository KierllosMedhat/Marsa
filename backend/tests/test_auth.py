from datetime import timedelta
import pytest
from httpx import AsyncClient
import pyotp

from app.models.staff import Staff
from app.services.auth_service import auth_service


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    """Health check returns status ok, db boolean, redis boolean, and timestamp."""
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] in ("ok", "degraded")
    assert "db" in data
    assert "redis" in data
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_login_valid_credentials(client: AsyncClient, doctor_user: Staff):
    """Login with correct credentials returns access and refresh tokens."""
    payload = {
        "email": "doctor@marsa.clinic",
        "password": "DoctorSecret123!",
    }
    response = await client.post("/auth/login", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"
    assert data["requires_mfa"] is False


@pytest.mark.asyncio
async def test_login_invalid_password(client: AsyncClient, doctor_user: Staff):
    """Login with wrong password returns HTTP 401."""
    payload = {
        "email": "doctor@marsa.clinic",
        "password": "WrongPassword!",
    }
    response = await client.post("/auth/login", json=payload)
    assert response.status_code == 401
    assert "Invalid email or password" in response.json()["detail"]


@pytest.mark.asyncio
async def test_login_nonexistent_email(client: AsyncClient):
    """Login with non-existent email returns HTTP 401."""
    payload = {
        "email": "nobody@marsa.clinic",
        "password": "SomePassword123!",
    }
    response = await client.post("/auth/login", json=payload)
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_access_protected_without_token(client: AsyncClient):
    """Accessing protected endpoint without Bearer token returns HTTP 401."""
    response = await client.get("/auth/me")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_expired_token_returns_401(client: AsyncClient, doctor_user: Staff):
    """Expired access token returns HTTP 401."""
    expired_token = auth_service.create_access_token(
        data={"sub": str(doctor_user.staff_id), "role": doctor_user.role.value, "email": doctor_user.email},
        expires_delta=timedelta(seconds=-10),  # expired in past
    )
    headers = {"Authorization": f"Bearer {expired_token}"}
    response = await client.get("/auth/me", headers=headers)
    assert response.status_code == 401
    assert "expired" in response.json()["detail"].lower()


@pytest.mark.asyncio
async def test_logout_invalidates_refresh_token(client: AsyncClient, doctor_user: Staff):
    """Logging out revokes the refresh token from Redis, preventing subsequent refreshes."""
    # 1. Login to get tokens
    login_res = await client.post(
        "/auth/login",
        json={"email": "doctor@marsa.clinic", "password": "DoctorSecret123!"},
    )
    assert login_res.status_code == 200
    refresh_token = login_res.json()["refresh_token"]

    # 2. Call logout
    logout_res = await client.post(
        "/auth/logout",
        json={"refresh_token": refresh_token},
    )
    assert logout_res.status_code == 200

    # 3. Attempting to refresh with the revoked token must fail with 401
    refresh_res = await client.post(
        "/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert refresh_res.status_code == 401


@pytest.mark.asyncio
async def test_mfa_flow(client: AsyncClient, doctor_user: Staff, doctor_headers: dict[str, str], db_session):
    """Test full MFA flow: setup MFA, login requires MFA, verify TOTP, obtain full tokens."""
    # 1. Doctor sets up MFA
    setup_res = await client.post("/auth/mfa/setup", headers=doctor_headers)
    assert setup_res.status_code == 200
    mfa_data = setup_res.json()
    secret = mfa_data["secret"]
    assert "otpauth_url" in mfa_data
    assert "secret" in mfa_data

    # 2. Doctor logs in: system indicates MFA is required
    login_res = await client.post(
        "/auth/login",
        json={"email": "doctor@marsa.clinic", "password": "DoctorSecret123!"},
    )
    assert login_res.status_code == 200
    login_body = login_res.json()
    assert login_body["requires_mfa"] is True
    assert login_body["mfa_token"] is not None
    assert login_body["access_token"] is None

    # 3. Verify with invalid TOTP code returns 401
    verify_bad = await client.post(
        "/auth/mfa/verify",
        json={"mfa_token": login_body["mfa_token"], "code": "000000"},
    )
    assert verify_bad.status_code == 401

    # 4. Verify with valid TOTP code returns access & refresh tokens
    totp = pyotp.TOTP(secret)
    valid_code = totp.now()

    verify_ok = await client.post(
        "/auth/mfa/verify",
        json={"mfa_token": login_body["mfa_token"], "code": valid_code},
    )
    assert verify_ok.status_code == 200
    tokens = verify_ok.json()
    assert "access_token" in tokens
    assert "refresh_token" in tokens
