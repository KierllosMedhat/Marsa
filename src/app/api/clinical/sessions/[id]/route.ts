import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { getDb, logAuditEvent, saveDb, SessionRecord } from '@/lib/db';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const session = db.sessions.find((s) => s.session_id === params.id);
  if (!session) {
    return NextResponse.json({ detail: 'Session not found' }, { status: 404 });
  }

  return NextResponse.json(session);
}

async function handleUpsertSession(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor']);
  if ('error' in auth) return auth.error;

  try {
    const body = await req.json();
    const db = getDb();
    const nowIso = new Date().toISOString();

    let session = db.sessions.find((s) => s.session_id === params.id);
    if (!session) {
      // Auto-create session if client generated UUID locally
      const defaultPatientId =
        body.patient_id || db.patients[0]?.patient_id || 'unknown';
      session = {
        session_id: params.id,
        patient_id: defaultPatientId,
        appointment_id: body.appointment_id || null,
        started_at: nowIso,
        ended_at: null,
        status: 'draft',
        session_number: null,
        chief_complaint: null,
        sleep: null,
        appetite: null,
        mood: null,
        anxiety: null,
        suicidal_self_harm_assessment: null,
        substance_use: null,
        mental_status_examination: null,
        diagnosis: null,
        treatment_plan: null,
        follow_up: null,
        created_by: auth.staff.staff_id,
        finalized_by: null,
        finalized_at: null,
        created_at: nowIso,
      } as SessionRecord;
      db.sessions.unshift(session);
    }

    if (body.session_number !== undefined && body.session_number !== null) {
      const parsed = parseInt(String(body.session_number), 10);
      if (!isNaN(parsed)) session.session_number = parsed;
    }
    if (body.chief_complaint !== undefined) session.chief_complaint = body.chief_complaint;
    if (body.sleep !== undefined) session.sleep = body.sleep;
    if (body.appetite !== undefined) session.appetite = body.appetite;
    if (body.mood !== undefined) session.mood = body.mood;
    if (body.anxiety !== undefined) session.anxiety = body.anxiety;
    if (body.suicidal_self_harm_assessment !== undefined) {
      session.suicidal_self_harm_assessment = body.suicidal_self_harm_assessment;
    }
    if (body.substance_use !== undefined) session.substance_use = body.substance_use;
    if (body.mental_status_examination !== undefined) {
      session.mental_status_examination = body.mental_status_examination;
    }
    if (body.diagnosis !== undefined) session.diagnosis = body.diagnosis;
    if (body.treatment_plan !== undefined) session.treatment_plan = body.treatment_plan;
    if (body.follow_up !== undefined) session.follow_up = body.follow_up;
    if (body.status === 'finalized') {
      session.status = 'finalized';
      session.ended_at = nowIso;
      session.finalized_by = auth.staff.staff_id;
      session.finalized_at = nowIso;
    }

    saveDb(db);
    logAuditEvent('update_session', 'session', auth.staff.staff_id, session.session_id);

    return NextResponse.json(session);
  } catch {
    return NextResponse.json({ detail: 'Invalid session update payload' }, { status: 400 });
  }
}

export const PUT = handleUpsertSession;
export const PATCH = handleUpsertSession;
