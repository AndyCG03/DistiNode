function required(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(`Falta la variable de entorno ${name}. Revisa .env (ver README).`);
  }
  return value;
}

/**
 * Todas se leen en tiempo de ejecución (no hay NEXT_PUBLIC_*): la misma imagen de Docker sirve para
 * cualquier dominio. Sin base de datos la app sigue funcionando: portada y demo.
 */
export function isAuthConfigured(): boolean {
  return Boolean(process.env.DATABASE_URL && process.env.BETTER_AUTH_SECRET);
}

export function isGoogleConfigured(): boolean {
  return Boolean(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET);
}

export function isLiveblocksConfigured(): boolean {
  return Boolean(process.env.LIVEBLOCKS_SECRET_KEY);
}

export function databaseUrl() {
  return required("DATABASE_URL", process.env.DATABASE_URL);
}

export function liveblocksSecret() {
  return required("LIVEBLOCKS_SECRET_KEY", process.env.LIVEBLOCKS_SECRET_KEY);
}

/** URL del servidor de Liveblocks para el servidor de Next (red interna de Docker). Vacío = nube de Liveblocks. */
export function liveblocksServerUrl(): string | undefined {
  return process.env.LIVEBLOCKS_BASE_URL || undefined;
}

/**
 * URL del servidor de Liveblocks para el navegador. Si no se fija, y hay servidor propio, se usa el mismo
 * origen de la página: Caddy envía los WebSocket /v7 y /v8 al contenedor de Liveblocks.
 */
export function liveblocksPublicUrl(requestOrigin: string): string | undefined {
  if (process.env.LIVEBLOCKS_PUBLIC_URL) return process.env.LIVEBLOCKS_PUBLIC_URL;
  return process.env.LIVEBLOCKS_BASE_URL ? requestOrigin : undefined;
}
