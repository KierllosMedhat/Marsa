import { NextRequest, NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { formatStaffUser, signToken, verifyToken } from '@/lib/auth';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const refreshToken = body.refresh_token || '';
    const payload = verifyToken(refreshToken);

    if (!payload || payload.type !== 'refresh') {
      return NextResponse.json(
        { detail: 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً' },
        { status: 401 }
      );
    }

    const db = getDb();
    const staff = db.staff.find(
      (s) => s.staff_id === payload.sub && s.is_active
    );
    if (!staff) {
      return NextResponse.json(
        { detail: 'المستخدم غير موجود أو غير مفعل' },
        { status: 401 }
      );
    }

    const newAccess = signToken(
      staff.staff_id,
      staff.role,
      'access',
      60 * 60 * 24 * 7
    );
    const newRefresh = signToken(
      staff.staff_id,
      staff.role,
      'refresh',
      60 * 60 * 24 * 30
    );

    return NextResponse.json({
      access_token: newAccess,
      refresh_token: newRefresh,
      token_type: 'bearer',
      requires_mfa: false,
      user: formatStaffUser(staff),
    });
  } catch {
    return NextResponse.json(
      { detail: 'طلب تحديث الجلسة غير صالح' },
      { status: 400 }
    );
  }
}
