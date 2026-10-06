"use client";

import { Handle, Position, type Node, type NodeProps } from "@xyflow/react";
import { memo } from "react";
import type { DownReason } from "@/lib/liveblocks.config";
import { COMPONENTS, hasCapacity, paramValue, type ComponentKind, type Params } from "@/sim/components";
import type { NodeStats } from "@/sim/types";
import { HexIcon } from "./icons";
import { useSecondsLeft } from "./Countdown";
import { useNodeStats } from "./SimContext";

export const NODE_W = 184;
export const NODE_H = 60;

export type Selector = { name: string; color: string };
export type StationData = {
  label: string;
  kind: ComponentKind;
  down: boolean;
  downUntil?: number | null;
  downReason?: DownReason | null;
  slow?: boolean;
  params: Params;
  selectedBy: Selector[];
};
export type StationNodeType = Node<StationData, "station">;

function summary(kind: ComponentKind, params: Params): string {
  const v = (k: Parameters<typeof paramValue>[2]) => paramValue(kind, params, k);
  switch (kind) {
    case "server":
    case "worker":
    case "database":
      return `${v("capacity")} pet/s · cola ${v("queueMax")}`;
    case "cache":
    case "cdn":
      return `${v("hitRate")} % aciertos`;
    case "balancer":
      return v("lbAlgorithm") === 1 ? "menos conexiones" : "por turnos";
    case "gateway":
      return `límite ${v("rateLimit")} pet/s`;
    case "queue":
      return `capacidad ${v("queueMax")} msj`;
    case "client":
      return v("retries") > 0 ? `${v("retries")} reintentos` : "genera tráfico";
  }
}

function liveSummary(kind: ComponentKind, s: NodeStats): string {
  const rate = `${Math.round(s.arrivalRate)} pet/s`;
  if (hasCapacity(kind)) return `${rate} · cola ${s.queue}/${s.queueMax}`;
  if (kind === "queue") return `${s.queue} en espera · ${s.busy} entregados`;
  if (kind === "client") return "enviando";
  if (s.dropRate > 0) return `${rate} · ${Math.round(s.dropRate)} rechazadas`;
  return rate;
}

const REASON: Record<DownReason, string> = {
  manual: "Caído",
  caos: "Caído (caos)",
  sobrecarga: "Caído por sobrecarga",
};

function StationNodeImpl({ id, data, selected }: NodeProps<StationNodeType>) {
  const { label, kind, down, downUntil, downReason, slow, params, selectedBy } = data;
  const other = selectedBy[0];
  const stats = useNodeStats(id);
  const secondsLeft = useSecondsLeft(down ? downUntil : null);
  const live = stats && stats.status !== "idle" && !down;
  const status = live ? stats.status : undefined;

  let line: string;
  if (down) line = secondsLeft !== null ? `Reiniciando… ${secondsLeft} s` : REASON[downReason ?? "manual"];
  else if (live) line = liveSummary(kind, stats);
  else line = summary(kind, params);

  return (
    <div
      className="station relative flex items-center gap-2.5 rounded-full border-[3.5px] bg-papel py-2 pr-4 pl-2"
      data-down={down || undefined}
      data-status={status}
      data-slow={(slow && !down) || undefined}
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
        <div className={`cifras truncate text-[0.8rem] ${down ? "text-rojo" : "text-gris-texto"}`}>{line}</div>
      </div>
      <Handle type="source" position={Position.Right} className="station-handle" aria-label={`Salida de ${label}`} />
      {slow && !down && (
        <span className="absolute -right-1 -bottom-2 rounded-full border-2 border-papel bg-ambar px-1.5 text-[0.65rem] font-bold text-white">
          lento
        </span>
      )}
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
      <span className="sr-only">
        {COMPONENTS[kind].name}
        {slow ? ", degradado" : ""}
      </span>
    </div>
  );
}

export const StationNode = memo(StationNodeImpl);
