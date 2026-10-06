"use client";

import { useStoreApi } from "@xyflow/react";
import { useEffect, useRef } from "react";
import { useReducedMotion } from "@/lib/use-media";
import type { Train } from "@/sim/types";
import { pointAt } from "./geometry";
import { useSimRuntime } from "./SimContext";

/** Como mucho dibujamos esta cantidad de trenes por fotograma; con más, una muestra estable por id. */
export const MAX_DRAWN = 260;

type Palette = { request: string; requestEdge: string; response: string; error: string; line: string };

function readPalette(): Palette {
  const css = getComputedStyle(document.documentElement);
  const v = (name: string) => css.getPropertyValue(name).trim();
  return {
    request: v("--papel"),
    requestEdge: v("--tinta"),
    response: v("--gris-tren"),
    error: v("--rojo"),
    line: v("--verde"),
  };
}

/**
 * Capa <canvas> por encima del lienzo: avanza el motor en cada fotograma y dibuja los trenes
 * sobre las líneas de metro. Sin React en el bucle caliente.
 */
export function TrafficLayer() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const runtime = useSimRuntime();
  const store = useStoreApi();
  const reduced = useReducedMotion();

  useEffect(() => {
    const canvas = canvasRef.current!;
    const ctx = canvas.getContext("2d")!;
    let raf = 0;
    let last = performance.now();
    let palette = readPalette();
    let frame = 0;
    const dpr = () => Math.min(window.devicePixelRatio || 1, 2);

    const resize = () => {
      const { width, height } = canvas.getBoundingClientRect();
      canvas.width = Math.round(width * dpr());
      canvas.height = Math.round(height * dpr());
    };
    const ro = new ResizeObserver(resize);
    ro.observe(canvas);
    resize();

    const loop = (now: number) => {
      raf = requestAnimationFrame(loop);
      const dt = (now - last) / 1000;
      last = now;
      runtime.tick(dt, now);
      if (++frame % 30 === 0) palette = readPalette();

      const [tx, ty, zoom] = store.getState().transform;
      const scale = dpr();
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      ctx.setTransform(scale, 0, 0, scale, 0, 0);

      const trains = runtime.engine.trains();
      if (trains.length === 0) return;
      if (reduced) drawStatic(ctx, trains, runtime.polylines, palette, tx, ty, zoom);
      else drawTrains(ctx, trains, runtime.polylines, palette, tx, ty, zoom);
    };
    raf = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(raf);
      ro.disconnect();
    };
  }, [runtime, store, reduced]);

  return <canvas ref={canvasRef} className="pointer-events-none absolute inset-0 z-[4] size-full" aria-hidden="true" />;
}

type Lines = Map<string, import("./geometry").Polyline>;

function drawTrains(
  ctx: CanvasRenderingContext2D,
  trains: Train[],
  lines: Lines,
  p: Palette,
  tx: number,
  ty: number,
  zoom: number,
) {
  const every = Math.ceil(trains.length / MAX_DRAWN);
  const s = Math.min(Math.max(zoom, 0.55), 1.5);
  const w = 15 * s;
  const h = 8 * s;
  ctx.lineWidth = 1.5 * s;

  for (const t of trains) {
    if (every > 1 && t.id % every !== 0) continue;
    const pl = lines.get(t.edgeId);
    if (!pl) continue;
    const pt = pointAt(pl, t.progress);
    // Se desvanecen al entrar y salir de las estaciones.
    const edgeFade = Math.min(t.progress, 1 - t.progress) * pl.length;
    ctx.globalAlpha = Math.min(1, Math.max(0, (edgeFade - 6) / 14));
    if (ctx.globalAlpha <= 0) continue;

    ctx.save();
    ctx.translate(pt.x * zoom + tx, pt.y * zoom + ty);
    ctx.rotate(pt.angle);
    ctx.beginPath();
    ctx.roundRect(-w / 2, -h / 2, w, h, h / 2);
    if (t.kind === "async") {
      // Mensaje de cola: rombo oscuro, para distinguirlo de las peticiones de los clientes.
      ctx.beginPath();
      ctx.moveTo(-h * 0.9, 0);
      ctx.lineTo(0, -h * 0.9);
      ctx.lineTo(h * 0.9, 0);
      ctx.lineTo(0, h * 0.9);
      ctx.closePath();
      ctx.fillStyle = p.requestEdge;
      ctx.strokeStyle = p.request;
      ctx.fill();
      ctx.stroke();
    } else if (t.kind === "request") {
      ctx.fillStyle = p.request;
      ctx.strokeStyle = p.requestEdge;
      ctx.fill();
      ctx.stroke();
    } else {
      ctx.fillStyle = t.kind === "error" ? p.error : p.response;
      ctx.fill();
    }
    ctx.restore();
  }
  ctx.globalAlpha = 1;
}

/** Movimiento reducido: sin trenes que se desplacen; las líneas con tráfico se resaltan quietas. */
function drawStatic(
  ctx: CanvasRenderingContext2D,
  trains: Train[],
  lines: Lines,
  p: Palette,
  tx: number,
  ty: number,
  zoom: number,
) {
  const load = new Map<string, { n: number; errors: number }>();
  for (const t of trains) {
    const l = load.get(t.edgeId) ?? { n: 0, errors: 0 };
    l.n++;
    if (t.kind === "error") l.errors++;
    load.set(t.edgeId, l);
  }
  ctx.lineCap = "round";
  ctx.lineJoin = "round";
  for (const [id, l] of load) {
    const pl = lines.get(id);
    if (!pl) continue;
    ctx.beginPath();
    pl.pts.forEach((q, i) =>
      i ? ctx.lineTo(q.x * zoom + tx, q.y * zoom + ty) : ctx.moveTo(q.x * zoom + tx, q.y * zoom + ty),
    );
    ctx.strokeStyle = l.errors > l.n / 3 ? p.error : p.line;
    ctx.globalAlpha = 0.18 + 0.32 * Math.min(1, l.n / 25);
    ctx.lineWidth = (10 + 8 * Math.min(1, l.n / 25)) * Math.max(zoom, 0.5);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}
