import os
import uuid
from typing import AsyncGenerator
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import StaticPool

from app.config import get_settings
from app.database import Base, get_db
from app.main import app
from app.models.staff import Staff, StaffRole
from app.redis_client import get_redis
from app.services.auth_service import auth_service
from app.utils.encryption import generate_rsa_key_pair

# Generate test RSA keys and AES key if not present in env
test_priv, test_pub = generate_rsa_key_pair()
os.environ.setdefault("JWT_PRIVATE_KEY", test_priv)
os.environ.setdefault("JWT_PUBLIC_KEY", test_pub)
os.environ.setdefault("ENCRYPTION_KEY", "ryb8iV8JcwcymGCsq2kRwOZvxzWXfAdfvJ1u4QrET+4=")

# Test database: use in-memory SQLite if TEST_DATABASE_URL not set
TEST_DATABASE_URL = os.getenv("TEST_DATABASE_URL", "sqlite+aiosqlite:///:memory:")

test_engine = create_async_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in TEST_DATABASE_URL else {},
    poolclass=StaticPool if "sqlite" in TEST_DATABASE_URL else None,
)

TestingSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class FakeRedis:
    """In-memory async Redis stand-in for tests."""

    def __init__(self):
        self._store: dict[str, str] = {}

    async def get(self, key: str) -> str | None:
        return self._store.get(key)

    async def set(self, key: str, value: str) -> bool:
        self._store[key] = str(value)
        return True

    async def setex(self, key: str, time: int, value: str) -> bool:
        self._store[key] = str(value)
        return True

    async def delete(self, *keys: str) -> int:
        count = 0
        for k in keys:
            if k in self._store:
                del self._store[k]
                count += 1
        return count

    async def ping(self) -> bool:
        return True

    async def aclose(self) -> None:
        pass


@pytest.fixture(scope="session")
def fake_redis_instance() -> FakeRedis:
    return FakeRedis()


@pytest.fixture(autouse=True)
async def setup_test_db():
    """Create all tables before each test and drop them after."""
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Yield a transactional test database session."""
    async with TestingSessionLocal() as session:
        yield session


@pytest.fixture
async def client(db_session: AsyncSession, fake_redis_instance: FakeRedis) -> AsyncGenerator[AsyncClient, None]:
    """Provide an AsyncClient wired with test database and fake Redis overrides."""
    async def override_get_db():
        yield db_session

    async def override_get_redis():
        yield fake_redis_instance

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_redis] = override_get_redis

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest.fixture
async def doctor_user(db_session: AsyncSession) -> Staff:
    """Create and return a doctor staff user."""
    doctor = Staff(
        staff_id=uuid.uuid4(),
        role=StaffRole.doctor,
        name_ar="د. أحمد محمود",
        name_en="Dr. Ahmed Mahmoud",
        email="doctor@marsa.clinic",
        phone="01011112222",
        password_hash=auth_service.hash_password("DoctorSecret123!"),
        is_active=True,
    )
    db_session.add(doctor)
    await db_session.commit()
    await db_session.refresh(doctor)
    return doctor


@pytest.fixture
async def receptionist_user(db_session: AsyncSession) -> Staff:
    """Create and return a receptionist staff user."""
    receptionist = Staff(
        staff_id=uuid.uuid4(),
        role=StaffRole.receptionist,
        name_ar="سارة علي",
        name_en="Sara Ali",
        email="receptionist@marsa.clinic",
        phone="01033334444",
        password_hash=auth_service.hash_password("ReceptionSecret123!"),
        is_active=True,
    )
    db_session.add(receptionist)
    await db_session.commit()
    await db_session.refresh(receptionist)
    return receptionist


@pytest.fixture
def doctor_token(doctor_user: Staff) -> str:
    """Generate a valid JWT access token for the doctor user."""
    return auth_service.create_access_token({
        "sub": str(doctor_user.staff_id),
        "role": doctor_user.role.value,
        "email": doctor_user.email,
    })


@pytest.fixture
def receptionist_token(receptionist_user: Staff) -> str:
    """Generate a valid JWT access token for the receptionist user."""
    return auth_service.create_access_token({
        "sub": str(receptionist_user.staff_id),
        "role": receptionist_user.role.value,
        "email": receptionist_user.email,
    })


@pytest.fixture
def doctor_headers(doctor_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {doctor_token}"}


@pytest.fixture
def receptionist_headers(receptionist_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {receptionist_token}"}
