import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { DiagnosisRecord, getDb, logAuditEvent, saveDb } from '@/lib/db';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const list = db.diagnoses
    .filter((d) => d.patient_id === params.id)
    .sort((a, b) => b.created_at.localeCompare(a.created_at));

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

    const diag: DiagnosisRecord = {
      diagnosis_id: crypto.randomUUID(),
      patient_id: params.id,
      icd10_code: body.icd10_code || null,
      description_ar: body.description_ar || 'تشخيص سريري',
      description_en: body.description_en || null,
      date_diagnosed: body.date_diagnosed || nowIso.slice(0, 10),
      status: body.status || 'active',
      author_id: auth.staff.staff_id,
      created_at: nowIso,
      finalized_at: null,
    };

    db.diagnoses.unshift(diag);
    saveDb(db);
    logAuditEvent('create_diagnosis', 'diagnosis', auth.staff.staff_id, diag.diagnosis_id);

    return NextResponse.json(diag, { status: 201 });
  } catch {
    return NextResponse.json({ detail: 'Invalid diagnosis payload' }, { status: 400 });
  }
}
