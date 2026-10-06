/** Solo permite rutas internas para evitar redirecciones abiertas. */
export function safeNext(raw: string | null | undefined, fallback = "/salas"): string {
  if (!raw || !raw.startsWith("/") || raw.startsWith("//") || raw.startsWith("/\\")) return fallback;
  return raw;
}
