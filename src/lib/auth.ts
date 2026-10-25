import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { getDb, StaffMember, StaffRole } from './db';

const JWT_SECRET =
  process.env.JWT_SECRET ||
  process.env.JWT_PRIVATE_KEY ||
  'marsa-clinic-jwt-signing-secret-2026-secure';

function base64UrlEncode(input: Buffer | string): string {
  const buf = typeof input === 'string' ? Buffer.from(input, 'utf8') : input;
  return buf
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
}

function base64UrlDecode(input: string): string {
  let base64 = input.replace(/-/g, '+').replace(/_/g, '/');
  while (base64.length % 4 !== 0) {
    base64 += '=';
  }
  return Buffer.from(base64, 'base64').toString('utf8');
}

export interface TokenPayload {
  sub: string;
  role: StaffRole;
  type: 'access' | 'refresh' | 'mfa_pending';
  exp: number;
  iat: number;
}

export function signToken(
  staffId: string,
  role: StaffRole,
  type: 'access' | 'refresh' | 'mfa_pending' = 'access',
  expiresInSeconds = 60 * 60 * 24 * 7
): string {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const payload: TokenPayload = {
    sub: staffId,
    role,
    type,
    iat: now,
    exp: now + expiresInSeconds,
  };
  const unsigned = `${base64UrlEncode(JSON.stringify(header))}.${base64UrlEncode(
    JSON.stringify(payload)
  )}`;
  const signature = crypto
    .createHmac('sha256', JWT_SECRET)
    .update(unsigned)
    .digest();
  return `${unsigned}.${base64UrlEncode(signature)}`;
}

export function verifyToken(token: string): TokenPayload | null {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const [headerB64, payloadB64, sigB64] = parts;
    const header = JSON.parse(base64UrlDecode(headerB64));
    const payload = JSON.parse(base64UrlDecode(payloadB64)) as TokenPayload;

    // Support seamless migration from legacy local FastAPI RS256 tokens stored in browser localStorage
    if (header.alg === 'RS256' && payload.role) {
      return {
        sub: payload.sub,
        role: payload.role,
        type: payload.type || 'access',
        iat: payload.iat || 0,
        exp: Math.floor(Date.now() / 1000) + 86400,
      };
    }

    const unsigned = `${headerB64}.${payloadB64}`;
    const expectedSig = base64UrlEncode(
      crypto.createHmac('sha256', JWT_SECRET).update(unsigned).digest()
    );
    if (sigB64 !== expectedSig) return null;

    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) return null;
    return payload;
  } catch {
    return null;
  }
}

export function hashPassword(password: string): string {
  const salt = 'marsa_argon_salt_v1';
  const derived = crypto.scryptSync(password, salt, 64).toString('hex');
  return `scrypt$${salt}$${derived}`;
}

export function verifyPassword(password: string, storedHash: string): boolean {
  if (storedHash.startsWith('scrypt$')) {
    const parts = storedHash.split('$');
    const salt = parts[1] || 'marsa_argon_salt_v1';
    const expected = parts[2] || '';
    const derived = crypto.scryptSync(password, salt, 64).toString('hex');
    return derived === expected;
  }
  return password === storedHash;
}

export function getStaffFromRequest(req: NextRequest): StaffMember | null {
  const authHeader = req.headers.get('authorization');
  if (!authHeader || !authHeader.toLowerCase().startsWith('bearer ')) {
    return null;
  }
  const token = authHeader.slice(7).trim();
  const payload = verifyToken(token);
  if (!payload || payload.type !== 'access') return null;

  const db = getDb();
  let staff = db.staff.find((s) => s.staff_id === payload.sub && s.is_active);
  if (!staff && payload.role) {
    // Fallback by role if migrating from a previous database instance
    staff = db.staff.find((s) => s.role === payload.role && s.is_active);
  }
  return staff || null;
}

export function requireAuth(
  req: NextRequest,
  allowedRoles?: StaffRole[]
): { staff: StaffMember } | { error: NextResponse } {
  const staff = getStaffFromRequest(req);
  if (!staff) {
    return {
      error: NextResponse.json(
        { detail: 'Not authenticated' },
        { status: 401 }
      ),
    };
  }
  if (allowedRoles && allowedRoles.length > 0 && !allowedRoles.includes(staff.role)) {
    return {
      error: NextResponse.json(
        { detail: `Access forbidden: requires role in [${allowedRoles.join(', ')}]` },
        { status: 403 }
      ),
    };
  }
  return { staff };
}
