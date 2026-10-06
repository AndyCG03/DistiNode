import type { FitViewOptions } from "@xyflow/react";

/** En pantallas estrechas no se aleja tanto que las estaciones no se lean: mejor desplazarse con el dedo. */
export function fitOptions(): FitViewOptions {
  const narrow = typeof window !== "undefined" && window.matchMedia("(max-width: 767px)").matches;
  return narrow ? { padding: 0.15, minZoom: 0.6, maxZoom: 1 } : { padding: 0.25, maxZoom: 1.1 };
}
