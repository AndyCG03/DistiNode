import type { ComponentKind, Params } from "./components";

export interface SimNode {
  id: string;
  kind: ComponentKind;
  params: Params;
  down: boolean;
  /** Degradado: procesa 4 veces más lento (o añade 150 ms si no tiene capacidad). */
  slow?: boolean;
}

export interface SimEdge {
  id: string;
  source: string;
  target: string;
  /** Segundos que tarda un tren en recorrer la línea (visual). Por defecto DEFAULT_TRAVEL. */
  travelTime?: number;
  /** Latencia de red añadida, en ms simulados. Cuenta en la latencia y en los tiempos de espera. */
  latencyMs?: number;
  /** Conexión cortada: lo que se envía por ella falla. */
  down?: boolean;
}

export interface SimGraph {
  nodes: SimNode[];
  edges: SimEdge[];
}

/** request/response/error: tráfico de clientes · async: mensajes de una cola a sus workers. */
export type TrainKind = "request" | "response" | "error" | "async";

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
  /** Peticiones rechazadas por segundo (cola llena, nodo caído, límite, sin destino). */
  dropRate: number;
  queue: number;
  queueMax: number;
  busy: number;
  workers: number;
  /** Carga: llegadas / capacidad (o / límite en un API Gateway). */
  rho: number;
  status: Health;
  /** Segundos seguidos con la cola casi llena. Lo usa el supervisor para las caídas por sobrecarga. */
  overloadFor: number;
}

export interface Metrics {
  /** Respuestas correctas que llegan a los clientes por segundo. */
  throughput: number;
  /** Media de la latencia simulada (espera + proceso + red) de las respuestas correctas, en ms. */
  avgLatencyMs: number;
  /** Percentil 95 de esa latencia, en ms. */
  p95LatencyMs: number;
  /** Fracción 0..1 de peticiones que terminaron en error (incluye tiempos de espera agotados). */
  errorRate: number;
  /** Reintentos por segundo de los clientes. */
  retryRate: number;
  /** Mensajes procesados por segundo en segundo plano (colas → workers). */
  asyncThroughput: number;
  /** Mensajes esperando en todas las colas. */
  backlog: number;
  inFlight: number;
}

export interface EngineOptions {
  seed?: number;
  /** Paso fijo en segundos. */
  dt?: number;
}
