/**
 * Motor de simulación de DistiNode. TypeScript puro: sin React, sin DOM.
 *
 * - Paso fijo (`dt`, 10 ms por defecto) con acumulador: `advance(segundosReales)`.
 * - PRNG con semilla: mismas entradas → mismos resultados (útil para pruebas, lecciones y misiones).
 * - Las peticiones viajan por las aristas; la respuesta vuelve por la misma ruta en sentido contrario.
 */

import { paramValue, type ComponentKind } from "./components";
import { createRng, type Rng } from "./rng";
import type { EngineOptions, Health, Metrics, NodeStats, SimEdge, SimGraph, SimNode, Train, TrainKind } from "./types";

export const DEFAULT_DT = 0.01;
export const DEFAULT_TRAVEL = 0.35;
/** Si la pestaña se congela, no intentamos recuperar más de esto de golpe. */
export const MAX_FRAME = 0.25;
export const MAX_HOPS = 24;
const METRICS_WINDOW = 2;
const BUCKET = 0.1;
const BUCKETS = 10; // ventana de 1 s para las tasas por nodo

export const THRESHOLDS = { warnRho: 0.8, hotRho: 1, warnQueue: 0.15, hotQueue: 0.5 } as const;

interface Hop {
  node: string;
  edge: string;
}

interface Request {
  id: number;
  origin: string;
  path: Hop[];
  error: boolean;
  /** Segundos de espera + proceso acumulados en los componentes. */
  nodeTime: number;
  enqueuedAt: number;
}

interface Transit {
  id: number;
  req: Request;
  edge: string;
  /** 1 = hacia delante (petición), -1 = de vuelta (respuesta). */
  dir: 1 | -1;
  kind: TrainKind;
  depart: number;
  arrive: number;
}

interface Job {
  req: Request;
  doneAt: number;
}

interface NodeState {
  node: SimNode;
  rr: number;
  queue: Request[];
  busy: Job[];
  arrivals: number[];
  drops: number[];
  /** Cliente: próxima petición. */
  nextEmit: number;
  /** Balanceador: vista de salud de sus destinos y próximo chequeo. */
  healthy: Map<string, boolean>;
  nextCheck: number;
}

const hasCapacity = (k: ComponentKind) => k === "server" || k === "database";

export class Engine {
  readonly dt: number;
  private rng: Rng;
  private seed: number;
  private now = 0;
  private acc = 0;
  private traffic = 20;
  private nextId = 1;
  private nodes = new Map<string, NodeState>();
  private edges = new Map<string, SimEdge>();
  private out = new Map<string, SimEdge[]>();
  private transits: Transit[] = [];
  private bucketIdx = 0;
  private done: { t: number; latency: number; error: boolean }[] = [];

  constructor(opts: EngineOptions = {}) {
    this.dt = opts.dt ?? DEFAULT_DT;
    this.seed = opts.seed ?? 1;
    this.rng = createRng(this.seed);
  }

  get time() {
    return this.now;
  }

  /** Vuelve a t = 0 sin tráfico en vuelo, conservando el grafo. */
  reset() {
    this.rng = createRng(this.seed);
    this.now = 0;
    this.acc = 0;
    this.nextId = 1;
    this.transits = [];
    this.done = [];
    this.bucketIdx = 0;
    for (const s of this.nodes.values()) {
      s.queue = [];
      s.busy = [];
      s.arrivals.fill(0);
      s.drops.fill(0);
      s.rr = 0;
      s.nextEmit = 0;
      s.healthy.clear();
      s.nextCheck = 0;
    }
  }

  setTraffic(rps: number) {
    this.traffic = Math.max(0, rps);
  }

