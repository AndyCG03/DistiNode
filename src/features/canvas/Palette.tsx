"use client";

import { useReactFlow } from "@xyflow/react";
import { COMPONENTS, COMPONENT_ORDER, type ComponentKind } from "@/sim/components";
import { HexIcon } from "./icons";
import { NODE_H, NODE_W } from "./StationNode";
import { useDiagram, useNotify } from "./useDiagram";

export const DND_TYPE = "application/x-nodos-componente";

export function Palette() {
  const { addNode } = useDiagram();
  const notify = useNotify();
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
      <div className="px-4 pt-4 pb-2">
        <h2 id="paleta" className="font-semibold">
          Componentes
        </h2>
        <p className="mt-0.5 text-sm text-gris-texto">Arrástralos al lienzo.</p>
      </div>
      <ul className="flex flex-col gap-1 px-2">
        {COMPONENT_ORDER.map((kind) => {
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
                className="flex w-full cursor-grab items-center gap-3 rounded-lg px-2 py-2 text-left hover:bg-verde-suave active:cursor-grabbing"
              >
                <HexIcon kind={kind} size={34} className="text-verde" />
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
      <p className="mt-auto px-4 pb-4 text-xs leading-relaxed text-gris-texto">
        Une la salida <span aria-hidden="true">●</span> derecha de una estación con la entrada izquierda de otra.
        <br />
        <kbd className="font-semibold">Espacio</kbd> ▶/⏸ · <kbd className="font-semibold">Supr</kbd> borra
      </p>
    </aside>
  );
}
