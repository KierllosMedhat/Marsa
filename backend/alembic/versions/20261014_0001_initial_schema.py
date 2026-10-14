"""Initial schema for Marsa psychiatric clinic management system.

Revision ID: 20261014_0001
Revises: 
Create Date: 2026-10-14 13:00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "20261014_0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. staff table
    op.create_table(
        "staff",
        sa.Column("staff_id", sa.Uuid(), nullable=False),
        sa.Column("role", sa.String(length=32), nullable=False),
        sa.Column("name_ar", sa.String(length=255), nullable=False, comment="Arabic full name"),
        sa.Column("name_en", sa.String(length=255), nullable=True, comment="English full name"),
        sa.Column("email", sa.String(length=255), nullable=False),
        sa.Column("phone", sa.String(length=50), nullable=True),
        sa.Column("password_hash", sa.String(length=255), nullable=False, comment="Argon2id password hash"),
        sa.Column("mfa_secret", sa.String(length=255), nullable=True, comment="TOTP MFA secret"),
        sa.Column("mfa_enabled", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("staff_id"),
    )
    op.create_index(op.f("ix_staff_email"), "staff", ["email"], unique=True)
    op.create_index(op.f("ix_staff_role"), "staff", ["role"], unique=False)

    # 2. appointment_types table
    op.create_table(
        "appointment_types",
        sa.Column("type_id", sa.Uuid(), nullable=False),
        sa.Column("name_ar", sa.String(length=255), nullable=False),
        sa.Column("name_en", sa.String(length=255), nullable=True),
        sa.Column("duration_minutes", sa.Integer(), nullable=False),
        sa.Column("price_egp", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.PrimaryKeyConstraint("type_id"),
    )

    # 3. patients table
    op.create_table(
        "patients",
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("mrn", sa.String(length=50), nullable=False, comment="Medical Record Number"),
        sa.Column("name_ar", sa.String(length=255), nullable=False),
        sa.Column("name_en", sa.String(length=255), nullable=True),
        sa.Column("dob", sa.Date(), nullable=True),
        sa.Column("sex", sa.String(length=32), nullable=False),
        sa.Column("national_id", sa.Text(), nullable=True, comment="Encrypted National ID (AES-256-GCM)"),
        sa.Column("phone", sa.String(length=50), nullable=True),
        sa.Column("email", sa.String(length=255), nullable=True),
        sa.Column("address", sa.Text(), nullable=True),
        sa.Column("emergency_contact", sa.JSON().with_variant(postgresql.JSONB(astext_type=sa.Text()), "postgresql"), nullable=True),
        sa.Column("created_by", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["created_by"], ["staff.staff_id"]),
        sa.PrimaryKeyConstraint("patient_id"),
    )
    op.create_index(op.f("ix_patients_mrn"), "patients", ["mrn"], unique=True)
    op.create_index(op.f("ix_patients_name_ar"), "patients", ["name_ar"], unique=False)
    op.create_index(op.f("ix_patients_name_en"), "patients", ["name_en"], unique=False)
    op.create_index(op.f("ix_patients_phone"), "patients", ["phone"], unique=False)

    # 4. booking_requests table
    op.create_table(
        "booking_requests",
        sa.Column("request_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("phone", sa.String(length=50), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=True),
        sa.Column("type_id", sa.Uuid(), nullable=False),
        sa.Column("preferred_slot", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("matching_patient_id", sa.Uuid(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["matching_patient_id"], ["patients.patient_id"]),
        sa.ForeignKeyConstraint(["type_id"], ["appointment_types.type_id"]),
        sa.PrimaryKeyConstraint("request_id"),
    )
    op.create_index(op.f("ix_booking_requests_phone"), "booking_requests", ["phone"], unique=False)
    op.create_index(op.f("ix_booking_requests_status"), "booking_requests", ["status"], unique=False)

    # 5. appointments table
    op.create_table(
        "appointments",
        sa.Column("appointment_id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=True),
        sa.Column("booking_request_id", sa.Uuid(), nullable=True),
        sa.Column("type_id", sa.Uuid(), nullable=False),
        sa.Column("slot_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("slot_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("hold_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("hold_session_key", sa.String(length=255), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["booking_request_id"], ["booking_requests.request_id"]),
        sa.ForeignKeyConstraint(["patient_id"], ["patients.patient_id"]),
        sa.ForeignKeyConstraint(["type_id"], ["appointment_types.type_id"]),
        sa.PrimaryKeyConstraint("appointment_id"),
    )
    op.create_index(op.f("ix_appointments_patient_id"), "appointments", ["patient_id"], unique=False)
    op.create_index(op.f("ix_appointments_slot_start"), "appointments", ["slot_start"], unique=False)
    op.create_index(op.f("ix_appointments_status"), "appointments", ["status"], unique=False)

    # 6. patient_clinical table
    op.create_table(
        "patient_clinical",
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("medical_history", sa.Text(), nullable=True, comment="Encrypted medical history"),
        sa.Column("psychiatric_history", sa.Text(), nullable=True, comment="Encrypted psychiatric history"),
        sa.Column("family_history", sa.Text(), nullable=True, comment="Encrypted family history"),
        sa.Column("social_history", sa.Text(), nullable=True, comment="Encrypted social history"),
        sa.Column("allergies", sa.JSON().with_variant(postgresql.JSONB(astext_type=sa.Text()), "postgresql"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_by", sa.Uuid(), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patients.patient_id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["updated_by"], ["staff.staff_id"]),
        sa.PrimaryKeyConstraint("patient_id"),
    )

    # 7. diagnoses table
    op.create_table(
        "diagnoses",
        sa.Column("diagnosis_id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("icd10_code", sa.String(length=20), nullable=True),
        sa.Column("description_ar", sa.Text(), nullable=False),
        sa.Column("description_en", sa.Text(), nullable=True),
        sa.Column("date_diagnosed", sa.Date(), nullable=False),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("author_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("finalized_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["author_id"], ["staff.staff_id"]),
        sa.ForeignKeyConstraint(["patient_id"], ["patients.patient_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("diagnosis_id"),
    )
    op.create_index(op.f("ix_diagnoses_patient_id"), "diagnoses", ["patient_id"], unique=False)

    # 8. medications table
    op.create_table(
        "medications",
        sa.Column("medication_id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("name_ar", sa.String(length=255), nullable=False),
        sa.Column("name_en", sa.String(length=255), nullable=True),
        sa.Column("dose", sa.String(length=100), nullable=True),
        sa.Column("frequency", sa.String(length=100), nullable=True),
        sa.Column("route", sa.String(length=100), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=True),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("prescribed_by", sa.Uuid(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["patient_id"], ["patients.patient_id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["prescribed_by"], ["staff.staff_id"]),
        sa.PrimaryKeyConstraint("medication_id"),
    )
    op.create_index(op.f("ix_medications_patient_id"), "medications", ["patient_id"], unique=False)

    # 9. sessions table
    op.create_table(
        "sessions",
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("patient_id", sa.Uuid(), nullable=False),
        sa.Column("appointment_id", sa.Uuid(), nullable=True),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("created_by", sa.Uuid(), nullable=False),
        sa.Column("finalized_by", sa.Uuid(), nullable=True),
        sa.Column("finalized_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["appointment_id"], ["appointments.appointment_id"]),
        sa.ForeignKeyConstraint(["created_by"], ["staff.staff_id"]),
        sa.ForeignKeyConstraint(["finalized_by"], ["staff.staff_id"]),
        sa.ForeignKeyConstraint(["patient_id"], ["patients.patient_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("session_id"),
    )
    op.create_index(op.f("ix_sessions_patient_id"), "sessions", ["patient_id"], unique=False)
    op.create_index(op.f("ix_sessions_appointment_id"), "sessions", ["appointment_id"], unique=False)

    # 10. session_notes table
    op.create_table(
        "session_notes",
        sa.Column("note_id", sa.Uuid(), nullable=False),
        sa.Column("session_id", sa.Uuid(), nullable=False),
        sa.Column("note_type", sa.String(length=32), nullable=False),
        sa.Column("content_typed", sa.Text(), nullable=True, comment="Encrypted typed note content"),
        sa.Column("content_ink_ref", sa.String(length=500), nullable=True),
        sa.Column("version", sa.Integer(), nullable=False, server_default=sa.text("1")),
        sa.Column("is_draft", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("amended_from", sa.Uuid(), nullable=True),
        sa.Column("edited_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("edited_by", sa.Uuid(), nullable=False),
        sa.ForeignKeyConstraint(["amended_from"], ["session_notes.note_id"]),
        sa.ForeignKeyConstraint(["edited_by"], ["staff.staff_id"]),
        sa.ForeignKeyConstraint(["session_id"], ["sessions.session_id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("note_id"),
    )
    op.create_index(op.f("ix_session_notes_session_id"), "session_notes", ["session_id"], unique=False)

    # 11. payments table
    op.create_table(
        "payments",
        sa.Column("payment_id", sa.Uuid(), nullable=False),
        sa.Column("appointment_id", sa.Uuid(), nullable=False),
        sa.Column("amount_egp", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("currency", sa.String(length=10), nullable=False, server_default="EGP"),
        sa.Column("method", sa.String(length=32), nullable=False),
        sa.Column("gateway_ref", sa.String(length=255), nullable=True),
        sa.Column("idempotency_key", sa.String(length=255), nullable=True),
        sa.Column("status", sa.String(length=32), nullable=False),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("gateway_response", sa.JSON().with_variant(postgresql.JSONB(astext_type=sa.Text()), "postgresql"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["appointment_id"], ["appointments.appointment_id"]),
        sa.PrimaryKeyConstraint("payment_id"),
    )
    op.create_index(op.f("ix_payments_appointment_id"), "payments", ["appointment_id"], unique=False)
    op.create_index(op.f("ix_payments_idempotency_key"), "payments", ["idempotency_key"], unique=True)
    op.create_index(op.f("ix_payments_status"), "payments", ["status"], unique=False)

    # 12. audit_log table
    op.create_table(
        "audit_log",
        sa.Column("log_id", sa.Uuid(), nullable=False),
        sa.Column("staff_id", sa.Uuid(), nullable=True),
        sa.Column("action", sa.String(length=100), nullable=False),
        sa.Column("resource_type", sa.String(length=100), nullable=False),
        sa.Column("resource_id", sa.Uuid(), nullable=True),
        sa.Column("ip_address", sa.String(length=50), nullable=True),
        sa.Column("user_agent", sa.Text(), nullable=True),
        sa.Column("timestamp", sa.DateTime(timezone=True), nullable=False),
        sa.Column("details", sa.JSON().with_variant(postgresql.JSONB(astext_type=sa.Text()), "postgresql"), nullable=True),
        sa.ForeignKeyConstraint(["staff_id"], ["staff.staff_id"]),
        sa.PrimaryKeyConstraint("log_id"),
    )
    op.create_index(op.f("ix_audit_log_action"), "audit_log", ["action"], unique=False)
    op.create_index(op.f("ix_audit_log_resource_type"), "audit_log", ["resource_type"], unique=False)
    op.create_index(op.f("ix_audit_log_resource_id"), "audit_log", ["resource_id"], unique=False)
    op.create_index(op.f("ix_audit_log_staff_id"), "audit_log", ["staff_id"], unique=False)
    op.create_index(op.f("ix_audit_log_timestamp"), "audit_log", ["timestamp"], unique=False)


def downgrade() -> None:
    op.drop_table("audit_log")
    op.drop_table("payments")
    op.drop_table("session_notes")
    op.drop_table("sessions")
    op.drop_table("medications")
    op.drop_table("diagnoses")
    op.drop_table("patient_clinical")
    op.drop_table("appointments")
    op.drop_table("booking_requests")
    op.drop_table("patients")
    op.drop_table("appointment_types")
    op.drop_table("staff")
