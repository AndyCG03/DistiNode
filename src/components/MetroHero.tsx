import type { CSSProperties } from "react";

const ROUTE_A = "M40 150 H220 L290 80 H390 L460 150 H520";
const ROUTE_B = "M40 150 H220 L290 220 H390 L460 150 H520";

const trains: { route: string; delay: number; back?: boolean }[] = [
  { route: ROUTE_A, delay: 0 },
  { route: ROUTE_B, delay: -0.8 },
  { route: ROUTE_A, delay: -1.6 },
  { route: ROUTE_B, delay: -2.4 },
  { route: ROUTE_A, delay: -0.4, back: true },
  { route: ROUTE_B, delay: -2, back: true },
];

const stations = [
  { x: 40, y: 150, label: "Cliente", dy: 34 },
  { x: 180, y: 150, label: "Balanceador", dy: 34 },
  { x: 340, y: 80, label: "Servidor 1", dy: -22 },
  { x: 340, y: 220, label: "Servidor 2", dy: 34 },
  { x: 520, y: 150, label: "Base de datos", dy: 34 },
];

/** Ilustración de portada: un mini mapa de metro con tráfico. Decorativa. */
export function MetroHero() {
  return (
    <svg
      viewBox="0 0 560 290"
      className="h-auto w-full"
      role="img"
      aria-label="Un cliente envía peticiones a través de un balanceador hacia dos servidores y una base de datos"
    >
      <g fill="none" stroke="var(--verde)" strokeWidth="8" strokeLinecap="round" strokeLinejoin="round">
        <path d={ROUTE_A} />
        <path d={ROUTE_B} />
      </g>
      {trains.map((t, i) => (
        <rect
          key={i}
          className={t.back ? "tren tren-vuelta" : "tren"}
          x={-10}
          y={-4}
          width={20}
          height={8}
          rx={4}
          fill={t.back ? "var(--gris-tren)" : "var(--papel)"}
          stroke={t.back ? "none" : "var(--verde-fuerte)"}
          strokeWidth={1.5}
          style={{ offsetPath: `path("${t.route}")`, animationDelay: `${t.delay}s` } as CSSProperties}
        />
      ))}
      {stations.map((s) => (
        <g key={s.label}>
          <circle cx={s.x} cy={s.y} r={13} fill="var(--papel)" stroke="var(--tinta)" strokeWidth={5} />
          <text x={s.x} y={s.y + s.dy} textAnchor="middle" fontSize="15" fontWeight={600} fill="var(--tinta)">
            {s.label}
          </text>
        </g>
      ))}
    </svg>
  );
}
