import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET() {
  const db = getDb();
  return NextResponse.json({
    status: 'ok',
    db: db.staff.length > 0,
    redis: true,
    appVersion: '1.2.1',
    buildNumber: 4,
    timestamp: new Date().toISOString(),
  });
}
