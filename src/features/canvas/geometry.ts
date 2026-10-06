/**
 * Trazado "mapa de metro": tramos horizontales y diagonales a 45°.
 * Lo comparten la arista (MetroEdge) y la capa de trenes (TrafficLayer) para que los trenes
 * vayan exactamente sobre la línea.
 */

export type Pt = { x: number; y: number };

export const STUB = 22;
const CORNER = 14;

export function metroPoints(s: Pt, t: Pt): Pt[] {
  const a = { x: s.x + STUB, y: s.y };
  const b = { x: t.x - STUB, y: t.y };
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const sx = Math.sign(dx);
  const sy = Math.sign(dy);
  const adx = Math.abs(dx);
  const ady = Math.abs(dy);

  let mid: Pt[];
  if (adx >= ady) {
    const h = (adx - ady) / 2;
    const p1 = { x: a.x + sx * h, y: a.y };
    mid = [p1, { x: p1.x + sx * ady, y: b.y }];
  } else {
    const d = adx / 2;
    const p1 = { x: a.x + sx * d, y: a.y + sy * d };
    mid = [p1, { x: p1.x, y: b.y - sy * d }];
  }

  const pts = [s, a, ...mid, b, t];
  return pts.filter((p, i) => i === 0 || Math.hypot(p.x - pts[i - 1].x, p.y - pts[i - 1].y) > 0.5);
}

/** Path SVG con esquinas redondeadas. */
export function roundedPath(pts: Pt[]): string {
  if (pts.length < 2) return "";
  let d = `M${pts[0].x},${pts[0].y}`;
  for (let i = 1; i < pts.length - 1; i++) {
    const p0 = pts[i - 1];
    const p = pts[i];
    const p1 = pts[i + 1];
    const l0 = Math.hypot(p.x - p0.x, p.y - p0.y);
    const l1 = Math.hypot(p1.x - p.x, p1.y - p.y);
    const r = Math.min(CORNER, l0 / 2, l1 / 2);
    const ax = p.x + ((p0.x - p.x) / l0) * r;
    const ay = p.y + ((p0.y - p.y) / l0) * r;
    const bx = p.x + ((p1.x - p.x) / l1) * r;
    const by = p.y + ((p1.y - p.y) / l1) * r;
    d += ` L${ax},${ay} Q${p.x},${p.y} ${bx},${by}`;
  }
  const last = pts[pts.length - 1];
  return `${d} L${last.x},${last.y}`;
}

export interface Polyline {
  pts: Pt[];
  /** Longitud acumulada hasta cada punto. */
  acc: number[];
  length: number;
}

export function polyline(pts: Pt[]): Polyline {
  const acc = [0];
  for (let i = 1; i < pts.length; i++) {
    acc.push(acc[i - 1] + Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y));
  }
  return { pts, acc, length: acc[acc.length - 1] ?? 0 };
}

/** Punto y dirección (ángulo en radianes) a una fracción 0..1 del recorrido. */
export function pointAt(pl: Polyline, f: number): { x: number; y: number; angle: number } {
  const { pts, acc, length } = pl;
  if (pts.length === 1 || length === 0) return { ...pts[0], angle: 0 };
  const d = Math.min(Math.max(f, 0), 1) * length;
  let i = 1;
  while (i < acc.length - 1 && acc[i] < d) i++;
  const p0 = pts[i - 1];
  const p1 = pts[i];
  const seg = acc[i] - acc[i - 1] || 1;
  const k = (d - acc[i - 1]) / seg;
  return {
    x: p0.x + (p1.x - p0.x) * k,
    y: p0.y + (p1.y - p0.y) * k,
    angle: Math.atan2(p1.y - p0.y, p1.x - p0.x),
  };
}

type Box = { x: number; y: number; width: number; height: number };

/** Salida por la derecha del origen, entrada por la izquierda del destino. */
export function endpoints(source: Box, target: Box): { s: Pt; t: Pt } {
  return {
    s: { x: source.x + source.width, y: source.y + source.height / 2 },
    t: { x: target.x, y: target.y + target.height / 2 },
  };
}
