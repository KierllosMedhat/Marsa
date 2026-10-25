import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import {
  AppointmentRecord,
  BookingRequestRecord,
  getDb,
  PatientRecord,
  saveDb,
} from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const auth = requireAuth(req, ['doctor', 'receptionist', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const sorted = [...db.booking_requests].sort((a, b) =>
    b.created_at.localeCompare(a.created_at)
  );
  return NextResponse.json(sorted);
}

export async function POST(req: NextRequest) {
  // Public endpoint (no auth required) for patients booking from the website
  try {
    const body = await req.json();
    const name = (body.name || '').trim();
    const phone = (body.phone || '').trim();
    const email = body.email ? String(body.email).trim() : null;

    if (!name || !phone) {
      return NextResponse.json(
        { detail: 'يرجى إدخال الاسم ورقم الهاتف.' },
        { status: 422 }
      );
    }

    const db = getDb();
    const typeObj =
      db.appointment_types.find((t) => t.type_id === body.type_id) ||
      db.appointment_types[0];

    const nowIso = new Date().toISOString();

    // 1. Find existing patient by phone or exact name, or auto-create a patient record
    let patient = db.patients.find(
      (p) => !p.deleted_at && (p.phone === phone || p.name_ar === name)
    );

    if (!patient) {
      const nextNum = db.patients.length + 1;
      const mrn = `MRN-${String(nextNum).padStart(5, '0')}`;
      const doctorId =
        db.staff.find((s) => s.role === 'doctor')?.staff_id || 'system';

      patient = {
        patient_id: crypto.randomUUID(),
        mrn,
        name_ar: name,
        name_en: null,
        dob: null,
        sex: null,
        national_id: null,
        phone,
        email,
        address: null,
        occupation: null,
        marital_status: null,
        children: null,
        first_session_date: (body.preferred_slot || nowIso).slice(0, 10),
        last_session_date: null,
        emergency_contact: null,
        created_by: doctorId,
        created_at: nowIso,
        updated_at: nowIso,
        deleted_at: null,
      } as PatientRecord;

      db.patients.unshift(patient);
    }

    // 2. Create the booking request record for receptionist triage visibility
    const requestId = crypto.randomUUID();
    const bookingReq: BookingRequestRecord = {
      request_id: requestId,
      name,
      phone,
      email,
      type_id: typeObj.type_id,
      preferred_slot: body.preferred_slot || nowIso,
      status: 'pending_match',
      matching_patient_id: patient.patient_id,
      notes: body.notes || null,
      created_at: nowIso,
    };
    db.booking_requests.unshift(bookingReq);

    // 3. Automatically create a scheduled appointment so it immediately appears in the Portal Schedule
    let slotStartIso = nowIso;
    if (body.preferred_slot) {
      const parsed = new Date(body.preferred_slot);
      if (!isNaN(parsed.getTime())) {
        slotStartIso = parsed.toISOString();
      }
    }
    const durationMs = (typeObj.duration_minutes || 45) * 60 * 1000;
    const slotEndIso = new Date(
      new Date(slotStartIso).getTime() + durationMs
    ).toISOString();

    const newAppt: AppointmentRecord = {
      appointment_id: crypto.randomUUID(),
      patient_id: patient.patient_id,
      booking_request_id: requestId,
      type_id: typeObj.type_id,
      slot_start: slotStartIso,
      slot_end: slotEndIso,
      status: 'confirmed',
      notes: body.notes
        ? `${body.notes} (حجز من الموقع الإلكتروني)`
        : 'حجز من الموقع الإلكتروني',
      created_at: nowIso,
      updated_at: nowIso,
    };
    db.appointments.push(newAppt);

    saveDb(db);

    return NextResponse.json(
      {
        ...bookingReq,
        appointment_id: newAppt.appointment_id,
        patient_id: patient.patient_id,
        patient_mrn: patient.mrn,
      },
      { status: 201 }
    );
  } catch {
    return NextResponse.json(
      { detail: 'Invalid booking request payload' },
      { status: 400 }
    );
  }
}
