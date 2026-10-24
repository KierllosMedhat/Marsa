import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import {
  buildDoctorPatientResponse,
  buildReceptionistPatientSummary,
  getDb,
  logAuditEvent,
  PatientRecord,
  saveDb,
} from '@/lib/db';
import { encryptField } from '@/lib/encryption';

export async function GET(req: NextRequest) {
  const auth = requireAuth(req);
  if ('error' in auth) return auth.error;

  const { staff } = auth;
  const q = req.nextUrl.searchParams.get('q')?.trim().toLowerCase() || '';

  const db = getDb();
  let patients = db.patients.filter((p) => !p.deleted_at);

  if (q) {
    patients = patients.filter(
      (p) =>
        p.name_ar.toLowerCase().includes(q) ||
        (p.name_en && p.name_en.toLowerCase().includes(q)) ||
        (p.phone && p.phone.includes(q)) ||
        p.mrn.toLowerCase().includes(q)
    );
  }

  logAuditEvent('list_patients', 'patient', staff.staff_id);

  if (staff.role === 'receptionist') {
    return NextResponse.json(patients.map((p) => buildReceptionistPatientSummary(p)));
  }

  return NextResponse.json(patients.map((p) => buildDoctorPatientResponse(p)));
}

export async function POST(req: NextRequest) {
  const auth = requireAuth(req, ['doctor', 'receptionist', 'admin']);
  if ('error' in auth) return auth.error;

  const { staff } = auth;
  try {
    const body = await req.json();
    const nameAr = (body.name_ar || '').trim();
    if (!nameAr) {
      return NextResponse.json(
        { detail: 'Patient Arabic name (name_ar) is required' },
        { status: 422 }
      );
    }

    const db = getDb();
    const activePatients = db.patients.filter((p) => !p.deleted_at);

    // Duplicate detection warnings
    const duplicateWarnings = activePatients
      .filter(
        (p) =>
          p.name_ar === nameAr ||
          (body.phone && p.phone && p.phone === body.phone)
      )
      .map((p) => ({
        patient_id: p.patient_id,
        mrn: p.mrn,
        name_ar: p.name_ar,
        phone: p.phone,
        similarity_reason: 'Similar name or phone number found',
      }));

    // Generate next MRN-0000X
    const nextNumber = db.patients.length + 1;
    const mrn = `MRN-${String(nextNumber).padStart(5, '0')}`;
    const nowIso = new Date().toISOString();

    const newPatient: PatientRecord = {
      patient_id: crypto.randomUUID(),
      mrn,
      name_ar: nameAr,
      name_en: body.name_en || null,
      dob: body.dob || null,
      sex: body.sex || null,
      national_id: body.national_id ? encryptField(body.national_id) : null,
      phone: body.phone || null,
      email: body.email || null,
      address: body.address || null,
      occupation: body.occupation || null,
      marital_status: body.marital_status || null,
      children: body.children || null,
      first_session_date: body.first_session_date || nowIso.slice(0, 10),
      last_session_date: body.last_session_date || null,
      emergency_contact: body.emergency_contact || null,
      created_by: staff.staff_id,
      created_at: nowIso,
      updated_at: nowIso,
      deleted_at: null,
    };

    db.patients.unshift(newPatient);
    saveDb(db);
    logAuditEvent('create_patient', 'patient', staff.staff_id, newPatient.patient_id);

    const patientOut =
      staff.role === 'receptionist'
        ? buildReceptionistPatientSummary(newPatient)
        : buildDoctorPatientResponse(newPatient);

    return NextResponse.json(
      {
        patient: patientOut,
        duplicate_warnings: duplicateWarnings,
      },
      { status: 201 }
    );
  } catch {
    return NextResponse.json({ detail: 'Invalid request payload' }, { status: 400 });
  }
}
