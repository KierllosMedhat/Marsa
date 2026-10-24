import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { getDb, saveDb } from '@/lib/db';

export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string; noteId: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const idx = db.patient_notes.findIndex(
    (n) => n.patient_id === params.id && n.note_id === params.noteId
  );

  if (idx === -1) {
    return NextResponse.json({ detail: 'Note not found' }, { status: 404 });
  }

  db.patient_notes.splice(idx, 1);
  saveDb(db);

  return new NextResponse(null, { status: 204 });
}
