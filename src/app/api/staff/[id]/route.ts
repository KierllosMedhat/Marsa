import { NextRequest, NextResponse } from 'next/server';
import { formatStaffUser, hashPassword, requireAuth } from '@/lib/auth';
import { getDb, saveDb } from '@/lib/db';

export const dynamic = 'force-dynamic';

async function handleUpdateStaff(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  const db = getDb();
  const targetStaff = db.staff.find((s) => s.staff_id === params.id);
  if (!targetStaff) {
    return NextResponse.json({ detail: 'الحساب غير موجود' }, { status: 404 });
  }

  try {
    const body = await req.json();
    if (body.name_ar !== undefined && String(body.name_ar).trim()) {
      targetStaff.name_ar = String(body.name_ar).trim();
    }
    if (body.name_en !== undefined) {
      targetStaff.name_en = body.name_en ? String(body.name_en).trim() : null;
    }
    if (body.email !== undefined && String(body.email).trim()) {
      const nextEmail = String(body.email).trim().toLowerCase();
      const dup = db.staff.find(
        (s) => s.staff_id !== params.id && s.email.toLowerCase() === nextEmail
      );
      if (dup) {
        return NextResponse.json(
          { detail: 'البريد الإلكتروني مستخدم بالفعل لحساب آخر.' },
          { status: 409 }
        );
      }
      targetStaff.email = nextEmail;
    }
    if (body.phone !== undefined) {
      targetStaff.phone = body.phone ? String(body.phone).trim() : null;
    }
    if (
      body.role !== undefined &&
      (body.role === 'doctor' || body.role === 'receptionist')
    ) {
      targetStaff.role = body.role;
    }
    if (body.is_active !== undefined && params.id !== auth.staff.staff_id) {
      targetStaff.is_active = Boolean(body.is_active);
    }
    if (body.password !== undefined && String(body.password).trim().length > 0) {
      targetStaff.password_hash = hashPassword(String(body.password).trim());
    }

    saveDb(db);
    return NextResponse.json(formatStaffUser(targetStaff));
  } catch {
    return NextResponse.json({ detail: 'Invalid update payload' }, { status: 400 });
  }
}

export const PUT = handleUpdateStaff;
export const PATCH = handleUpdateStaff;

export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const auth = requireAuth(req, ['doctor', 'admin']);
  if ('error' in auth) return auth.error;

  if (params.id === auth.staff.staff_id) {
    return NextResponse.json(
      { detail: 'لا يمكنك حذف حسابك الشخصي الحالي أثناء تسجيل الدخول.' },
      { status: 400 }
    );
  }

  const db = getDb();
  db.staff = db.staff.filter((s) => s.staff_id !== params.id);
  saveDb(db);

  return NextResponse.json({ status: 'deleted', staff_id: params.id });
}
