import uuid
from datetime import datetime
from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models.staff import StaffRole


class StaffBase(BaseModel):
    name_ar: str = Field(..., description="Full Arabic Name")
    name_en: str | None = Field(default=None, description="Full English Name")
    email: EmailStr
    phone: str | None = None
    role: StaffRole = StaffRole.receptionist
    is_active: bool = True


class StaffCreate(StaffBase):
    password: str = Field(..., min_length=8, description="Plaintext password")


class StaffUpdate(BaseModel):
    name_ar: str | None = None
    name_en: str | None = None
    phone: str | None = None
    role: StaffRole | None = None
    is_active: bool | None = None
    password: str | None = Field(default=None, min_length=8)


class StaffResponse(BaseModel):
    staff_id: uuid.UUID
    role: StaffRole
    name_ar: str
    name_en: str | None = None
    email: EmailStr
    phone: str | None = None
    mfa_enabled: bool
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class LoginResponse(BaseModel):
    access_token: str | None = None
    refresh_token: str | None = None
    token_type: str = "bearer"
    requires_mfa: bool = False
    mfa_token: str | None = None


class MFASetupResponse(BaseModel):
    secret: str
    otpauth_url: str


class MFAVerifyRequest(BaseModel):
    mfa_token: str | None = None
    code: str = Field(..., min_length=6, max_length=6, description="6-digit TOTP code")


class TokenRefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
