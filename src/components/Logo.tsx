/**
 * Marca de Nodos: hexágono con cubo isométrico (identidad CUJAE). Las aristas interiores del cubo
 * forman una "Y" — tres líneas que se unen en un nodo.
 */
export function LogoMark({ size = 32, className }: { size?: number; className?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      className={className}
      aria-hidden="true"
      focusable="false"
    >
      <polygon points="10.2,27 50,4 89.8,27 50,50" fill="#A6A6A6" />
      <polygon points="89.8,27 89.8,73 50,96 50,50" fill="#FFFFFF" />
      <polygon points="10.2,27 50,50 50,96 10.2,73" fill="#00704F" />
      <polygon
        points="50,4 89.8,27 89.8,73 50,96 10.2,73 10.2,27"
        fill="none"
        stroke="#00704F"
        strokeWidth="6"
        strokeLinejoin="round"
      />
      <circle cx="50" cy="50" r="8" fill="#FFFFFF" stroke="#00704F" strokeWidth="5" />
    </svg>
  );
}

export function Logo({ size = 30 }: { size?: number }) {
  return (
    <span className="inline-flex items-center gap-2">
      <LogoMark size={size} />
      <span className="text-[1.35rem] font-bold leading-none tracking-tight text-verde">nodos</span>
    </span>
  );
}
