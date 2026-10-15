import enum
import uuid
from datetime import date as DateType, datetime
from sqlalchemy import Boolean, Date, DateTime, Enum, ForeignKey, Integer, String, Text, Uuid, JSON
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base, utcnow


class DiagnosisStatus(str, enum.Enum):
    active = "active"
    resolved = "resolved"
    in_remission = "in_remission"


class SessionStatus(str, enum.Enum):
    draft = "draft"
    finalized = "finalized"


class NoteType(str, enum.Enum):
    typed = "typed"
    handwritten = "handwritten"
    mixed = "mixed"


class PatientClinical(Base):
    """Sensitive clinical background data for a patient, strictly separated from demographics."""

    __tablename__ = "patient_clinical"

    patient_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("patients.patient_id", ondelete="CASCADE"),
        primary_key=True,
    )
    # Encrypted fields using AES-256-GCM
    medical_history: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted medical history / التاريخ الطبي مشفر",
    )
    psychiatric_history: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted psychiatric history / التاريخ النفسي مشفر",
    )
    family_history: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted family history / التاريخ المرضي العائلي مشفر",
    )
    social_history: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted social history / التاريخ الاجتماعي مشفر",
    )
    history: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted complete psychiatric history / التاريخ المرضي والنفسي الكامل مشفر",
    )
    psychiatric_examinations: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted psychiatric examinations / الفحوصات والتقييمات النفسية مشفر",
    )
    physical_neurological_exam: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted physical and neurological exam / الفحص الجسدي والعصبي مشفر",
    )
    risk_assessment: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted risk assessment / تقييم الخطورة مشفر",
    )
    suicide_attempts: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted suicide attempts history / محاولات الانتحار السابقة مشفر",
    )
    admitted_before: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted past hospital admissions / دخول مستشفى سابق مشفر",
    )
    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted general doctor notes / ملاحظات الطبيب العامة مشفر",
    )
    allergies: Mapped[list | dict | None] = mapped_column(
        JSON().with_variant(JSONB, "postgresql"),
        nullable=True,
        comment="Known allergies list / الحساسية المعروفة",
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
        nullable=False,
    )
    updated_by: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("staff.staff_id"),
        nullable=False,
    )

    # Relationships
    patient = relationship("Patient", back_populates="clinical_record")
    updater = relationship("Staff", foreign_keys=[updated_by])


class Diagnosis(Base):
    """Psychiatric and medical diagnoses assigned to a patient."""

    __tablename__ = "diagnoses"

    diagnosis_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("patients.patient_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    icd10_code: Mapped[str | None] = mapped_column(
        String(20),
        nullable=True,
        comment="ICD-10 classification code (e.g. F32.1) / رمز التصنيف الدولي للأمراض",
    )
    description_ar: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="Arabic diagnosis description / وصف التشخيص بالعربية",
    )
    description_en: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="English diagnosis description / وصف التشخيص بالإنجليزية",
    )
    date_diagnosed: Mapped[DateType] = mapped_column(
        Date,
        nullable=False,
        comment="Date diagnosis was made / تاريخ التشخيص",
    )
    status: Mapped[DiagnosisStatus] = mapped_column(
        Enum(DiagnosisStatus, name="diagnosis_status_enum", native_enum=False),
        nullable=False,
        default=DiagnosisStatus.active,
    )
    author_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("staff.staff_id"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )
    finalized_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # Relationships
    patient = relationship("Patient", back_populates="diagnoses")
    author = relationship("Staff", foreign_keys=[author_id])


class Medication(Base):
    """Psychiatric and medical prescriptions for a patient."""

    __tablename__ = "medications"

    medication_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("patients.patient_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    name_ar: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="Medication name in Arabic / اسم الدواء بالعربية",
    )
    name_en: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        comment="Medication trade or generic name in English / اسم الدواء بالإنجليزية",
    )
    dose: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="Dosage (e.g. 20mg) / الجرعة",
    )
    frequency: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="Frequency (e.g. once daily at bedtime) / التكرار ومواعيد التناول",
    )
    route: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="Route (e.g. oral) / طريقة التناول",
    )
    duration: Mapped[str | None] = mapped_column(
        String(100),
        nullable=True,
        comment="Treatment duration (e.g. 3 months) / مدة العلاج",
    )
    date: Mapped[DateType | None] = mapped_column(
        Date,
        nullable=True,
        comment="Prescription date / تاريخ الوصفة",
    )
    start_date: Mapped[DateType | None] = mapped_column(
        Date,
        nullable=True,
    )
    end_date: Mapped[DateType | None] = mapped_column(
        Date,
        nullable=True,
    )
    notes: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
    )
    prescribed_by: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("staff.staff_id"),
        nullable=False,
    )
    is_active: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )

    # Relationships
    patient = relationship("Patient", back_populates="medications")
    prescriber = relationship("Staff", foreign_keys=[prescribed_by])


