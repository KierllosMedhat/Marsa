import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';
import { logAuditEvent } from '@/lib/db';

export async function POST(req: NextRequest) {
  const auth = requireAuth(req);
  if ('error' in auth) return auth.error;

  logAuditEvent('logout', 'auth', auth.staff.staff_id);
  return new NextResponse(null, { status: 204 });
}
