"use client";

import { useActions, useDiagramState } from "@/features/collab/context";
import { COMPONENTS, paramValue, type ParamSpec } from "@/sim/components";
import { HexIcon } from "./icons";
import type { Selection } from "./RoomView";
import { NodeLiveStats } from "./NodeLiveStats";

export function PropertiesPanel({ selection, onClear }: { selection: Selection; onClear: () => void }) {
  const nodeId = selection.nodes.length === 1 && selection.edges.length === 0 ? selection.nodes[0] : null;
  const edgeId = selection.edges.length === 1 && selection.nodes.length === 0 ? selection.edges[0] : null;
  const { nodes, edges } = useDiagramState();
  const node = nodeId ? (nodes[nodeId] ?? null) : null;
  const edge = edgeId ? (edges[edgeId] ?? null) : null;
  const edgeLabels = edge ? [nodes[edge.source]?.label ?? "?", nodes[edge.target]?.label ?? "?"] : null;
  const diagram = useActions();
  const notify = diagram.notify;

  if (!node && !edge) return null;

  return (
    <aside
      className="flex w-72 shrink-0 flex-col overflow-y-auto border-l border-linea bg-papel"
      aria-label="Propiedades"
    >
      {node && (
        <div className="flex flex-col gap-5 p-4">
          <div className="flex items-center gap-3">
            <HexIcon kind={node.kind} size={40} className={node.down ? "text-gris" : "text-verde"} />
            <div className="min-w-0">
              <p className="text-sm text-gris-texto">{COMPONENTS[node.kind].name}</p>
              <p className="truncate font-semibold">{node.label}</p>
            </div>
          </div>

          <label className="flex flex-col gap-1.5">
            <span className="text-sm font-semibold">Nombre</span>
            <input
              className="campo h-10"
              value={node.label}
              maxLength={40}
              onChange={(e) => diagram.setLabel(node.id, e.target.value)}
            />
          </label>

          {COMPONENTS[node.kind].params.map((spec) => (
            <ParamField
              key={spec.key}
              spec={spec}
              value={paramValue(node.kind, node.params, spec.key)}
              onChange={(v) => diagram.setParam(node.id, spec.key, v)}
            />
          ))}

          <NodeLiveStats id={node.id} kind={node.kind} />

          <div className="flex flex-col gap-2 border-t border-linea pt-4">
            <button
              type="button"
              className={`btn h-10 ${node.down ? "btn-primario" : "btn-borde text-rojo hover:!border-rojo"}`}
              onClick={() => {
                diagram.setDown(node.id, !node.down);
                notify(`${node.down ? "revivió" : "tumbó"} ${node.label}`);
              }}
            >
              {node.down ? "Revivir" : "Tumbar"}
            </button>
            <button
              type="button"
              className="h-9 rounded-full text-sm font-semibold text-gris-texto hover:text-rojo"
              onClick={() => {
                diagram.removeElements([node.id], []);
                notify(`borró ${node.label}`);
                onClear();
              }}
            >
              Borrar componente
            </button>
          </div>
        </div>
      )}
      {edge && edgeLabels && (
        <div className="flex flex-col gap-4 p-4">
          <div>
            <p className="text-sm text-gris-texto">Conexión</p>
            <p className="font-semibold">
              {edgeLabels[0]} → {edgeLabels[1]}
            </p>
          </div>
          <p className="text-sm text-gris-texto">
            Las peticiones van en el sentido de la flecha; las respuestas vuelven por la misma línea.
          </p>
          <button
            type="button"
            className="btn btn-borde h-10 text-rojo hover:!border-rojo"
            onClick={() => {
              diagram.removeElements([], [edge.id]);
              onClear();
            }}
          >
            Borrar conexión
          </button>
        </div>
      )}
    </aside>
  );
}

function ParamField({ spec, value, onChange }: { spec: ParamSpec; value: number; onChange: (v: number) => void }) {
  const id = `param-${spec.key}`;
  const clamp = (v: number) => Math.min(spec.max, Math.max(spec.min, v));
  return (
    <div className="flex flex-col gap-1.5">
      <div className="flex items-baseline justify-between gap-2">
        <label htmlFor={id} className="text-sm font-semibold">
          {spec.label}
        </label>
        <span className="flex items-baseline gap-1">
          <input
            type="number"
            aria-label={`${spec.label} (${spec.unit})`}
            className="cifras w-16 rounded-md border border-linea bg-papel px-1.5 py-0.5 text-right text-sm"
            min={spec.min}
            max={spec.max}
            step={spec.step}
            value={value}
            onChange={(e) => {
              const v = Number(e.target.value);
              if (Number.isFinite(v)) onChange(clamp(v));
            }}
          />
          <span className="text-xs text-gris-texto">{spec.unit}</span>
        </span>
      </div>
      <input
        id={id}
        type="range"
        className="rango"
        min={spec.min}
        max={Math.min(spec.max, rangeMax(spec))}
        step={spec.step}
        value={value}
        onChange={(e) => onChange(clamp(Number(e.target.value)))}
        aria-describedby={`${id}-help`}
      />
      <p id={`${id}-help`} className="text-xs text-gris-texto">
        {spec.help}
      </p>
    </div>
  );
}

/** El deslizador cubre el rango útil; el campo numérico permite ir más allá. */
function rangeMax(spec: ParamSpec) {
  if (spec.key === "capacity") return 300;
  if (spec.key === "processingMs") return 500;
  if (spec.key === "queueMax") return 200;
  return spec.max;
}
