import { NextRequest, NextResponse } from 'next/server';
import { getDb, logAuditEvent } from '@/lib/db';
import { signToken, verifyPassword } from '@/lib/auth';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const email = (body.email || '').trim().toLowerCase();
    const password = body.password || '';

    const db = getDb();
    const staff = db.staff.find((s) => s.email.toLowerCase() === email);

    if (!staff || !verifyPassword(password, staff.password_hash)) {
      logAuditEvent('login_failed', 'auth', staff?.staff_id || null);
      return NextResponse.json(
        { detail: 'Invalid email or password' },
        { status: 401 }
      );
    }

    if (!staff.is_active) {
      return NextResponse.json(
        { detail: 'Staff account is deactivated' },
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

    const accessToken = signToken(staff.staff_id, staff.role, 'access', 60 * 60 * 24);
    const refreshToken = signToken(staff.staff_id, staff.role, 'refresh', 60 * 60 * 24 * 30);

    logAuditEvent('login_success', 'auth', staff.staff_id);

    return NextResponse.json({
      access_token: accessToken,
      refresh_token: refreshToken,
      token_type: 'bearer',
      requires_mfa: false,
    });
  } catch {
    return NextResponse.json(
      { detail: 'Invalid request body' },
      { status: 400 }
    );
  }
}
