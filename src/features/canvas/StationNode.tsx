"use client";

import { Handle, Position, type Node, type NodeProps } from "@xyflow/react";
import { memo } from "react";
import { COMPONENTS, paramValue, type ComponentKind, type Params } from "@/sim/components";
import { HexIcon } from "./icons";

export const NODE_W = 184;
export const NODE_H = 60;

export type Selector = { name: string; color: string };
export type StationData = {
  label: string;
  kind: ComponentKind;
  down: boolean;
  params: Params;
  selectedBy: Selector[];
};
export type StationNodeType = Node<StationData, "station">;

function summary(kind: ComponentKind, params: Params): string {
  switch (kind) {
    case "server":
    case "database":
      return `${paramValue(kind, params, "capacity")} pet/s · cola ${paramValue(kind, params, "queueMax")}`;
    case "cache":
      return `${paramValue(kind, params, "hitRate")} % aciertos`;
    case "balancer":
      return "round-robin";
    case "client":
      return "genera tráfico";
  }
}

function StationNodeImpl({ data, selected }: NodeProps<StationNodeType>) {
  const { label, kind, down, params, selectedBy } = data;
  const other = selectedBy[0];

  return (
    <div
      className="station relative flex items-center gap-2.5 rounded-full border-[3.5px] bg-papel py-2 pr-4 pl-2"
      data-down={down || undefined}
      data-selected={selected || undefined}
      style={{
        width: NODE_W,
        height: NODE_H,
        boxShadow: other ? `0 0 0 3px var(--fondo), 0 0 0 6.5px ${other.color}` : undefined,
      }}
    >
      <Handle type="target" position={Position.Left} className="station-handle" aria-label={`Entrada de ${label}`} />
      <HexIcon kind={kind} size={38} className={down ? "text-gris" : "station-hex"} />
      <div className="min-w-0 leading-tight">
        <div className="truncate font-semibold">{label}</div>
        <div className="cifras truncate text-[0.8rem] text-gris-texto" data-stats-for={kind}>
          {down ? "Caído" : summary(kind, params)}
        </div>
      </div>
      <Handle type="source" position={Position.Right} className="station-handle" aria-label={`Salida de ${label}`} />
      {selectedBy.length > 0 && (
        <div className="absolute -top-7 left-4 flex gap-1" aria-label="Seleccionado por">
          {selectedBy.map((s) => (
            <span
              key={s.name + s.color}
              className="rounded-full px-2 py-0.5 text-[0.7rem] font-semibold whitespace-nowrap text-white"
              style={{ background: s.color }}
            >
              {s.name}
            </span>
          ))}
        </div>
      )}
      <span className="sr-only">{COMPONENTS[kind].name}</span>
    </div>
  );
}

export const StationNode = memo(StationNodeImpl);