class Session(Base):
    """Clinical therapy or consultation session linked to an appointment."""

    __tablename__ = "sessions"

    session_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("patients.patient_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    appointment_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("appointments.appointment_id"),
        nullable=True,
        index=True,
    )
    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    status: Mapped[SessionStatus] = mapped_column(
        Enum(SessionStatus, name="session_status_enum", native_enum=False),
        nullable=False,
        default=SessionStatus.draft,
    )
    session_number: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        comment="Session number or label / رقم الجلسة",
    )
    chief_complaint: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Chief complaint / الشكوى الرئيسية",
    )
    sleep: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Sleep patterns and quality / النوم",
    )
    appetite: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Appetite / الشهية",
    )
    mood: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Subjective and objective mood / المزاج",
    )
    anxiety: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Anxiety level and symptoms / القلق والتوتر",
    )
    suicidal_self_harm_assessment: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Suicidal and self-harm assessment / تقييم الانتحار وإيذاء النفس",
    )
    substance_use: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Substance and alcohol use history / تعاطي المواد المخدرة",
    )
    mental_status_examination: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Mental Status Examination (MSE) / فحص الحالة العقلية",
    )
    diagnosis: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Session provisional or confirmed diagnosis / تشخيص الجلسة",
    )
    treatment_plan: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Treatment and psychotherapy plan / الخطة العلاجية",
    )
    follow_up: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Follow-up interval and recommendations / توصيات المتابعة",
    )
    created_by: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("staff.staff_id"),
        nullable=False,
    )
    finalized_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("staff.staff_id"),
        nullable=True,
    )
    finalized_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )

    # Relationships
    patient = relationship("Patient", back_populates="sessions")
    appointment = relationship("Appointment", back_populates="session")
    notes = relationship(
        "SessionNote",
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="SessionNote.version.desc()",
    )
    creator = relationship("Staff", foreign_keys=[created_by])
    finalizer = relationship("Staff", foreign_keys=[finalized_by])


class SessionNote(Base):
    """Clinical session notes with versioning and encryption."""

    __tablename__ = "session_notes"

    note_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("sessions.session_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    note_type: Mapped[NoteType] = mapped_column(
        Enum(NoteType, name="note_type_enum", native_enum=False),
        nullable=False,
        default=NoteType.typed,
    )
    content_typed: Mapped[str | None] = mapped_column(
        Text,
        nullable=True,
        comment="Encrypted typed note content (AES-256-GCM) / ملاحظات الجلسة مشفرة",
    )
    content_ink_ref: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True,
        comment="File storage reference for handwritten strokes / مرجع ملف الخط اليدوي",
    )
    version: Mapped[int] = mapped_column(
        Integer,
        default=1,
        nullable=False,
    )
    is_draft: Mapped[bool] = mapped_column(
        Boolean,
        default=True,
        nullable=False,
    )
    amended_from: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("session_notes.note_id"),
        nullable=True,
        comment="Self-FK to previous version if this note is an amendment",
    )
    edited_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )
    edited_by: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("staff.staff_id"),
        nullable=False,
    )

    # Relationships
    session = relationship("Session", back_populates="notes")
    editor = relationship("Staff", foreign_keys=[edited_by])
    previous_note = relationship("SessionNote", remote_side=[note_id])


class PatientFile(Base):
    """Clinical files, scans, reports, labs for a patient."""

    __tablename__ = "patient_files"

    file_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("patients.patient_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    file_name: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
        comment="File name or report title / اسم الملف أو التقرير",
    )
    file_type: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        comment="File MIME or category (report, lab, scan) / نوع الملف",
    )
    file_location: Mapped[str] = mapped_column(
        String(500),
        nullable=False,
        comment="Storage path or URI / مسار الملف",
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        nullable=False,
    )
    uploaded_by: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("staff.staff_id"),
        nullable=True,
    )

    # Relationships
    patient = relationship("Patient", back_populates="files")
    uploader = relationship("Staff", foreign_keys=[uploaded_by])


class PatientNote(Base):
    """Doctor quick notes on patient profile."""

    __tablename__ = "patient_notes"

    note_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        primary_key=True,
        default=uuid.uuid4,
    )
    patient_id: Mapped[uuid.UUID] = mapped_column(
        Uuid,
        ForeignKey("patients.patient_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    note_text: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        comment="Note content / نص الملاحظة",
    )
    last_modified: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
        nullable=False,
    )
    author_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid,
        ForeignKey("staff.staff_id"),
        nullable=True,
    )

    # Relationships
    patient = relationship("Patient", back_populates="notes")
    author = relationship("Staff", foreign_keys=[author_id])
