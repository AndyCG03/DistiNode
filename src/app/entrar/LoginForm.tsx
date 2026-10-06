"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

type Status = { kind: "idle" } | { kind: "sending" } | { kind: "sent"; email: string } | { kind: "error"; message: string };

export function LoginForm({ next }: { next: string }) {
  const [status, setStatus] = useState<Status>({ kind: "idle" });
  const callback = () => `${window.location.origin}/auth/callback?next=${encodeURIComponent(next)}`;

  async function sendLink(formData: FormData) {
    const email = String(formData.get("email") ?? "").trim();
    if (!email) return;
    setStatus({ kind: "sending" });
    const { error } = await createClient().auth.signInWithOtp({
      email,
      options: { emailRedirectTo: callback() },
    });
    setStatus(
      error
        ? { kind: "error", message: "No se pudo enviar el enlace. Revisa el correo e inténtalo otra vez." }
        : { kind: "sent", email },
    );
  }

  async function google() {
    setStatus({ kind: "sending" });
    const { error } = await createClient().auth.signInWithOAuth({
      provider: "google",
      options: { redirectTo: callback() },
    });
    if (error) setStatus({ kind: "error", message: "No se pudo abrir Google. Inténtalo otra vez." });
  }

  if (status.kind === "sent") {
    return (
      <div className="panel mt-8 p-5" role="status">
        <p className="font-semibold">Revisa tu correo</p>
        <p className="mt-1 text-gris-texto">
          Enviamos un enlace a <span className="font-semibold text-tinta">{status.email}</span>. Ábrelo en este
          mismo navegador.
        </p>
        <button type="button" className="mt-4 text-sm font-semibold text-verde underline-offset-4 hover:underline" onClick={() => setStatus({ kind: "idle" })}>
          Usar otro correo
        </button>
      </div>
    );
  }

  const busy = status.kind === "sending";

  return (
    <div className="mt-8">
      <form action={sendLink} className="flex flex-col gap-3">
        <label htmlFor="email" className="text-sm font-semibold">
          Correo
        </label>
        <input
          id="email"
          name="email"
          type="email"
          required
          autoComplete="email"
          placeholder="tu@correo.com"
          className="campo"
        />
        <button type="submit" className="btn btn-primario" disabled={busy}>
          {busy ? "Enviando…" : "Enviarme el enlace"}
        </button>
      </form>
      <div className="my-6 flex items-center gap-3 text-sm text-gris-texto" aria-hidden="true">
        <span className="h-px flex-1 bg-linea" />o<span className="h-px flex-1 bg-linea" />
      </div>
      <button type="button" className="btn btn-borde w-full" onClick={google} disabled={busy}>
        <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true">
          <path fill="#FFC107" d="M43.6 20.5H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z" />
          <path fill="#FF3D00" d="m6.3 14.7 6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 7.9 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z" />
          <path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-8l-6.5 5C9.5 39.6 16.2 44 24 44z" />
          <path fill="#1976D2" d="M43.6 20.5H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.4-.4-3.5z" />
        </svg>
        Continuar con Google
      </button>
      {status.kind === "error" && (
        <p role="alert" className="mt-4 text-sm text-rojo">
          {status.message}
        </p>
      )}
    </div>
  );
}
