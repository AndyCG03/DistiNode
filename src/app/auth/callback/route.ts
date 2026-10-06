import type { EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { isSupabaseConfigured } from "@/lib/env";
import { safeNext } from "@/lib/safe-next";

/**
 * Destino del enlace mágico y de Google.
 * - `?code=` (PKCE): Google y el enlace mágico con la plantilla por defecto.
 * - `?token_hash=&type=`: plantilla de correo personalizada (ver README); funciona en otro navegador.
 */
export async function GET(request: NextRequest) {
  const { searchParams, origin } = request.nextUrl;
  const next = safeNext(searchParams.get("next"));
  if (!isSupabaseConfigured()) return NextResponse.redirect(new URL("/entrar", origin));
  const code = searchParams.get("code");
  const tokenHash = searchParams.get("token_hash");
  const type = searchParams.get("type") as EmailOtpType | null;
  const supabase = await createClient();

  let ok = false;
  if (code) {
    ok = !(await supabase.auth.exchangeCodeForSession(code)).error;
  } else if (tokenHash && type) {
    ok = !(await supabase.auth.verifyOtp({ token_hash: tokenHash, type })).error;
  }

  const target = ok ? next : `/entrar?error=1&next=${encodeURIComponent(next)}`;
  return NextResponse.redirect(new URL(target, origin));
}
