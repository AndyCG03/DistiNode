"use client";

import type { ComponentKind } from "@/sim/components";
import { useNodeStats } from "./SimContext";

const fmt = new Intl.NumberFormat("es", { maximumFractionDigits: 0 });

const STATUS: Record<string, { label: string; className: string }> = {
  idle: { label: "En reposo", className: "text-gris-texto" },
  ok: { label: "Va sobrado", className: "text-verde" },
  warn: { label: "Cerca del límite", className: "text-ambar" },
  hot: { label: "Saturado", className: "text-rojo" },
  down: { label: "Caído", className: "text-rojo" },
};

/** Estadísticas en vivo del nodo seleccionado. */
export function NodeLiveStats({ id, kind }: { id: string; kind: ComponentKind }) {
  const s = useNodeStats(id);
  if (!s || kind === "client") return null;
  const status = STATUS[s.status];
  const capacity = (kind === "server" || kind === "database") && s.status !== "down";

  return (
    <section aria-label="En vivo" className="rounded-xl bg-fondo p-3">
      <p className={`text-sm font-semibold ${status.className}`}>{status.label}</p>
      <dl className="cifras mt-2 grid grid-cols-2 gap-x-3 gap-y-2 text-sm">
        <Row label="Llegan" value={`${fmt.format(s.arrivalRate)} pet/s`} />
        {capacity && <Row label="Carga" value={`${fmt.format(s.rho * 100)} %`} />}
        {capacity && <Row label="Cola" value={`${s.queue} / ${s.queueMax}`} />}
        {capacity && <Row label="Trabajando" value={`${s.busy} / ${s.workers}`} />}
        <Row label="Fallan" value={`${fmt.format(s.dropRate)} /s`} />
      </dl>
      {capacity && (
        <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-linea" aria-hidden="true">
          <div
            className={`h-full rounded-full transition-[width] ${s.status === "hot" ? "bg-rojo" : s.status === "warn" ? "bg-ambar" : "bg-verde"}`}
            style={{ width: `${Math.min(100, s.rho * 100)}%` }}
          />
        </div>
      )}
    </section>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs text-gris-texto">{label}</dt>
      <dd className="font-semibold">{value}</dd>
    </div>
  );
}
