import { NextRequest, NextResponse } from 'next/server';
import { requireAuth } from '@/lib/auth';

export async function GET(req: NextRequest) {
  const auth = requireAuth(req);
  if ('error' in auth) return auth.error;

  const { staff } = auth;
  return NextResponse.json({
    staff_id: staff.staff_id,
    role: staff.role,
    name_ar: staff.name_ar,
    name_en: staff.name_en,
    email: staff.email,
    phone: staff.phone,
    mfa_enabled: staff.mfa_enabled,
    is_active: staff.is_active,
    created_at: staff.created_at,
  });
}
