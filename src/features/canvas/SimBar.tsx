"use client";

import { useActions, useDiagramState } from "@/features/collab/context";
import { useEffect, useRef } from "react";
import { SIM_DEFAULTS } from "@/lib/liveblocks.config";
import { useHistory, useMetrics } from "./SimContext";
import { OVERLOAD_SECONDS } from "./Supervisor";

const fmt = new Intl.NumberFormat("es", { maximumFractionDigits: 0 });

/** Barra flotante: ▶/⏸, tráfico y métricas en vivo. */
export function SimBar({ readOnly, compact = false }: { readOnly: boolean; compact?: boolean }) {
  const sim = useDiagramState().sim;
  const { running, traffic } = sim;
  const opts = { ...SIM_DEFAULTS, ...sim };
  const { setRunning, setTraffic, setSimOptions, notify } = useActions();
  const m = useMetrics();
  const history = useHistory();
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
        series={history.map((h) => h.throughput)}
        color="var(--verde)"
        unit="/s"
      />
      <Metric
        label="latencia p95"
        value={`${fmt.format(m.p95LatencyMs)} ms`}
        title={`El 95 % de las respuestas tarda menos que esto (media: ${fmt.format(m.avgLatencyMs)} ms). Cuenta espera, proceso y red; el viaje lento de los trenes no.`}
        series={history.map((h) => h.p95)}
        color="var(--tinta)"
        unit=" ms"
      />
      <Metric
        label="errores"
        value={`${fmt.format(errorPct)} %`}
        title="Peticiones que terminaron en error (incluidos los tiempos de espera agotados), últimos 2 s"
        tone={errorPct >= 5 ? "text-rojo" : errorPct > 0 ? "text-ambar" : undefined}
        series={history.map((h) => h.errors * 100)}
        color="var(--rojo)"
        unit=" %"
        fixedMax={100}
      />
      {m.retryRate >= 0.5 && (
        <Metric
          label="reintentos"
          value={`${fmt.format(m.retryRate)}/s`}
          title="Reintentos de los clientes por segundo"
        />
      )}
      {(m.backlog > 0 || m.asyncThroughput > 0) && (
        <Metric
          label="en segundo plano"
          value={`${fmt.format(m.asyncThroughput)}/s · ${fmt.format(m.backlog)} en cola`}
          title="Mensajes procesados por los workers por segundo, y mensajes esperando en las colas"
        />
      )}
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

  const playButton = (
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
  );
  const trafficSlider = (
    <input
      type="range"
      className={compact ? "rango w-full" : "rango w-36 md:w-44"}
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
  );
  const faultToggles = (
    <>
      <Toggle
        on={opts.chaos}
        onChange={(v) => {
          setSimOptions({ chaos: v });
          notify(v ? "activó el modo caos" : "desactivó el modo caos");
        }}
        label="Caos"
        title="Caídas, lentitud y cortes de red al azar; lo caído vuelve solo tras unos segundos"
      />
      <Toggle
        on={opts.autoCrash}
        onChange={(v) => {
          setSimOptions({ autoCrash: v });
          notify(v ? "activó las caídas por sobrecarga" : "desactivó las caídas por sobrecarga");
        }}
        label={compact ? "Sobrecarga" : "Sobrecarga tumba"}
        title={`Un componente saturado más de ${OVERLOAD_SECONDS} s se cae y tarda ${opts.restartSec} s en reiniciar`}
      />
    </>
  );

  // Móvil: dos filas a todo el ancho, botones grandes, sin minigráficas.
  if (compact) {
    return (
      <div className="pointer-events-none absolute inset-x-2 bottom-2 z-20 pb-[env(safe-area-inset-bottom)]">
        <div
          className="pointer-events-auto flex flex-col gap-2 rounded-2xl border border-linea bg-papel p-2 shadow-flota"
          role="group"
          aria-label="Simulación"
        >
          <div className="flex items-center gap-3">
            {playButton}
            <label className="flex min-w-0 flex-1 items-center gap-2">
              <span className="sr-only">Tráfico</span>
              {trafficSlider}
            </label>
            <span className="cifras shrink-0 text-sm whitespace-nowrap text-gris-texto">{traffic} pet/s</span>
          </div>
          <div className="flex items-center justify-between gap-2 px-1">
            <dl className="cifras flex gap-3 text-sm">
              <Metric label="ok/s" value={fmt.format(m.throughput)} title="Respuestas correctas por segundo" />
              <Metric label="p95" value={`${fmt.format(m.p95LatencyMs)} ms`} title="Latencia p95" />
              <Metric
                label="errores"
                value={`${fmt.format(errorPct)} %`}
                title="Errores"
                tone={errorPct >= 5 ? "text-rojo" : errorPct > 0 ? "text-ambar" : undefined}
              />
            </dl>
            <div className="flex gap-1" role="group" aria-label="Fallos">
              {faultToggles}
            </div>
          </div>
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
        {playButton}

        <label className="flex items-center gap-3">
          <span className="text-sm font-semibold">Tráfico</span>
          {trafficSlider}
          <span className="cifras w-[4.5rem] text-sm whitespace-nowrap text-gris-texto">{traffic} pet/s</span>
        </label>

        <div className="border-l border-linea pl-5">{metrics}</div>

        <div className="flex items-center gap-1.5 border-l border-linea pl-4" role="group" aria-label="Fallos">
          {faultToggles}
        </div>
      </div>
    </div>
  );
}

function Metric({
  label,
  value,
  title,
  tone,
  series,
  color,
  unit = "",
  fixedMax,
}: {
  label: string;
  value: string;
  title: string;
  tone?: string;
  series?: number[];
  color?: string;
  unit?: string;
  fixedMax?: number;
}) {
  return (
    <div title={title} className="flex items-end gap-2 leading-tight">
      <div className="flex flex-col">
        <dt className="text-xs whitespace-nowrap text-gris-texto">{label}</dt>
        <dd className={`font-semibold whitespace-nowrap ${tone ?? ""}`}>{value}</dd>
      </div>
      {series && color && <Sparkline values={series} color={color} unit={unit} label={label} fixedMax={fixedMax} />}
    </div>
  );
}

/** Minigráfica del último minuto: una serie, línea de 2 px, sin ejes (el rótulo la nombra). */
function Sparkline({
  values,
  color,
  unit,
  label,
  fixedMax,
}: {
  values: number[];
  color: string;
  unit: string;
  label: string;
  fixedMax?: number;
}) {
  const w = 64;
  const h = 22;
  if (values.length < 2) return <span className="inline-block" style={{ width: w, height: h }} aria-hidden="true" />;
  const max = Math.max(fixedMax ?? 0, ...values, 1e-9);
  const step = w / (values.length - 1);
  const pts = values.map((v, i) => `${(i * step).toFixed(1)},${(h - 2 - (v / max) * (h - 4)).toFixed(1)}`).join(" ");
  const peak = Math.max(...values);
  return (
    <svg
      width={w}
      height={h}
      viewBox={`0 0 ${w} ${h}`}
      role="img"
      aria-label={`${label}, último minuto: máximo ${fmt.format(peak)}${unit}, ahora ${fmt.format(values[values.length - 1])}${unit}`}
      className="mb-0.5 hidden lg:block"
    >
      <line x1={0} y1={h - 1} x2={w} y2={h - 1} stroke="var(--linea)" strokeWidth={1} />
      <polyline points={pts} fill="none" stroke={color} strokeWidth={2} strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}

function Toggle({
  on,
  onChange,
  label,
  title,
}: {
  on: boolean;
  onChange: (v: boolean) => void;
  label: string;
  title: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      onClick={() => onChange(!on)}
      title={title}
      className={`flex h-8 items-center gap-1.5 rounded-full border px-2.5 text-xs font-semibold whitespace-nowrap ${
        on ? "border-rojo bg-rojo text-white" : "border-linea text-gris-texto hover:border-tinta hover:text-tinta"
      }`}
    >
      <span aria-hidden="true" className={`size-2 rounded-full ${on ? "bg-white" : "bg-gris"}`} />
      {label}
    </button>
  );
}
