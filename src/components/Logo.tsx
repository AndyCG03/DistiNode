/**
 * Marca de DistiNode: cuatro cubos isométricos (el cubo de la CUJAE) unidos por un hexágono abierto.
 * Recreada en SVG a partir de public/brand/distinode-original.jpg para que escale y sirva en modo oscuro.
 */
export function LogoMark({ size = 32, className }: { size?: number; className?: string }) {
  return (
    <svg width={size} height={size} viewBox="20 -10 540 500" className={className} aria-hidden="true" focusable="false">
      <g fill="none" stroke="#0B6B4F" strokeWidth="24" strokeLinejoin="miter">
        <polyline points="97,300 97,165 205,103" />
        <polyline points="375,103 483,165 483,300" />
        <polyline points="188,410 290,469 392,410" />
      </g>
      <g stroke="#0B6B4F" strokeWidth="4">
        <line x1="290" y1="140" x2="290" y2="190" />
        <line x1="160" y1="350" x2="215" y2="318" />
      </g>
      <polygon points="290.0,184.0 366.2,228.0 290.0,272.0 213.8,228.0" fill="#A6A6A6" />
      <polygon points="213.8,228.0 290.0,272.0 290.0,360.0 213.8,316.0" fill="#0B6B4F" />
      <polygon points="224.5,246.5 282.4,276.4 282.4,346.8 224.5,309.8" fill="#FFFFFF" />
      <polygon points="290.0,272.0 366.2,228.0 366.2,316.0 290.0,360.0" fill="#0B6B4F" />
      <polygon points="290.0,4.0 347.2,37.0 290.0,70.0 232.8,37.0" fill="#A6A6A6" />
      <polygon points="232.8,37.0 290.0,70.0 290.0,136.0 232.8,103.0" fill="#0B6B4F" />
      <polygon points="240.8,50.9 284.3,73.3 284.3,126.1 240.8,98.4" fill="#FFFFFF" />
      <polygon points="290.0,70.0 347.2,37.0 347.2,103.0 290.0,136.0" fill="#0B6B4F" />
      <polygon points="110.0,316.0 167.2,349.0 110.0,382.0 52.8,349.0" fill="#A6A6A6" />
      <polygon points="52.8,349.0 110.0,382.0 110.0,448.0 52.8,415.0" fill="#0B6B4F" />
      <polygon points="60.8,362.9 104.3,385.3 104.3,438.1 60.8,410.4" fill="#FFFFFF" />
      <polygon points="110.0,382.0 167.2,349.0 167.2,415.0 110.0,448.0" fill="#0B6B4F" />
      <polygon points="470.0,316.0 527.2,349.0 470.0,382.0 412.8,349.0" fill="#A6A6A6" />
      <polygon points="412.8,349.0 470.0,382.0 470.0,448.0 412.8,415.0" fill="#0B6B4F" />
      <polygon points="420.8,362.9 464.3,385.3 464.3,438.1 420.8,410.4" fill="#FFFFFF" />
      <polygon points="470.0,382.0 527.2,349.0 527.2,415.0 470.0,448.0" fill="#0B6B4F" />
    </svg>
  );
}

export function Logo({ size = 32 }: { size?: number }) {
  return (
    <span className="inline-flex items-center gap-2">
      <LogoMark size={size} />
      <span className="text-[1.35rem] leading-none font-bold tracking-tight">
        <span className="text-verde">Disti</span>
        <span className="text-tinta">Node</span>
      </span>
    </span>
  );
}
