import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { AppointmentTypeRecord, getDb, saveDb } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET() {
  const db = getDb();
  const activeTypes = db.appointment_types.filter((t) => t.is_active);
  return NextResponse.json(activeTypes);
}

export async function POST(req: NextRequest) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  try {
    const body = await req.json();
    const db = getDb();

    const newType: AppointmentTypeRecord = {
      type_id: crypto.randomUUID(),
      name_ar: body.name_ar || 'جلسة علاجية',
      name_en: body.name_en || null,
      duration_minutes: Number(body.duration_minutes) || 45,
      price_egp: Number(body.price_egp) || 600,
      is_active: body.is_active !== undefined ? Boolean(body.is_active) : true,
    };

    db.appointment_types.push(newType);
    saveDb(db);

    return NextResponse.json(newType, { status: 201 });
  } catch {
    return NextResponse.json({ detail: 'Invalid appointment type payload' }, { status: 400 });
  }
}