  /** Sustituye el grafo conservando el estado de los nodos que siguen existiendo. */
  setGraph(graph: SimGraph) {
    const next = new Map<string, NodeState>();
    for (const n of graph.nodes) {
      const prev = this.nodes.get(n.id);
      if (prev) {
        const wentDown = !prev.node.down && n.down;
        prev.node = n;
        if (wentDown) this.crash(prev);
        next.set(n.id, prev);
      } else {
        next.set(n.id, {
          node: n,
          rr: 0,
          queue: [],
          busy: [],
          arrivals: new Array(BUCKETS).fill(0),
          drops: new Array(BUCKETS).fill(0),
          nextEmit: this.now,
          healthy: new Map(),
          nextCheck: this.now,
        });
      }
    }
    // Lo que había dentro de nodos borrados se pierde.
    for (const [id, s] of this.nodes) {
      if (!next.has(id)) for (const r of [...s.queue, ...s.busy.map((j) => j.req)]) this.lose(r);
    }
    this.nodes = next;

    this.edges = new Map();
    this.out = new Map();
    for (const e of graph.edges) {
      if (!next.has(e.source) || !next.has(e.target) || e.source === e.target) continue;
      this.edges.set(e.id, e);
      const list = this.out.get(e.source) ?? [];
      list.push(e);
      this.out.set(e.source, list);
    }

    this.transits = this.transits.filter((m) => {
      if (this.edges.has(m.edge)) return true;
      this.lose(m.req);
      return false;
    });
  }

  /** Avanza `seconds` de tiempo real en pasos fijos. Devuelve cuántos pasos dio. */
  advance(seconds: number): number {
    this.acc += Math.min(Math.max(seconds, 0), MAX_FRAME);
    let steps = 0;
    // El épsilon evita perder un paso por errores de coma flotante al acumular.
    while (this.acc >= this.dt - 1e-9) {
      this.step();
      this.acc = Math.max(0, this.acc - this.dt);
      steps++;
    }
    return steps;
  }

  step() {
    this.now += this.dt;
    const now = this.now;
    this.rollBuckets();

    // 1. Llegadas.
    if (this.transits.some((m) => m.arrive <= now)) {
      const arrived: Transit[] = [];
      this.transits = this.transits.filter((m) => (m.arrive <= now ? (arrived.push(m), false) : true));
      arrived.sort((a, b) => a.arrive - b.arrive || a.id - b.id);
      for (const m of arrived) {
        if (m.dir === 1) this.onRequest(m);
        else this.onResponse(m);
      }
    }

    // 2. Clientes generan tráfico (llegadas regulares con algo de variación).
    const clients = [...this.nodes.values()].filter(
      (s) => s.node.kind === "client" && !s.node.down && this.out.has(s.node.id),
    );
    const perClient = clients.length ? this.traffic / clients.length : 0;
    for (const s of clients) {
      if (perClient <= 0) continue;
      if (s.nextEmit < now - 1) s.nextEmit = now; // venía de pausa o de 0 pet/s
      while (s.nextEmit <= now) {
        this.emit(s);
        s.nextEmit += (0.5 + this.rng()) / perClient;
      }
    }

    // 3. Servidores y bases de datos: terminan trabajos y sacan de la cola.
    for (const s of this.nodes.values()) {
      if (!hasCapacity(s.node.kind) || s.node.down) continue;
      if (s.busy.length) {
        const finished = s.busy.filter((j) => j.doneAt <= now);
        if (finished.length) {
          s.busy = s.busy.filter((j) => j.doneAt > now);
          for (const j of finished) this.afterService(s, j.req);
        }
      }
      this.fillWorkers(s);
    }

    // 4. Chequeos de salud de los balanceadores.
    for (const s of this.nodes.values()) {
      if (s.node.kind !== "balancer" || s.node.down || s.nextCheck > now) continue;
      for (const e of this.out.get(s.node.id) ?? []) s.healthy.set(e.target, !this.nodes.get(e.target)!.node.down);
      s.nextCheck = now + paramValue("balancer", s.node.params, "healthCheckMs") / 1000;
    }

    // 5. Ventana de métricas.
    let cut = 0;
    while (cut < this.done.length && this.done[cut].t < now - METRICS_WINDOW) cut++;
    if (cut) this.done.splice(0, cut);
  }

  // ── Consultas ────────────────────────────────────────────

