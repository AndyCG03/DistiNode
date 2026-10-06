"use client";

import { useReactFlow } from "@xyflow/react";
import { useCallback, useEffect, useRef } from "react";
import { useActions } from "@/features/collab/context";
import { TEMPLATES, type Template } from "@/sim/templates";

/** Carga una plantilla, avisa a los demás y encuadra el lienzo. */
export function useLoadTemplate() {
  const actions = useActions();
  const flow = useReactFlow();
  return useCallback(
    (t: Template) => {
      actions.loadTemplate(t);
      actions.notify(`cargó la plantilla «${t.name}»`);
      setTimeout(() => flow.fitView({ padding: 0.25, duration: 400 }), 150);
    },
    [actions, flow],
  );
}

/** Miniatura de la plantilla como mapa de metro: líneas a 45° y estaciones. */
export function TemplatePreview({
  template,
  width = 132,
  height = 64,
}: {
  template: Template;
  width?: number;
  height?: number;
}) {
  const cols = Math.max(...template.nodes.map((n) => n.col)) || 1;
  const rows = Math.max(...template.nodes.map((n) => n.row)) || 0;
  const pad = 8;
  const x = (c: number) => pad + (c / cols) * (width - pad * 2);
  const y = (r: number) => (rows ? pad + (r / rows) * (height - pad * 2) : height / 2);
  const pos = new Map(template.nodes.map((n) => [n.key, { x: x(n.col), y: y(n.row) }]));
  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} aria-hidden="true" className="shrink-0">
      {template.edges.map(([a, b]) => {
        const p = pos.get(a)!;
        const q = pos.get(b)!;
        const dx = q.x - p.x;
        const dy = q.y - p.y;
        // tramo horizontal + diagonal, como las líneas del lienzo
        const h = Math.max(0, Math.abs(dx) - Math.abs(dy)) / 2;
        const mid1 = { x: p.x + Math.sign(dx) * h, y: p.y };
        const mid2 = { x: q.x - Math.sign(dx) * h, y: q.y };
        return (
          <polyline
            key={a + b}
            points={`${p.x},${p.y} ${mid1.x},${mid1.y} ${mid2.x},${mid2.y} ${q.x},${q.y}`}
            fill="none"
            stroke="var(--verde)"
            strokeWidth={2.5}
            strokeLinejoin="round"
            strokeLinecap="round"
          />
        );
      })}
      {template.nodes.map((n) => (
        <circle
          key={n.key}
          cx={x(n.col)}
          cy={y(n.row)}
          r={3.6}
          fill="var(--papel)"
          stroke="var(--tinta)"
          strokeWidth={1.8}
        />
      ))}
    </svg>
  );
}

export function TemplateButton({ template, onPick }: { template: Template; onPick: (t: Template) => void }) {
  return (
    <button
      type="button"
      onClick={() => onPick(template)}
      className="flex w-full items-center gap-3 rounded-xl border border-linea bg-papel p-2.5 text-left hover:border-verde"
    >
      <span className="rounded-lg bg-fondo p-1">
        <TemplatePreview template={template} />
      </span>
      <span className="min-w-0">
        <span className="block font-semibold">{template.name}</span>
        <span className="block text-sm leading-snug text-gris-texto">{template.summary}</span>
      </span>
    </button>
  );
}

/** Diálogo con todas las plantillas. Si el lienzo tiene algo, avisa de que se sustituye. */
export function TemplateDialog({
  open,
  onClose,
  replacing,
}: {
  open: boolean;
  onClose: () => void;
  replacing: boolean;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  const load = useLoadTemplate();

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);

  return (
    <dialog
      ref={ref}
      onClose={onClose}
      onClick={(e) => e.target === ref.current && onClose()}
      className="m-auto w-[min(640px,calc(100vw-32px))] rounded-2xl border border-linea bg-papel p-0 text-tinta shadow-flota backdrop:bg-black/40"
      aria-labelledby="plantillas-titulo"
    >
      <div className="flex items-start justify-between gap-4 border-b border-linea px-5 py-4">
        <div>
          <h2 id="plantillas-titulo" className="text-lg font-bold">
            Plantillas
          </h2>
          <p className="text-sm text-gris-texto">
            {replacing
              ? "Sustituyen el diagrama actual para todos los de la sala."
              : "Sistemas listos para darle al ▶."}
          </p>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="rounded-full px-2 py-1 text-gris-texto hover:text-tinta"
          aria-label="Cerrar"
        >
          ✕
        </button>
      </div>
      <ul className="grid max-h-[70vh] gap-2 overflow-y-auto p-4 sm:grid-cols-2">
        {TEMPLATES.map((t) => (
          <li key={t.id}>
            <TemplateButton
              template={t}
              onPick={(picked) => {
                load(picked);
                onClose();
              }}
            />
          </li>
        ))}
      </ul>
    </dialog>
  );
}
