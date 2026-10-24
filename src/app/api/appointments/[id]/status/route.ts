import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { getDb, saveDb } from '@/lib/db';

async function handleStatusUpdate(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'receptionist', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const appt = db.appointments.find((a) => a.appointment_id === params.id);
  if (!appt) {
    return NextResponse.json({ detail: 'Appointment not found' }, { status: 404 });
  }

  try {
    const body = await req.json();
    if (body.status) {
      appt.status = body.status;
      appt.updated_at = new Date().toISOString();
      saveDb(db);
    }
    return NextResponse.json(appt);
  } catch {
    return NextResponse.json({ detail: 'Invalid status payload' }, { status: 400 });
  }
}

export const PATCH = handleStatusUpdate;
export const PUT = handleStatusUpdate;
export const POST = handleStatusUpdate;
