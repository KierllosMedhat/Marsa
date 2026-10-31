import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { formatStaffUser, hashPassword, requireAuth } from '@/lib/auth';
import { getDb, saveDb } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  return NextResponse.json(db.staff.map(formatStaffUser));
}

export async function POST(req: NextRequest) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  try {
    const body = await req.json();
    const nameAr = String(body.name_ar || '').trim();
    const email = String(body.email || '').trim().toLowerCase();
    const password = String(body.password || '').trim();
    const role = body.role === 'doctor' ? 'doctor' : 'receptionist';

    if (!nameAr || !email || !password) {
      return NextResponse.json(
        {
          detail:
            'يرجى إدخال الاسم، البريد الإلكتروني (أو اسم المستخدم)، وكلمة المرور.',
        },
        { status: 422 }
      );
    }

    const db = getDb();
    const dup = db.staff.find((s) => s.email.toLowerCase() === email);
    if (dup) {
      return NextResponse.json(
        { detail: 'البريد الإلكتروني أو اسم المستخدم مسجل بالفعل لحساب آخر.' },
        { status: 409 }
      );
    }

    const newStaff = {
      staff_id: crypto.randomUUID(),
      role: role as 'doctor' | 'receptionist',
      name_ar: nameAr,
      name_en: body.name_en ? String(body.name_en).trim() : null,
      email,
      phone: body.phone ? String(body.phone).trim() : null,
      password_hash: hashPassword(password),
      mfa_enabled: false,
      is_active: body.is_active !== false,
      created_at: new Date().toISOString(),
    };

    db.staff.push(newStaff);
    saveDb(db);

    return NextResponse.json(formatStaffUser(newStaff), { status: 201 });
  } catch {
    return NextResponse.json({ detail: 'Invalid staff payload' }, { status: 400 });
  }
}
