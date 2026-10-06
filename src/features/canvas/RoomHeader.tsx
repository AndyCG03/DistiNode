"use client";

import Link from "next/link";
import { useState } from "react";
import { LogoMark } from "@/components/Logo";
import { ThemeToggle } from "@/components/ThemeToggle";
import { PresenceBar } from "./PresenceBar";
import { ProjectMenu } from "./ProjectMenu";
import type { RoomInfo } from "./RoomView";

/** `room` null = modo demo (solo en este navegador). */
export function RoomHeader({ room, compact }: { room: RoomInfo | null; compact: boolean }) {
  const [copied, setCopied] = useState(false);

  async function copyLink() {
    if (!room) return;
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
      <Link
        href={room ? "/salas" : "/"}
        className="flex items-center gap-2 rounded-md"
        aria-label={room ? "Volver a mis salas" : "Volver al inicio"}
      >
        <LogoMark size={28} />
      </Link>
      <span aria-hidden="true" className="text-linea">
        /
      </span>
      <h1 className="min-w-0 truncate font-semibold">{room ? room.name : "Demo"}</h1>
      {!room && (
        <span className="hidden shrink-0 rounded-full bg-verde-suave px-2 py-0.5 text-xs font-semibold whitespace-nowrap text-verde sm:inline">
          Se guarda solo en este navegador
        </span>
      )}
      {room && (
        <button
          type="button"
          onClick={copyLink}
          className="cifras hidden items-center gap-1.5 rounded-md bg-verde-suave px-2 py-1 text-sm font-semibold tracking-[0.15em] text-verde hover:ring-1 hover:ring-verde sm:inline-flex"
          title="Copiar enlace de invitación"
        >
          {room.code}
          <span className="text-xs tracking-normal">{copied ? "¡copiado!" : "copiar enlace"}</span>
        </button>
      )}
      <div className="ml-auto flex items-center gap-1 sm:gap-2">
        <ProjectMenu name={room ? room.name : "Demo"} compact={compact} />
        <Link
          href="/guia"
          target="_blank"
          className="hidden rounded-full px-3 py-1.5 text-sm font-semibold text-gris-texto hover:bg-verde-suave hover:text-tinta sm:block"
        >
          Guía
        </Link>
        <PresenceBar />
        <ThemeToggle />
      </div>
    </header>
  );
}
