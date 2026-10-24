import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { getDb, logAuditEvent, saveDb, SessionRecord } from '@/lib/db';

export async function POST(req: NextRequest) {
  const auth = requireAuth(req, ['doctor']);
  if ('error' in auth) return auth.error;

  try {
    const body = await req.json();
    const db = getDb();
    const patient = db.patients.find(
      (p) => p.patient_id === body.patient_id && !p.deleted_at
    );
    if (!patient) {
      return NextResponse.json({ detail: 'Patient not found' }, { status: 404 });
    }

    const nowIso = new Date().toISOString();
    const session: SessionRecord = {
      session_id: crypto.randomUUID(),
      patient_id: body.patient_id,
      appointment_id: body.appointment_id || null,
      started_at: body.started_at || nowIso,
      ended_at: null,
      status: 'draft',
      session_number: body.session_number ? Number(body.session_number) : null,
      chief_complaint: body.chief_complaint || null,
      sleep: body.sleep || null,
      appetite: body.appetite || null,
      mood: body.mood || null,
      anxiety: body.anxiety || null,
      suicidal_self_harm_assessment: body.suicidal_self_harm_assessment || null,
      substance_use: body.substance_use || null,
      mental_status_examination: body.mental_status_examination || null,
      diagnosis: body.diagnosis || null,
      treatment_plan: body.treatment_plan || null,
      follow_up: body.follow_up || null,
      created_by: auth.staff.staff_id,
      finalized_by: null,
      finalized_at: null,
      created_at: nowIso,
    };

    db.sessions.unshift(session);
    saveDb(db);
    logAuditEvent('start_session', 'session', auth.staff.staff_id, session.session_id);

    return NextResponse.json(session, { status: 201 });
  } catch {
    return NextResponse.json({ detail: 'Invalid session payload' }, { status: 400 });
  }
}
