import { NextResponse, type NextRequest } from "next/server";
import { getAuth } from "@/lib/auth";
import { isAuthConfigured } from "@/lib/env";

export async function POST(request: NextRequest) {
  const response = NextResponse.redirect(new URL("/", request.nextUrl.origin), { status: 303 });
  if (!isAuthConfigured()) return response;
  const res = await getAuth().api.signOut({ headers: request.headers, asResponse: true });
  // Copia las cookies que borra Better Auth.
  for (const cookie of res.headers.getSetCookie()) response.headers.append("set-cookie", cookie);
  return response;
}
