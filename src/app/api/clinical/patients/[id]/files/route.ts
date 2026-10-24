import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { getDb, logAuditEvent, PatientFileRecord, saveDb } from '@/lib/db';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const list = db.patient_files
    .filter((f) => f.patient_id === params.id)
    .sort((a, b) => b.uploaded_at.localeCompare(a.uploaded_at));

  return NextResponse.json(list);
}

export async function POST(
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
    const nowIso = new Date().toISOString();

    const fileRec: PatientFileRecord = {
      file_id: crypto.randomUUID(),
      patient_id: params.id,
      file_name: body.file_name || 'مرفق طبي',
      file_type: body.file_type || 'medical_report',
      file_location: body.file_location || '/uploads/reports/document.pdf',
      uploaded_at: nowIso,
    };

    db.patient_files.unshift(fileRec);
    saveDb(db);
    logAuditEvent('add_patient_file', 'patient_file', auth.staff.staff_id, fileRec.file_id);

    return NextResponse.json(fileRec, { status: 201 });
  } catch {
    return NextResponse.json({ detail: 'Invalid file payload' }, { status: 400 });
  }
}
