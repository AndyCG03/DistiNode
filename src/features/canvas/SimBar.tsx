"use client";

import { useStorage } from "@liveblocks/react/suspense";
import { useEffect, useRef } from "react";
import { useMetrics } from "./SimContext";
import { useDiagram, useNotify } from "./useDiagram";

const fmt = new Intl.NumberFormat("es", { maximumFractionDigits: 0 });

/** Barra flotante: ▶/⏸, tráfico y métricas en vivo. */
export function SimBar({ readOnly }: { readOnly: boolean }) {
  const running = useStorage((root) => root.sim.running);
  const traffic = useStorage((root) => root.sim.traffic);
  const { setRunning, setTraffic } = useDiagram();
  const notify = useNotify();
  const m = useMetrics();
  const lastTraffic = useRef(traffic);

  const toggle = () => {
    setRunning(!running);
    notify(running ? "pausó la simulación" : "puso en marcha la simulación");
  };
  const toggleRef = useRef(toggle);
  useEffect(() => {
    toggleRef.current = toggle;
  });

  // Espacio = ▶/⏸, salvo cuando se escribe o se pulsa un control.
  useEffect(() => {
    if (readOnly) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.code !== "Space" || e.repeat || e.ctrlKey || e.metaKey || e.altKey) return;
      const el = e.target as HTMLElement | null;
      if (el?.closest("input, textarea, select, button, a, [contenteditable='true'], [role='slider']")) return;
      e.preventDefault();
      toggleRef.current();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [readOnly]);

  function commitTraffic() {
    if (lastTraffic.current !== traffic) {
      lastTraffic.current = traffic;
      notify(`puso el tráfico a ${traffic} pet/s`);
    }
  }

  const errorPct = m.errorRate * 100;
  const metrics = (
    <dl className="cifras flex items-center gap-4 text-sm" aria-live="off">
      <Metric
        label="completadas"
        value={`${fmt.format(m.throughput)}/s`}
        title="Respuestas correctas que llegan a los clientes por segundo"
      />
      <Metric
        label="latencia"
        value={`${fmt.format(m.avgLatencyMs)} ms`}
        title="Media de espera y proceso en los componentes; el viaje por las líneas no cuenta"
      />
      <Metric
        label="errores"
        value={`${fmt.format(errorPct)} %`}
        title="Porcentaje de peticiones que fallaron en los últimos 2 s"
        tone={errorPct >= 5 ? "text-rojo" : errorPct > 0 ? "text-ambar" : undefined}
      />
    </dl>
  );

  // En móvil solo se mira: estado y métricas, sin controles.
  if (readOnly) {
    return (
      <div className="pointer-events-none absolute inset-x-0 bottom-3 z-20 flex justify-center px-3">
        <div className="flex items-center gap-4 rounded-2xl border border-linea bg-papel px-4 py-2 shadow-flota">
          <span className="flex items-center gap-1.5 text-sm font-semibold">
            <span aria-hidden="true" className={`size-2.5 rounded-full ${running ? "bg-verde" : "bg-gris"}`} />
            {running ? "En marcha" : "En pausa"}
          </span>
          {metrics}
        </div>
      </div>
    );
  }

  return (
    <div className="pointer-events-none absolute inset-x-0 bottom-4 z-20 flex justify-center px-4">
      <div
        className="pointer-events-auto flex max-w-full flex-wrap items-center gap-x-5 gap-y-2 rounded-2xl border border-linea bg-papel py-2 pr-5 pl-2 shadow-flota"
        role="group"
        aria-label="Simulación"
      >
        <button
          type="button"
          onClick={toggle}
          disabled={readOnly}
          aria-pressed={running}
          aria-keyshortcuts="Space"
          title={running ? "Pausar (Espacio)" : "Poner en marcha (Espacio)"}
          className="grid size-11 shrink-0 place-items-center rounded-full bg-verde text-sobre-verde hover:bg-verde-fuerte disabled:opacity-60"
        >
          {running ? (
            <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
              <rect x="3" y="2" width="3.5" height="12" rx="1" fill="currentColor" />
              <rect x="9.5" y="2" width="3.5" height="12" rx="1" fill="currentColor" />
            </svg>
          ) : (
            <svg width="16" height="16" viewBox="0 0 16 16" aria-hidden="true">
              <path d="M4 2.5v11a1 1 0 0 0 1.5.86l9-5.5a1 1 0 0 0 0-1.72l-9-5.5A1 1 0 0 0 4 2.5Z" fill="currentColor" />
            </svg>
          )}
          <span className="sr-only">{running ? "Pausar" : "Poner en marcha"}</span>
        </button>

        <label className="flex items-center gap-3">
          <span className="text-sm font-semibold">Tráfico</span>
          <input
            type="range"
            className="rango w-36 md:w-44"
            min={1}
            max={200}
            step={1}
            value={traffic}
            disabled={readOnly}
            onChange={(e) => setTraffic(Number(e.target.value))}
            onPointerUp={commitTraffic}
            onKeyUp={commitTraffic}
            aria-valuetext={`${traffic} peticiones por segundo`}
          />
          <span className="cifras w-[4.5rem] text-sm whitespace-nowrap text-gris-texto">{traffic} pet/s</span>
        </label>

        <div className="border-l border-linea pl-5">{metrics}</div>
      </div>
    </div>
  );
}

function Metric({ label, value, title, tone }: { label: string; value: string; title: string; tone?: string }) {
  return (
    <div title={title} className="flex flex-col leading-tight">
      <dt className="text-xs text-gris-texto">{label}</dt>
      <dd className={`font-semibold ${tone ?? ""}`}>{value}</dd>
    </div>
  );
}
