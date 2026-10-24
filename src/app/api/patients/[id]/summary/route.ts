import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import {
  buildReceptionistPatientSummary,
  getDb,
  logAuditEvent,
} from '@/lib/db';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'receptionist', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const patient = db.patients.find(
    (p) => p.patient_id === params.id && !p.deleted_at
  );

  if (!patient) {
    return NextResponse.json({ detail: 'Patient not found' }, { status: 404 });
  }

  logAuditEvent(
    'read_patient_summary',
    'patient',
    auth.staff.staff_id,
    patient.patient_id
  );
  return NextResponse.json(buildReceptionistPatientSummary(patient));
}
