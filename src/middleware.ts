import { NextRequest, NextResponse } from 'next/server';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers':
    'Content-Type, Authorization, Accept, X-Requested-With, X-CSRF-Token',
  'Access-Control-Max-Age': '86400',
};

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // Block direct web access to /portal — portal is accessed via Flutter app only
  if (pathname === '/portal' || pathname.startsWith('/portal/')) {
    return NextResponse.redirect(new URL('/', req.url));
  }

  // Handle CORS preflight and attach CORS headers for all /api/* endpoints (used by Flutter app)
  if (pathname.startsWith('/api')) {
    if (req.method === 'OPTIONS') {
      return new NextResponse(null, {
        status: 204,
        headers: corsHeaders,
      });
    }

    const res = NextResponse.next();
    Object.entries(corsHeaders).forEach(([key, value]) => {
      res.headers.set(key, value);
    });
    return res;
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/api/:path*', '/portal', '/portal/:path*'],
};
