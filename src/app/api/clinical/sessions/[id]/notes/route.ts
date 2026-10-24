import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { getDb, logAuditEvent, saveDb, SessionNoteRecord } from '@/lib/db';
import { decryptField, encryptField } from '@/lib/encryption';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const notes = db.session_notes
    .filter((n) => n.session_id === params.id)
    .map((n) => ({
      ...n,
      content_typed: decryptField(n.content_typed),
    }));

  return NextResponse.json(notes);
}

export async function POST(
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
    if (session && body.is_draft === false) {
      session.status = 'finalized';
      session.ended_at = nowIso;
      session.finalized_by = auth.staff.staff_id;
      session.finalized_at = nowIso;
    }

    const encryptedContent = body.content_typed
      ? encryptField(body.content_typed)
      : null;

    const note: SessionNoteRecord = {
      note_id: crypto.randomUUID(),
      session_id: params.id,
      note_type: body.note_type || 'typed',
      content_typed: encryptedContent,
      content_ink_ref: body.content_ink_ref || null,
      version: 1,
      is_draft: body.is_draft !== undefined ? Boolean(body.is_draft) : true,
      amended_from: body.amended_from || null,
      edited_at: nowIso,
      edited_by: auth.staff.staff_id,
    };

    db.session_notes.push(note);
    saveDb(db);
    logAuditEvent('create_session_note', 'session_note', auth.staff.staff_id, note.note_id);

    return NextResponse.json(
      {
        ...note,
        content_typed: body.content_typed || null,
      },
      { status: 201 }
    );
  } catch {
    return NextResponse.json({ detail: 'Invalid session note payload' }, { status: 400 });
  }
}
