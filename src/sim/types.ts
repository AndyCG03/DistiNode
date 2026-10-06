import type { ComponentKind, Params } from "./components";

export interface SimNode {
  id: string;
  kind: ComponentKind;
  params: Params;
  down: boolean;
}

export interface SimEdge {
  id: string;
  source: string;
  target: string;
  /** Segundos que tarda un mensaje en recorrer la línea. Por defecto DEFAULT_TRAVEL. */
  travelTime?: number;
}

export interface SimGraph {
  nodes: SimNode[];
  edges: SimEdge[];
}

export type TrainKind = "request" | "response" | "error";

/** Un mensaje en tránsito. `progress` va de 0 (origen de la arista) a 1 (destino). */
export interface Train {
  id: number;
  edgeId: string;
  kind: TrainKind;
  progress: number;
}

/** idle: sin tráfico · ok: verde · warn: ámbar · hot: rojo · down: caído */
export type Health = "idle" | "ok" | "warn" | "hot" | "down";

export interface NodeStats {
  /** Peticiones que llegan por segundo (ventana de 1 s). */
  arrivalRate: number;
  /** Peticiones rechazadas por segundo (cola llena, nodo caído, sin destino). */
  dropRate: number;
  queue: number;
  queueMax: number;
  busy: number;
  workers: number;
  /** Carga: llegadas / capacidad. */
  rho: number;
  status: Health;
}

export interface Metrics {
  /** Respuestas correctas que llegan a los clientes por segundo. */
  throughput: number;
  /** Media de espera + proceso en los componentes (ms). El viaje por las líneas no cuenta. */
  avgLatencyMs: number;
  /** Fracción 0..1 de respuestas con error. */
  errorRate: number;
  inFlight: number;
}

export interface EngineOptions {
  seed?: number;
  /** Paso fijo en segundos. */
  dt?: number;
}
