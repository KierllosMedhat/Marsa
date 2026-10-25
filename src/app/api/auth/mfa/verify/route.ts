import { NextRequest, NextResponse } from 'next/server';
import { getDb, logAuditEvent } from '@/lib/db';
import { formatStaffUser, signToken, verifyToken } from '@/lib/auth';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const mfaToken = body.mfa_token || '';
    const totpCode = (body.totp_code || '').trim();

    const payload = verifyToken(mfaToken);
    if (!payload || payload.type !== 'mfa_pending') {
      return NextResponse.json(
        { detail: 'انتهت صلاحية رمز المصادقة الثنائية' },
        { status: 401 }
      );
    }

    if (!totpCode || totpCode.length < 4) {
      return NextResponse.json(
        { detail: 'رمز التحقق الثنائي (TOTP) غير صحيح' },
        { status: 401 }
      );
    }

    const db = getDb();
    const staff = db.staff.find(
      (s) => s.staff_id === payload.sub && s.is_active
    );
    if (!staff) {
      return NextResponse.json(
        { detail: 'المستخدم غير موجود' },
        { status: 401 }
      );
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

    logAuditEvent('mfa_verify_success', 'auth', staff.staff_id);

    return NextResponse.json({
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: 'bearer',
      requires_mfa: false,
      user: formatStaffUser(staff),
    });
  } catch {
    return NextResponse.json({ detail: 'طلب غير صالح' }, { status: 400 });
  }
}
