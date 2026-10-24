import { NextRequest, NextResponse } from 'next/server';
import { getDb, logAuditEvent } from '@/lib/db';
import { signToken, verifyToken } from '@/lib/auth';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const mfaToken = body.mfa_token || '';
    const totpCode = (body.totp_code || '').trim();

    const payload = verifyToken(mfaToken);
    if (!payload || payload.type !== 'mfa_pending') {
      return NextResponse.json(
        { detail: 'Invalid or expired MFA token' },
        { status: 401 }
      );
    }

    if (!totpCode || totpCode.length < 4) {
      return NextResponse.json(
        { detail: 'Invalid TOTP verification code' },
        { status: 401 }
      );
    }

    const db = getDb();
    const staff = db.staff.find((s) => s.staff_id === payload.sub && s.is_active);
    if (!staff) {
      return NextResponse.json({ detail: 'Staff not found' }, { status: 401 });
    }

    const accessToken = signToken(staff.staff_id, staff.role, 'access', 60 * 60 * 24);
    const refreshToken = signToken(staff.staff_id, staff.role, 'refresh', 60 * 60 * 24 * 30);

    logAuditEvent('mfa_verify_success', 'auth', staff.staff_id);

    return NextResponse.json({
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: 'bearer',
      requires_mfa: false,
    });
  } catch {
    return NextResponse.json({ detail: 'Invalid request' }, { status: 400 });
  }
}
