import { NextRequest, NextResponse } from 'next/server';
import { getDb } from '@/lib/db';
import { signToken, verifyToken } from '@/lib/auth';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const refreshToken = body.refresh_token || '';
    const payload = verifyToken(refreshToken);

    if (!payload || payload.type !== 'refresh') {
      return NextResponse.json(
        { detail: 'Invalid or expired refresh token' },
        { status: 401 }
      );
    }

    const db = getDb();
    const staff = db.staff.find((s) => s.staff_id === payload.sub && s.is_active);
    if (!staff) {
      return NextResponse.json({ detail: 'Staff not found' }, { status: 401 });
    }

    const newAccess = signToken(staff.staff_id, staff.role, 'access', 60 * 60 * 24);
    const newRefresh = signToken(staff.staff_id, staff.role, 'refresh', 60 * 60 * 24 * 30);

    return NextResponse.json({
      access_token: newAccess,
      refresh_token: newRefresh,
      token_type: 'bearer',
      requires_mfa: false,
    });
  } catch {
    return NextResponse.json({ detail: 'Invalid request' }, { status: 400 });
  }
}
