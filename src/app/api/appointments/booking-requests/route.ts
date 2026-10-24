import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { BookingRequestRecord, getDb, saveDb } from '@/lib/db';

export async function GET(req: NextRequest) {
  const auth = requireAuth(req, ['doctor', 'receptionist', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const sorted = [...db.booking_requests].sort((a, b) =>
    b.created_at.localeCompare(a.created_at)
  );
  return NextResponse.json(sorted);
}

export async function POST(req: NextRequest) {
  // Public endpoint (no auth required) for prospective patients booking from the website
  try {
    const body = await req.json();
    const name = (body.name || '').trim();
    const phone = (body.phone || '').trim();

    if (!name || !phone) {
      return NextResponse.json(
        { detail: 'يرجى إدخال الاسم ورقم الهاتف.' },
        { status: 422 }
      );
    }

    const db = getDb();
    const typeObj =
      db.appointment_types.find((t) => t.type_id === body.type_id) ||
      db.appointment_types[0];

    const nowIso = new Date().toISOString();
    const bookingReq: BookingRequestRecord = {
      request_id: crypto.randomUUID(),
      name,
      phone,
      email: body.email || null,
      type_id: typeObj.type_id,
      preferred_slot: body.preferred_slot || null,
      status: 'pending_match',
      matching_patient_id: null,
      notes: body.notes || null,
      created_at: nowIso,
    };

    db.booking_requests.unshift(bookingReq);
    saveDb(db);

    return NextResponse.json(bookingReq, { status: 201 });
  } catch {
    return NextResponse.json(
      { detail: 'Invalid booking request payload' },
      { status: 400 }
    );
  }
}
