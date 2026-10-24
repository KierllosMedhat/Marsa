import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { getDb, logAuditEvent, MedicationRecord, saveDb } from '@/lib/db';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const list = db.medications
    .filter((m) => m.patient_id === params.id)
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

    const med: MedicationRecord = {
      medication_id: crypto.randomUUID(),
      patient_id: params.id,
      name_ar: body.name_ar || 'دواء موصوف',
      name_en: body.name_en || null,
      dose: body.dose || null,
      frequency: body.frequency || null,
      route: body.route || null,
      duration: body.duration || null,
      date: body.date || body.start_date || nowIso.slice(0, 10),
      start_date: body.start_date || body.date || nowIso.slice(0, 10),
      end_date: body.end_date || null,
      notes: body.notes || null,
      prescribed_by: auth.staff.staff_id,
      is_active: body.is_active !== undefined ? Boolean(body.is_active) : true,
      created_at: nowIso,
    };

    db.medications.unshift(med);
    saveDb(db);
    logAuditEvent('prescribe_medication', 'medication', auth.staff.staff_id, med.medication_id);

    return NextResponse.json(med, { status: 201 });
  } catch {
    return NextResponse.json({ detail: 'Invalid medication payload' }, { status: 400 });
  }
}
