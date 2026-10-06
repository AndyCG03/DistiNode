import { getSessionCookie } from "better-auth/cookies";
import { NextResponse, type NextRequest } from "next/server";

const PROTECTED = ["/salas", "/sala/"];

/**
 * Comprobación optimista: sin cookie de sesión, a /entrar. La comprobación real (sesión válida y membresía)
 * se hace en cada página y en /api/liveblocks-auth.
 */
export function proxy(request: NextRequest) {
  const path = request.nextUrl.pathname;
  const isProtected = PROTECTED.some((p) => path === p || path.startsWith(p));
  const authOn = Boolean(process.env.DATABASE_URL && process.env.BETTER_AUTH_SECRET);
  if (isProtected && authOn && !getSessionCookie(request)) {
    const login = request.nextUrl.clone();
    login.pathname = "/entrar";
    login.search = `?next=${encodeURIComponent(path)}`;
    return NextResponse.redirect(login);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/salas", "/sala/:path*"],
};
