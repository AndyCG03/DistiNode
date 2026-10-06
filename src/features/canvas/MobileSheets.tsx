"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useDiagramState } from "@/features/collab/context";
import { COMPONENTS, COMPONENT_ORDER, GROUPS } from "@/sim/components";
import { HexIcon } from "./icons";
import { useAddAtCenter } from "./Palette";
import { TemplateDialog } from "./templates";

/** Hoja inferior para el móvil. Se cierra con el botón, con Escape o tocando fuera. */
export function BottomSheet({
  label,
  onClose,
  children,
}: {
  label: string;
  onClose: () => void;
  children: React.ReactNode;
}) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="absolute inset-0 z-40 flex flex-col justify-end" role="dialog" aria-label={label}>
      <button type="button" aria-label="Cerrar" className="flex-1 bg-black/25" onClick={onClose} />
      <div className="max-h-[65vh] overflow-y-auto rounded-t-2xl border-t border-linea bg-papel pb-[env(safe-area-inset-bottom)] shadow-flota motion-safe:animate-[hoja_180ms_ease-out]">
        <div className="sticky top-0 z-10 flex items-center justify-between bg-papel px-4 pt-2 pb-1">
          <span
            aria-hidden="true"
            className="absolute top-1.5 left-1/2 h-1 w-10 -translate-x-1/2 rounded-full bg-linea"
          />
          <h2 className="pt-2 font-semibold">{label}</h2>
          <button
            type="button"
            onClick={onClose}
            className="mt-1 grid size-9 place-items-center rounded-full text-gris-texto hover:bg-verde-suave"
            aria-label="Cerrar"
          >
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

/** Botón flotante "+" y hoja con los componentes, para añadir desde el móvil. */
export function MobileAdd({ onAdded }: { onAdded: (id: string) => void }) {
  const [open, setOpen] = useState(false);
  const [templates, setTemplates] = useState(false);
  const addAtCenter = useAddAtCenter();
  const { nodes } = useDiagramState();

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="absolute right-4 bottom-32 z-30 grid size-14 place-items-center rounded-full bg-verde text-sobre-verde shadow-flota active:scale-95"
        aria-label="Añadir componente"
      >
        <svg width="26" height="26" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M12 5v14M5 12h14" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" />
        </svg>
      </button>
      {open && (
        <BottomSheet label="Añadir componente" onClose={() => setOpen(false)}>
          {GROUPS.map((group) => (
            <section key={group} aria-label={group} className="px-3 pb-2">
              <h3 className="px-1 pt-2 pb-1 text-xs font-semibold text-gris-texto">{group}</h3>
              <ul className="grid grid-cols-3 gap-2">
                {COMPONENT_ORDER.filter((k) => COMPONENTS[k].group === group).map((kind) => (
                  <li key={kind}>
                    <button
                      type="button"
                      onClick={() => {
                        const id = addAtCenter(kind);
                        setOpen(false);
                        if (id) onAdded(id);
                      }}
                      className="flex h-24 w-full flex-col items-center justify-center gap-1.5 rounded-xl border border-linea px-1 text-center active:bg-verde-suave"
                    >
                      <HexIcon kind={kind} size={36} className="text-verde" />
                      <span className="text-sm leading-tight font-semibold">{COMPONENTS[kind].name}</span>
                    </button>
                  </li>
                ))}
              </ul>
            </section>
          ))}
          <div className="flex gap-2 px-4 pt-2 pb-4">
            <button
              type="button"
              className="btn btn-borde h-11 flex-1 text-sm"
              onClick={() => {
                setOpen(false);
                setTemplates(true);
              }}
            >
              Plantillas…
            </button>
            <Link href="/guia" className="btn btn-borde h-11 flex-1 text-sm">
              Guía
            </Link>
          </div>
        </BottomSheet>
      )}
      <TemplateDialog open={templates} onClose={() => setTemplates(false)} replacing={Object.keys(nodes).length > 0} />
    </>
  );
}
