"use client";

import { useReactFlow } from "@xyflow/react";
import Link from "next/link";
import { useState } from "react";
import { useDiagramState } from "@/features/collab/context";
import { COMPONENTS, COMPONENT_ORDER, GROUPS, type ComponentKind } from "@/sim/components";
import { TemplateDialog } from "./templates";
import { HexIcon } from "./icons";
import { NODE_H, NODE_W } from "./StationNode";
import { useActions } from "@/features/collab/context";

export const DND_TYPE = "application/x-distinode-componente";

export function Palette() {
  const { addNode, notify } = useActions();
  const { nodes } = useDiagramState();
  const [templatesOpen, setTemplatesOpen] = useState(false);
  const flow = useReactFlow();

  /** Con teclado o clic: lo coloca en el centro de la vista. */
  function addAtCenter(kind: ComponentKind) {
    const pane = document.querySelector(".react-flow")?.getBoundingClientRect();
    if (!pane) return;
    const jitter = () => (Math.random() - 0.5) * 60;
    const p = flow.screenToFlowPosition({ x: pane.left + pane.width / 2, y: pane.top + pane.height / 2 });
    const { label } = addNode(kind, p.x - NODE_W / 2 + jitter(), p.y - NODE_H / 2 + jitter());
    notify(`añadió ${label}`);
  }

  return (
    <aside className="flex w-52 shrink-0 flex-col border-r border-linea bg-papel" aria-labelledby="paleta">
      <div className="px-4 pt-3 pb-1">
        <h2 id="paleta" className="font-semibold">
          Componentes
        </h2>
        <p className="text-sm text-gris-texto">Arrástralos al lienzo.</p>
      </div>
      {GROUPS.map((group) => (
        <section key={group} aria-label={group} className="px-2 pt-2">
          <h3 className="px-2 pb-0.5 text-xs font-semibold text-gris-texto">{group}</h3>
          <ul className="flex flex-col">
            {COMPONENT_ORDER.filter((k) => COMPONENTS[k].group === group).map((kind) => {
              const spec = COMPONENTS[kind];
              const tipId = `tip-${kind}`;
              return (
                <li key={kind} className="group relative">
                  <button
                    type="button"
                    draggable
                    onDragStart={(e) => {
                      e.dataTransfer.setData(DND_TYPE, kind);
                      e.dataTransfer.effectAllowed = "move";
                    }}
                    onClick={() => addAtCenter(kind)}
                    aria-describedby={tipId}
                    className="flex w-full cursor-grab items-center gap-2.5 rounded-lg px-2 py-1.5 text-left hover:bg-verde-suave active:cursor-grabbing"
                  >
                    <HexIcon kind={kind} size={30} className="text-verde" />
                    <span className="font-semibold">{spec.name}</span>
                  </button>
                  <span
                    id={tipId}
                    role="tooltip"
                    className="pointer-events-none absolute top-1/2 left-[calc(100%+10px)] z-50 w-56 -translate-y-1/2 rounded-lg bg-tinta px-3 py-2 text-sm text-papel opacity-0 shadow-flota transition-opacity group-focus-within:opacity-100 group-hover:opacity-100"
                  >
                    {spec.tooltip}
                  </span>
                </li>
              );
            })}
          </ul>
        </section>
      ))}
      <div className="px-3 pt-3">
        <button type="button" className="btn btn-borde h-9 w-full text-sm" onClick={() => setTemplatesOpen(true)}>
          Plantillas…
        </button>
      </div>
      <p className="mt-auto px-4 pt-3 pb-4 text-xs leading-relaxed text-gris-texto">
        Une la salida <span aria-hidden="true">●</span> derecha de una estación con la entrada izquierda de otra.
        <br />
        <kbd className="font-semibold">Espacio</kbd> ▶/⏸ · <kbd className="font-semibold">Supr</kbd> borra ·{" "}
        <Link href="/guia" target="_blank" className="font-semibold text-verde underline-offset-2 hover:underline">
          Guía
        </Link>
      </p>
      <TemplateDialog
        open={templatesOpen}
        onClose={() => setTemplatesOpen(false)}
        replacing={Object.keys(nodes).length > 0}
      />
    </aside>
  );
}
