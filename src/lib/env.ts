function required(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(`Falta la variable de entorno ${name}. Copia .env.example a .env.local y rellénala (ver README).`);
  }
  return value;
}

// Las NEXT_PUBLIC_* deben leerse de forma literal para que Next las incruste en el cliente.
export function supabaseEnv() {
  return {
    url: required("NEXT_PUBLIC_SUPABASE_URL", process.env.NEXT_PUBLIC_SUPABASE_URL),
    key: required("NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY),
  };
}

/** Sin Supabase la app sigue funcionando: portada y demo; entrar y salas muestran un aviso. */
export function isSupabaseConfigured(): boolean {
  return Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY);
}

/** Solo en el servidor. */
export function isLiveblocksConfigured(): boolean {
  return Boolean(process.env.LIVEBLOCKS_SECRET_KEY);
}

export function liveblocksSecret() {
  return required("LIVEBLOCKS_SECRET_KEY", process.env.LIVEBLOCKS_SECRET_KEY);
}
