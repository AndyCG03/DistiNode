"use client";

import Link from "next/link";
import { useState } from "react";
import { LogoMark } from "@/components/Logo";
import { ThemeToggle } from "@/components/ThemeToggle";
import { PresenceBar } from "./PresenceBar";
import type { RoomInfo } from "./RoomView";

export function RoomHeader({ room, readOnly }: { room: RoomInfo; readOnly: boolean }) {
  const [copied, setCopied] = useState(false);

  async function copyLink() {
    try {
      await navigator.clipboard.writeText(`${window.location.origin}/sala/${room.code}`);
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    } catch {
      // sin portapapeles: el código sigue visible
    }
  }

  return (
    <header className="flex h-14 shrink-0 items-center gap-3 border-b border-linea bg-papel px-3 md:px-4">
      <Link href="/salas" className="flex items-center gap-2 rounded-md" aria-label="Volver a mis salas">
        <LogoMark size={28} />
      </Link>
      <span aria-hidden="true" className="text-linea">
        /
      </span>
      <h1 className="min-w-0 truncate font-semibold">{room.name}</h1>
      <button
        type="button"
        onClick={copyLink}
        className="cifras hidden items-center gap-1.5 rounded-md bg-verde-suave px-2 py-1 text-sm font-semibold tracking-[0.15em] text-verde hover:ring-1 hover:ring-verde sm:inline-flex"
        title="Copiar enlace de invitación"
      >
        {room.code}
        <span className="text-xs tracking-normal">{copied ? "¡copiado!" : "copiar enlace"}</span>
      </button>
      {readOnly && (
        <span className="rounded-full border border-linea px-2 py-0.5 text-xs text-gris-texto">Solo lectura en móvil</span>
      )}
      <div className="ml-auto flex items-center gap-2">
        <PresenceBar />
        <ThemeToggle />
      </div>
    </header>
  );
}
