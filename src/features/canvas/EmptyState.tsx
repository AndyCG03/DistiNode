"use client";

import { useState } from "react";
import { LogoMark } from "@/components/Logo";
import { templateById, TEMPLATES } from "@/sim/templates";
import { TemplateButton, TemplateDialog, useLoadTemplate } from "./templates";

const FEATURED = ["tienda-online", "streaming-video", "microservicios", "alta-disponibilidad"];

export function EmptyState({ canLoad, canEdit }: { canLoad: boolean; canEdit: boolean }) {
  const load = useLoadTemplate();
  const [all, setAll] = useState(false);
  return (
    <div className="pointer-events-none absolute inset-0 z-10 grid place-items-center overflow-y-auto p-4 pb-28 sm:p-6">
      <div className="pointer-events-auto flex w-full max-w-2xl flex-col items-center text-center">
        <LogoMark size={56} />
        <h2 className="mt-4 text-xl font-bold">Un lienzo en blanco</h2>
        {canLoad ? (
          <>
            <p className="mt-1 text-gris-texto">
              {canEdit
                ? "Añade componentes, o empieza con un sistema hecho y dale al ▶."
                : "Carga un sistema y dale al ▶."}
            </p>
            <button type="button" className="btn btn-primario mt-5" onClick={() => load(TEMPLATES[0])}>
              Cargar ejemplo
            </button>
            <p className="mt-6 mb-2 text-sm font-semibold text-gris-texto">o parte de un sistema real</p>
            <ul className="grid w-full gap-2 text-left sm:grid-cols-2">
              {FEATURED.map((id) => templateById(id)!).map((t) => (
                <li key={t.id}>
                  <TemplateButton template={t} onPick={load} />
                </li>
              ))}
            </ul>
            <button
              type="button"
              className="mt-3 text-sm font-semibold text-verde underline-offset-4 hover:underline"
              onClick={() => setAll(true)}
            >
              Ver las {TEMPLATES.length} plantillas
            </button>
            <TemplateDialog open={all} onClose={() => setAll(false)} replacing={false} />
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
