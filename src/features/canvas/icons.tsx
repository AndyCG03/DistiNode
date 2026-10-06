import type { ComponentKind } from "@/sim/components";

const paths: Record<ComponentKind, React.ReactNode> = {
  client: (
    <>
      <rect x="4" y="5" width="16" height="11" rx="2" />
      <path d="M2.5 19h19" />
    </>
  ),
  balancer: (
    <>
      <path d="M3 12h6" />
      <path d="M9 12c3 0 4-6 7-6h4" />
      <path d="M9 12h11" />
      <path d="M9 12c3 0 4 6 7 6h4" />
    </>
  ),
  server: (
    <>
      <rect x="4" y="4" width="16" height="7" rx="2" />
      <rect x="4" y="13" width="16" height="7" rx="2" />
      <path d="M8 7.5h.01M8 16.5h.01" strokeWidth="3" />
    </>
  ),
  cache: <path d="M13 3 5 13.5h6L10 21l8-10.5h-6L13 3Z" />,
  cdn: (
    <>
      <circle cx="12" cy="12" r="8.5" />
      <path d="M3.5 12h17" />
      <path d="M12 3.5c2.5 2.6 3.6 5.5 3.6 8.5s-1.1 5.9-3.6 8.5c-2.5-2.6-3.6-5.5-3.6-8.5s1.1-5.9 3.6-8.5Z" />
    </>
  ),
  gateway: (
    <>
      <path d="M12 3 4.5 6v5.5c0 4.6 3.1 8 7.5 9.5 4.4-1.5 7.5-4.9 7.5-9.5V6L12 3Z" />
      <path d="M9 12h6M12 9v6" />
    </>
  ),
  worker: (
    <>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 3v2.5M12 18.5V21M3 12h2.5M18.5 12H21M5.6 5.6l1.8 1.8M16.6 16.6l1.8 1.8M5.6 18.4l1.8-1.8M16.6 7.4l1.8-1.8" />
    </>
  ),
  queue: (
    <>
      <rect x="3.5" y="5" width="4" height="14" rx="1.2" />
      <rect x="10" y="5" width="4" height="14" rx="1.2" />
      <path d="M17 12h4M19 10l2 2-2 2" />
    </>
  ),
  database: (
    <>
      <ellipse cx="12" cy="5.5" rx="7" ry="2.5" />
      <path d="M5 5.5v13c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5v-13" />
      <path d="M5 12c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5" />
    </>
  ),
};

export function ComponentIcon({ kind, size = 18 }: { kind: ComponentKind; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      {paths[kind]}
    </svg>
  );
}

/** Icono dentro de un hexágono (la firma visual). */
export function HexIcon({
  kind,
  size = 36,
  className = "",
}: {
  kind: ComponentKind;
  size?: number;
  className?: string;
}) {
  return (
    <span
      className={`relative inline-grid shrink-0 place-items-center ${className}`}
      style={{ width: size, height: size }}
    >
      <svg width={size} height={size} viewBox="0 0 100 100" className="absolute inset-0" aria-hidden="true">
        <polygon points="50,3 91,26.5 91,73.5 50,97 9,73.5 9,26.5" fill="currentColor" />
      </svg>
      <span className="relative text-[var(--hex-fg,var(--sobre-verde))]">
        <ComponentIcon kind={kind} size={Math.round(size * 0.5)} />
      </span>
    </span>
  );
}