  /** Mensajes en tránsito, con posición interpolada entre pasos. */
  trains(): Train[] {
    const t = this.now + this.acc;
    return this.transits.map((m) => {
      const f = Math.min(Math.max((t - m.depart) / (m.arrive - m.depart || 1), 0), 1);
      return { id: m.id, edgeId: m.edge, kind: m.kind, progress: m.dir === 1 ? f : 1 - f };
    });
  }

  nodeStats(id: string): NodeStats | null {
    const s = this.nodes.get(id);
    if (!s) return null;
    const { kind, params, down } = s.node;
    const span = Math.min(BUCKETS * BUCKET, Math.max(this.now, BUCKET));
    const arrivalRate = sum(s.arrivals) / span;
    const dropRate = sum(s.drops) / span;
    const queueMax = hasCapacity(kind) ? paramValue(kind, params, "queueMax") : 0;
    const capacity = hasCapacity(kind) ? paramValue(kind, params, "capacity") : 0;
    const rho = capacity > 0 ? arrivalRate / capacity : 0;
    const q = queueMax > 0 ? s.queue.length / queueMax : 0;

    let status: Health;
    if (down) status = "down";
    else if (arrivalRate === 0 && s.queue.length === 0 && s.busy.length === 0 && dropRate === 0) status = "idle";
    else if (dropRate > 0 || rho >= THRESHOLDS.hotRho || q > THRESHOLDS.hotQueue) status = "hot";
    else if (rho >= THRESHOLDS.warnRho || q > THRESHOLDS.warnQueue) status = "warn";
    else status = "ok";

    return {
      arrivalRate,
      dropRate,
      queue: s.queue.length,
      queueMax,
      busy: s.busy.length,
      workers: hasCapacity(kind) ? this.workers(s) : 0,
      rho,
      status,
    };
  }

  metrics(): Metrics {
    const span = Math.min(METRICS_WINDOW, Math.max(this.now, this.dt));
    let ok = 0;
    let err = 0;
    let lat = 0;
    for (const d of this.done) {
      if (d.error) err++;
      else {
        ok++;
        lat += d.latency;
      }
    }
    let inFlight = this.transits.length;
    for (const s of this.nodes.values()) inFlight += s.queue.length + s.busy.length;
    return {
      throughput: ok / span,
      avgLatencyMs: ok ? (lat / ok) * 1000 : 0,
      errorRate: ok + err ? err / (ok + err) : 0,
      inFlight,
    };
  }

  // ── Comportamiento ───────────────────────────────────────

  private emit(client: NodeState) {
    const edge = this.pick(client, this.out.get(client.node.id)!);
    const req: Request = {
      id: this.nextId++,
      origin: client.node.id,
      path: [],
      error: false,
      nodeTime: 0,
      enqueuedAt: 0,
    };
    this.send(req, edge, 1, "request");
  }

  private onRequest(m: Transit) {
    const edge = this.edges.get(m.edge)!;
    const s = this.nodes.get(edge.target)!;
    const req = m.req;
    req.path.push({ node: s.node.id, edge: edge.id });
    this.bump(s.arrivals);

    if (s.node.down || req.path.length > MAX_HOPS) return this.fail(s, req);

    switch (s.node.kind) {
      case "balancer": {
        const candidates = (this.out.get(s.node.id) ?? []).filter((e) => s.healthy.get(e.target) !== false);
        if (!candidates.length) return this.fail(s, req);
        return this.send(req, this.pick(s, candidates), 1, "request");
      }
      case "cache": {
        const hit = this.rng() * 100 < paramValue("cache", s.node.params, "hitRate");
        const next = this.out.get(s.node.id);
        if (hit || !next?.length) return this.respond(req);
        return this.send(req, this.pick(s, next), 1, "request");
      }
      case "server":
      case "database": {
        if (s.busy.length < this.workers(s)) return this.startJob(s, req);
        if (s.queue.length < paramValue(s.node.kind, s.node.params, "queueMax")) {
          req.enqueuedAt = this.now;
          s.queue.push(req);
          return;
        }
        return this.fail(s, req);
      }
      case "client":
        return this.respond(req);
    }
  }

