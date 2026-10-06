"use client";

import { LogoMark } from "@/components/Logo";
import { TEMPLATES } from "@/sim/templates";
import { TemplateButton, useLoadTemplate } from "./templates";

export function EmptyState({ canLoad, canEdit }: { canLoad: boolean; canEdit: boolean }) {
  const load = useLoadTemplate();
  return (
    <div className="pointer-events-none absolute inset-0 z-10 grid place-items-center overflow-y-auto p-6">
      <div className="pointer-events-auto flex w-full max-w-2xl flex-col items-center text-center">
        <LogoMark size={56} />
        <h2 className="mt-4 text-xl font-bold">Un lienzo en blanco</h2>
        {canLoad ? (
          <>
            <p className="mt-1 text-gris-texto">
              {canEdit
                ? "Arrastra componentes desde la izquierda, o empieza con un sistema hecho y dale al ▶."
                : "Carga un sistema y dale al ▶. Para diseñar el tuyo, ábrelo en un ordenador."}
            </p>
            <button type="button" className="btn btn-primario mt-5" onClick={() => load(TEMPLATES[0])}>
              Cargar ejemplo
            </button>
            <p className="mt-6 mb-2 text-sm font-semibold text-gris-texto">o elige una plantilla</p>
            <ul className="grid w-full gap-2 text-left sm:grid-cols-2">
              {TEMPLATES.slice(1).map((t) => (
                <li key={t.id}>
                  <TemplateButton template={t} onPick={load} />
                </li>
              ))}
            </ul>
          </>
        ) : (
          <p className="mt-1 text-gris-texto">
            Abre la sala en un ordenador para diseñar. Aquí verás lo que construya tu equipo.
          </p>
        )}
      </div>
    </div>
  );
}
