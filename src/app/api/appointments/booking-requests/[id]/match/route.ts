import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { getDb, saveDb } from '@/lib/db';

export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'receptionist', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const booking = db.booking_requests.find((b) => b.request_id === params.id);
  if (!booking) {
    return NextResponse.json({ detail: 'Booking request not found' }, { status: 404 });
  }

  try {
    const body = await req.json();
    booking.matching_patient_id = body.patient_id;
    booking.status = 'matched';

    // Also automatically schedule a confirmed appointment if preferred_slot exists
    const nowIso = new Date().toISOString();
    const slotStart = booking.preferred_slot
      ? new Date(booking.preferred_slot).toISOString()
      : nowIso;
    const slotEnd = new Date(new Date(slotStart).getTime() + 45 * 60 * 1000).toISOString();

    db.appointments.push({
      appointment_id: crypto.randomUUID(),
      patient_id: body.patient_id,
      booking_request_id: booking.request_id,
      type_id: booking.type_id,
      slot_start: slotStart,
      slot_end: slotEnd,
      status: 'confirmed',
      notes: booking.notes || 'موعد معتمد من طلبات الموقع الإلكتروني',
      created_at: nowIso,
      updated_at: nowIso,
    });

    saveDb(db);
    return NextResponse.json(booking);
  } catch {
    return NextResponse.json({ detail: 'Invalid match payload' }, { status: 400 });
  }
}
