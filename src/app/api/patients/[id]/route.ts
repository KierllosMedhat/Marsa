import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import {
  buildDoctorPatientResponse,
  getDb,
  logAuditEvent,
  saveDb,
} from '@/lib/db';
import { encryptField } from '@/lib/encryption';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const patient = db.patients.find(
    (p) => p.patient_id === params.id && !p.deleted_at
  );

  if (!patient) {
    return NextResponse.json({ detail: 'Patient not found' }, { status: 404 });
  }

  logAuditEvent('read_patient_full', 'patient', auth.staff.staff_id, patient.patient_id);
  return NextResponse.json(buildDoctorPatientResponse(patient));
}

async function handleUpdate(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const patient = db.patients.find(
    (p) => p.patient_id === params.id && !p.deleted_at
  );

  if (!patient) {
    return NextResponse.json({ detail: 'Patient not found' }, { status: 404 });
  }

  try {
    const body = await req.json();
    if (body.name_ar !== undefined && body.name_ar !== null) {
      patient.name_ar = body.name_ar;
    }
    if (body.name_en !== undefined) patient.name_en = body.name_en;
    if (body.dob !== undefined) patient.dob = body.dob;
    if (body.sex !== undefined) patient.sex = body.sex;
    if (body.national_id !== undefined) {
      patient.national_id = body.national_id ? encryptField(body.national_id) : null;
    }
    if (body.phone !== undefined) patient.phone = body.phone;
    if (body.email !== undefined) patient.email = body.email;
    if (body.address !== undefined) patient.address = body.address;
    if (body.occupation !== undefined) patient.occupation = body.occupation;
    if (body.marital_status !== undefined) patient.marital_status = body.marital_status;
    if (body.children !== undefined) patient.children = body.children;
    if (body.first_session_date !== undefined) {
      patient.first_session_date = body.first_session_date;
    }
    if (body.last_session_date !== undefined) {
      patient.last_session_date = body.last_session_date;
    }
    if (body.emergency_contact !== undefined) {
      patient.emergency_contact = body.emergency_contact;
    }

    patient.updated_at = new Date().toISOString();
    saveDb(db);
    logAuditEvent('update_patient', 'patient', auth.staff.staff_id, patient.patient_id);

    return NextResponse.json(buildDoctorPatientResponse(patient));
  } catch {
    return NextResponse.json({ detail: 'Invalid update payload' }, { status: 400 });
  }
}

export const PUT = handleUpdate;
export const PATCH = handleUpdate;

export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const patient = db.patients.find(
    (p) => p.patient_id === params.id && !p.deleted_at
  );

  if (!patient) {
    return NextResponse.json({ detail: 'Patient not found' }, { status: 404 });
  }

  patient.deleted_at = new Date().toISOString();
  saveDb(db);
  logAuditEvent('soft_delete_patient', 'patient', auth.staff.staff_id, patient.patient_id);

  return new NextResponse(null, { status: 204 });
}
