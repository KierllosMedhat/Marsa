import enum
import uuid
from datetime import date, datetime
from sqlalchemy import Date, DateTime, Enum, ForeignKey, String, Text, Uuid, JSON
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, utcnow


class PatientSex(str, enum.Enum):
    male = "male"
    female = "female"
    other = "other"
    prefer_not_to_say = "prefer_not_to_say"


class Patient(Base):
    """Patient demographic and non-clinical record."""

    __tablename__ = "patients"

    patient_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    mrn: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        index=True,
        nullable=False,
        comment="Medical Record Number / رقم السجل الطبي (MRN-XXXXX)",
    )
    name_ar: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        index=True,
        comment="Patient full Arabic name / اسم المريض بالكامل بالعربية",
    )
    name_en: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        index=True,
        comment="Patient full English name / اسم المريض بالإنجليزية",
    )
    dob: Mapped[date | None] = mapped_column(
        Date,
        nullable=True,
        comment="Date of birth / تاريخ الميلاد",
    )
    sex: Mapped[PatientSex] = mapped_column(
        Enum(PatientSex, name="patient_sex_enum", native_enum=False),
        nullable=False,
        default=PatientSex.prefer_not_to_say,
    )
    national_id: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted National ID (AES-256-GCM) / الرقم القومي مشفر",
    )
    phone: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        index=True,
        comment="Primary contact phone / رقم الهاتف",
    )
    email: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Email address / البريد الإلكتروني",
    )
    address: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Physical address / العنوان",
    )
    emergency_contact: Mapped[dict | None] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"),
        nullable=True,
        comment="Emergency contact details (name, relation, phone) / بيانات جهة الاتصال للطوارئ",
    )
    created_by: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("staff.staff_id"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
        nullable=False,
    )
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Timestamp when soft deleted / وقت الحذف المنطقي",
    )

    # Relationships
    creator = relationship(
        "Staff",
        back_populates="created_patients",
        foreign_keys=[created_by],
    )
    clinical_record = relationship(
        "PatientClinical",
        back_populates="patient",
        uselist=False,
        cascade="all, delete-orphan",
    )
    diagnoses = relationship(
        "Diagnosis",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    medications = relationship(
        "Medication",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    sessions = relationship(
        "Session",
        back_populates="patient",
        cascade="all, delete-orphan",
    )
    appointments = relationship(
        "Appointment",
        back_populates="patient",
    )