  private onResponse(m: Transit) {
    const req = m.req;
    req.path.pop();
    if (req.path.length === 0) {
      // Los errores ya se contaron al fallar; aquí solo llegan las respuestas correctas.
      if (!req.error) this.done.push({ t: this.now, latency: req.nodeTime, error: false });
      return;
    }
    this.respond(req);
  }

  private afterService(s: NodeState, req: Request) {
    const next = this.out.get(s.node.id);
    if (next?.length) this.send(req, this.pick(s, next), 1, "request");
    else this.respond(req);
  }

  private fillWorkers(s: NodeState) {
    const workers = this.workers(s);
    while (s.busy.length < workers && s.queue.length) {
      const req = s.queue.shift()!;
      req.nodeTime += this.now - req.enqueuedAt;
      this.startJob(s, req);
    }
  }

  private startJob(s: NodeState, req: Request) {
    const service = this.serviceTime(s);
    req.nodeTime += service;
    s.busy.push({ req, doneAt: this.now + service });
  }

  /** Un nodo cae: lo que tenía dentro falla. */
  private crash(s: NodeState) {
    const inside = [...s.queue, ...s.busy.map((j) => j.req)];
    s.queue = [];
    s.busy = [];
    for (const r of inside) this.fail(s, r);
  }

  /** El error cuenta en el instante del fallo; el tren rojo que vuelve es solo visual. */
  private fail(s: NodeState, req: Request) {
    this.bump(s.drops);
    if (!req.error) {
      req.error = true;
      this.done.push({ t: this.now, latency: 0, error: true });
    }
    this.respond(req);
  }

  /** La respuesta vuelve por la arista por la que llegó la petición al último nodo. */
  private respond(req: Request) {
    const hop = req.path[req.path.length - 1];
    const edge = hop && this.edges.get(hop.edge);
    if (!edge) return this.lose(req);
    this.send(req, edge, -1, req.error ? "error" : "response");
  }

  /** Petición perdida por un cambio del grafo: cuenta como error. */
  private lose(req: Request) {
    if (!req.error) this.done.push({ t: this.now, latency: 0, error: true });
    req.error = true;
    req.path = [];
  }

  private send(req: Request, edge: SimEdge, dir: 1 | -1, kind: TrainKind) {
    const travel = edge.travelTime ?? DEFAULT_TRAVEL;
    this.transits.push({
      id: this.nextId++,
      req,
      edge: edge.id,
      dir,
      kind,
      depart: this.now,
      arrive: this.now + travel,
    });
  }

  /** Round-robin. */
  private pick(s: NodeState, list: SimEdge[]): SimEdge {
    const e = list[s.rr % list.length];
    s.rr = (s.rr + 1) % 1_000_000;
    return e;
  }

  /** Trabajadores en paralelo = capacidad × tiempo de proceso (mínimo 1). */
  private workers(s: NodeState) {
    const { kind, params } = s.node;
    return Math.max(
      1,
      Math.round((paramValue(kind, params, "capacity") * paramValue(kind, params, "processingMs")) / 1000),
    );
  }

  /** Duración de cada trabajo, ajustada para que el rendimiento sea exactamente la capacidad. */
  private serviceTime(s: NodeState) {
    return this.workers(s) / Math.max(1e-6, paramValue(s.node.kind, s.node.params, "capacity"));
  }

  private bump(buckets: number[]) {
    buckets[this.bucketIdx % BUCKETS]++;
  }

  private rollBuckets() {
    const idx = Math.floor(this.now / BUCKET + 1e-9);
    if (idx === this.bucketIdx) return;
    const steps = Math.min(idx - this.bucketIdx, BUCKETS);
    for (let k = 1; k <= steps; k++) {
      const b = (this.bucketIdx + k) % BUCKETS;
      for (const s of this.nodes.values()) {
        s.arrivals[b] = 0;
        s.drops[b] = 0;
      }
    }
    this.bucketIdx = idx;
  }
}

function sum(xs: number[]) {
  let t = 0;
  for (const x of xs) t += x;
  return t;
}
