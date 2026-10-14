import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_staff, require_role
from app.models.appointment import Appointment, AppointmentStatus, AppointmentType
from app.models.booking import BookingRequest, BookingStatus
from app.models.staff import Staff, StaffRole
from app.schemas.appointment import (
    AppointmentCreate,
    AppointmentResponse,
    AppointmentStatusUpdate,
    AppointmentTypeCreate,
    AppointmentTypeResponse,
    BookingMatchRequest,
    BookingRequestCreate,
    BookingRequestResponse,
)

router = APIRouter(prefix="/appointments", tags=["Appointments & Bookings"])


@router.get("/types", response_model=list[AppointmentTypeResponse])
async def list_appointment_types(
    db: AsyncSession = Depends(get_db),
):
    """List available active appointment types (public / staff)."""
    result = await db.execute(
        select(AppointmentType).where(AppointmentType.is_active.is_(True))
    )
    return result.scalars().all()


@router.post("/types", response_model=AppointmentTypeResponse, status_code=status.HTTP_201_CREATED)
async def create_appointment_type(
    payload: AppointmentTypeCreate,
    current_staff: Staff = Depends(require_role(StaffRole.admin, StaffRole.doctor)),
    db: AsyncSession = Depends(get_db),
):
    """Create a new appointment type (admin/doctor)."""
    appt_type = AppointmentType(
        name_ar=payload.name_ar,
        name_en=payload.name_en,
        duration_minutes=payload.duration_minutes,
        price_egp=payload.price_egp,
        is_active=payload.is_active,
    )
    db.add(appt_type)
    await db.commit()
    await db.refresh(appt_type)
    return appt_type


@router.get("", response_model=list[AppointmentResponse])
async def list_appointments(
    current_staff: Staff = Depends(get_current_staff),
    db: AsyncSession = Depends(get_db),
):
    """List scheduled appointments (accessible by all authenticated staff)."""
    result = await db.execute(
        select(Appointment).order_by(Appointment.slot_start.desc())
    )
    return result.scalars().all()


@router.post("", response_model=AppointmentResponse, status_code=status.HTTP_201_CREATED)
async def create_appointment(
    payload: AppointmentCreate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.receptionist, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Schedule a new appointment slot."""
    type_obj = await db.get(AppointmentType, payload.type_id)
    if not type_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Appointment type not found",
        )

    appt = Appointment(
        patient_id=payload.patient_id,
        booking_request_id=payload.booking_request_id,
        type_id=payload.type_id,
        slot_start=payload.slot_start,
        slot_end=payload.slot_end,
        status=AppointmentStatus.confirmed if payload.patient_id else AppointmentStatus.available,
        notes=payload.notes,
    )
    db.add(appt)
    await db.commit()
    await db.refresh(appt)
    return appt


@router.post(
    "/booking-requests",
    response_model=BookingRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_booking_request(
    payload: BookingRequestCreate,
    db: AsyncSession = Depends(get_db),
):
    """Public booking endpoint (strictly non-clinical) where prospective patients request appointments."""
    type_obj = await db.get(AppointmentType, payload.type_id)
    if not type_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Requested appointment type not found",
        )

    req = BookingRequest(
        name=payload.name,
        phone=payload.phone,
        email=payload.email,
        type_id=payload.type_id,
        preferred_slot=payload.preferred_slot,
        notes=payload.notes,
        status=BookingStatus.pending_match,
    )
    db.add(req)
    await db.commit()
    await db.refresh(req)
    return req


@router.get(
    "/booking-requests",
    response_model=list[BookingRequestResponse],
)
async def list_booking_requests(
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.receptionist, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """List pending public booking requests for staff triage."""
    result = await db.execute(
        select(BookingRequest).order_by(BookingRequest.created_at.desc())
    )
    return result.scalars().all()


@router.patch("/{appointment_id}/status", response_model=AppointmentResponse)
async def update_appointment_status(
    appointment_id: uuid.UUID,
    payload: AppointmentStatusUpdate,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.receptionist, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Update appointment attendance/status (e.g., arrived, completed, no_show, cancelled)."""
    appt = await db.get(Appointment, appointment_id)
    if not appt:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Appointment not found")

    appt.status = payload.status
    await db.commit()
    await db.refresh(appt)
    return appt


@router.post("/booking-requests/{request_id}/match", response_model=BookingRequestResponse)
async def match_booking_request(
    request_id: uuid.UUID,
    payload: BookingMatchRequest,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.receptionist, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Safely match a public booking request with a verified patient record."""
    req = await db.get(BookingRequest, request_id)
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking request not found")

    req.matching_patient_id = payload.patient_id
    req.status = BookingStatus.matched
    await db.commit()
    await db.refresh(req)
    return req


@router.post("/booking-requests/{request_id}/reject", response_model=BookingRequestResponse)
async def reject_booking_request(
    request_id: uuid.UUID,
    current_staff: Staff = Depends(require_role(StaffRole.doctor, StaffRole.receptionist, StaffRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Mark an unviable or invalid booking request as rejected."""
    req = await db.get(BookingRequest, request_id)
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking request not found")

    req.status = BookingStatus.rejected
    await db.commit()
    await db.refresh(req)
    return req
