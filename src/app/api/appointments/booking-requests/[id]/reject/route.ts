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

  booking.status = 'rejected';
  saveDb(db);

  return NextResponse.json(booking);
}
