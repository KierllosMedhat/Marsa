import { NextResponse } from 'next/server';
import { getDb } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET() {
  const db = getDb();
  return NextResponse.json({
    status: 'ok',
    db: db.staff.length > 0,
    redis: true,
    appVersion: '1.2.4',
    buildNumber: 7,
    timestamp: new Date().toISOString(),
  });
}
