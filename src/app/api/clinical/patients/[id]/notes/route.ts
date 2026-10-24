import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { getDb, logAuditEvent, PatientNoteRecord, saveDb } from '@/lib/db';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const list = db.patient_notes
    .filter((n) => n.patient_id === params.id)
    .sort((a, b) => b.last_modified.localeCompare(a.last_modified));

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

    const noteRec: PatientNoteRecord = {
      note_id: crypto.randomUUID(),
      patient_id: params.id,
      note_text: body.note_text || '',
      last_modified: nowIso,
    };

    db.patient_notes.unshift(noteRec);
    saveDb(db);
    logAuditEvent('add_patient_note', 'patient_note', auth.staff.staff_id, noteRec.note_id);

    return NextResponse.json(noteRec, { status: 201 });
  } catch {
    return NextResponse.json({ detail: 'Invalid note payload' }, { status: 400 });
  }
}
