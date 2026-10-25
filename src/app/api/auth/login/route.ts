import { NextRequest, NextResponse } from 'next/server';
import { getDb, logAuditEvent } from '@/lib/db';
import { formatStaffUser, signToken, verifyPassword } from '@/lib/auth';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const rawEmail = (body.email || '').trim().toLowerCase();
    const password = (body.password || '').trim();

    if (!rawEmail || !password) {
      return NextResponse.json(
        { detail: 'يرجى إدخال البريد الإلكتروني وكلمة المرور' },
        { status: 400 }
      );
    }

    const db = getDb();
    const staff = db.staff.find(
      (s) =>
        s.email.toLowerCase() === rawEmail ||
        (rawEmail === 'doctor' && s.role === 'doctor') ||
        ((rawEmail === 'receptionist' || rawEmail === 'reception') &&
          s.role === 'receptionist')
    );

    if (!staff || !verifyPassword(password, staff.password_hash)) {
      logAuditEvent('login_failed', 'auth', staff?.staff_id || null);
      return NextResponse.json(
        { detail: 'البريد الإلكتروني أو كلمة المرور غير صحيحة' },
        { status: 401 }
      );
    }

    if (!staff.is_active) {
      return NextResponse.json(
        { detail: 'حساب الموظف غير مفعل حالياً' },
        { status: 403 }
      );
    }

    if (staff.mfa_enabled) {
      const mfaToken = signToken(staff.staff_id, staff.role, 'mfa_pending', 300);
      return NextResponse.json({
        requires_mfa: true,
        mfa_token: mfaToken,
        token_type: 'bearer',
      });
    }

    const accessToken = signToken(
      staff.staff_id,
      staff.role,
      'access',
      60 * 60 * 24 * 7
    );
    const refreshToken = signToken(
      staff.staff_id,
      staff.role,
      'refresh',
      60 * 60 * 24 * 30
    );

    logAuditEvent('login_success', 'auth', staff.staff_id);

    return NextResponse.json({
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: 'bearer',
      requires_mfa: false,
      user: formatStaffUser(staff),
    });
  } catch {
    return NextResponse.json(
      { detail: 'بيانات طلب تسجيل الدخول غير صالحة' },
      { status: 400 }
    );
  }
}
