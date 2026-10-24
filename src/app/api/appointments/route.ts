import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { AppointmentRecord, getDb, saveDb } from '@/lib/db';

function enrichAppointment(appt: AppointmentRecord) {
  const db = getDb();
  const patient = appt.patient_id
    ? db.patients.find((p) => p.patient_id === appt.patient_id)
    : null;
  const apptType = db.appointment_types.find((t) => t.type_id === appt.type_id);

  return {
    ...appt,
    patient_name: patient?.name_ar || 'مريض مسجل',
    patient_mrn: patient?.mrn || null,
    patient_phone: patient?.phone || null,
    type_name: apptType?.name_ar || 'جلسة استشارية',
  };
}

export async function GET(req: NextRequest) {
  const auth = requireAuth(req);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const sorted = [...db.appointments].sort((a, b) =>
    a.slot_start.localeCompare(b.slot_start)
  );

  return NextResponse.json(sorted.map(enrichAppointment));
}

export async function POST(req: NextRequest) {
  const auth = requireAuth(req, ['doctor', 'receptionist', 'admin']);
  if ('error' in auth) return auth.error;

  try {
    const body = await req.json();
    const db = getDb();

    const typeObj = db.appointment_types.find((t) => t.type_id === body.type_id);
    if (!typeObj) {
      return NextResponse.json(
        { detail: 'Appointment type not found' },
        { status: 404 }
      );
    }

    const nowIso = new Date().toISOString();
    const appt: AppointmentRecord = {
      appointment_id: crypto.randomUUID(),
      patient_id: body.patient_id || null,
      booking_request_id: body.booking_request_id || null,
      type_id: body.type_id,
      slot_start: body.slot_start,
      slot_end: body.slot_end,
      status: body.patient_id ? 'confirmed' : 'available',
      notes: body.notes || null,
      created_at: nowIso,
      updated_at: nowIso,
    };

    db.appointments.push(appt);
    saveDb(db);

    return NextResponse.json(enrichAppointment(appt), { status: 201 });
  } catch {
    return NextResponse.json({ detail: 'Invalid appointment payload' }, { status: 400 });
  }
}
