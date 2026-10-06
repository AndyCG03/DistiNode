/**
 * Motor de simulación de DistiNode. TypeScript puro: sin React, sin DOM.
 *
 * - Paso fijo (`dt`, 10 ms por defecto) con acumulador: `advance(segundosReales)`.
 * - PRNG con semilla: mismas entradas → mismos resultados (útil para pruebas, lecciones y misiones).
 * - Las peticiones viajan por las aristas; la respuesta vuelve por la misma ruta en sentido contrario.
 *
 * Dos relojes:
 * - Tiempo de pared (`now`): lo que tardan los trenes en recorrer las líneas. Es "cámara lenta" para que se vea.
 * - Tiempo simulado (`Request.sim`): espera + proceso + latencia de red. Es lo que miden las métricas
 *   y lo que agota los tiempos de espera de los clientes.
 */

import { hasCapacity, paramValue, type ComponentKind } from "./components";
import { createRng, type Rng } from "./rng";
import type { EngineOptions, Health, Metrics, NodeStats, SimEdge, SimGraph, SimNode, Train, TrainKind } from "./types";

export const DEFAULT_DT = 0.01;
export const DEFAULT_TRAVEL = 0.35;
/** Si la pestaña se congela, no intentamos recuperar más de esto de golpe. */
export const MAX_FRAME = 0.25;
export const MAX_HOPS = 24;
/** Latencia de red base por salto, en ms simulados. */
export const NET_MS = 1;
/** Un nodo degradado procesa así de lento… */
export const SLOW_FACTOR = 4;
/** …o, si no tiene capacidad propia, añade este retraso (s). */
export const SLOW_DELAY = 0.15;
/** Prefetch de una cola hacia consumidores sin capacidad propia. */
const DEFAULT_PREFETCH = 4;
/** Coste fijo (s simulados) de los componentes que no hacen cola. */
const INSTANT: Partial<Record<ComponentKind, number>> = { cdn: 0.002, gateway: 0.002, cache: 0.001, queue: 0.001 };
const METRICS_WINDOW = 2;
const BUCKET = 0.1;
const BUCKETS = 10; // ventana de 1 s para las tasas por nodo
const TIMEOUT_CHECK_EVERY = 5; // pasos

export const THRESHOLDS = { warnRho: 0.8, hotRho: 1, warnQueue: 0.15, hotQueue: 0.5, overloadQueue: 0.8 } as const;

interface Hop {
  node: string;
  edge: string;
}

type ReqKind = "client" | "child" | "async";

/** Una petición de cliente con sus intentos. */
interface Logical {
  client: string;
  attempt: number;
  retries: number;
  /** Tiempo de espera en s simulados (0 = sin límite). */
  timeout: number;
  /** Tiempo simulado consumido por intentos anteriores y esperas entre reintentos. */
  base: number;
  current: Request | null;
  settled: boolean;
}

interface Request {
  id: number;
  kind: ReqKind;
  /** Nodo donde nació: el cliente, el servidor que hizo fan-out o la cola. */
  origin: string;
  path: Hop[];
  error: boolean;
  /** Segundos simulados acumulados. */
  sim: number;
  /** Desde cuándo espera en una cola (tiempo de pared), o null. */
  queuedAt: number | null;
  logical?: Logical;
  /** El cliente ya se rindió con este intento: su respuesta se ignora. */
  abandoned?: boolean;
  parent?: Request;
  children?: Request[] | null;
  childMax?: number;
  childError?: boolean;
  done?: boolean;
  /** Mensaje de cola: worker que lo tiene. */
  consumer?: string;
  /** Mensaje de cola: ocupa un hueco del prefetch de su consumidor hasta que este termina de procesarlo. */
  credit?: boolean;
}

interface Transit {
  id: number;
  req: Request;
  edge: string;
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
  overloadFor: number;
  // cliente
  nextEmit: number;
  pending: Logical[];
  // balanceador
  healthy: Map<string, boolean>;
  nextCheck: number;
  outstanding: Map<string, number>;
  // API gateway
  tokens: number;
  // cola de mensajes
  backlog: Request[];
  inflight: Map<string, number>;
}

type Done = { t: number; latency: number; error: boolean };

export class Engine {
  readonly dt: number;
  private rng: Rng;
  private seed: number;
  private now = 0;
  private acc = 0;
  private steps = 0;
  private traffic = 20;
  private nextId = 1;
  private nodes = new Map<string, NodeState>();
  private edges = new Map<string, SimEdge>();
  private out = new Map<string, SimEdge[]>();
  private transits: Transit[] = [];
  private timers: { at: number; fn: () => void }[] = [];
  private bucketIdx = 0;
  private done: Done[] = [];
  private retryLog: number[] = [];
  private asyncLog: number[] = [];

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
    this.steps = 0;
    this.nextId = 1;
    this.transits = [];
    this.timers = [];
    this.done = [];
    this.retryLog = [];
    this.asyncLog = [];
    this.bucketIdx = 0;
    for (const [id, s] of this.nodes) this.nodes.set(id, this.freshState(s.node));
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
        next.set(n.id, this.freshState(n));
      }
    }
    const removed = [...this.nodes].filter(([id]) => !next.has(id)).map(([, s]) => s);
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

    // Lo que había dentro de nodos borrados o viajando por aristas borradas se pierde.
    for (const s of removed) for (const r of [...s.queue, ...s.busy.map((j) => j.req)]) this.lose(r);
    const lost: Request[] = [];
    this.transits = this.transits.filter((m) => {
      if (this.edges.has(m.edge)) return true;
      lost.push(m.req);
      return false;
    });
    for (const r of lost) this.lose(r);
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
    this.steps++;
    const now = this.now;
    this.rollBuckets();

    // 1. Temporizadores (reintentos, retrasos de nodos lentos).
    if (this.timers.length) {
      const due = this.timers.filter((t) => t.at <= now);
      if (due.length) {
        this.timers = this.timers.filter((t) => t.at > now);
        for (const t of due) t.fn();
      }
    }

    // 2. Llegadas.
    if (this.transits.some((m) => m.arrive <= now)) {
      const arrived: Transit[] = [];
      this.transits = this.transits.filter((m) => {
        if (m.arrive > now) return true;
        arrived.push(m);
        return false;
      });
      arrived.sort((a, b) => a.arrive - b.arrive || a.id - b.id);
      for (const m of arrived) {
        if (m.dir === 1) this.onRequest(m);
        else this.onResponse(m);
      }
    }

    // 3. Clientes generan tráfico (llegadas regulares con algo de variación).
    const clients = [...this.nodes.values()].filter(
      (s) => s.node.kind === "client" && !s.node.down && this.out.has(s.node.id),
    );
    const perClient = clients.length ? this.traffic / clients.length : 0;
    for (const s of clients) {
      if (perClient <= 0) continue;
      if (s.nextEmit < now - 1) s.nextEmit = now; // venía de pausa o de 0 pet/s
      while (s.nextEmit <= now) {
        this.newLogical(s);
        s.nextEmit += (0.5 + this.rng()) / perClient;
      }
    }

    for (const s of this.nodes.values()) {
      const { kind } = s.node;
      // 4. Servidores, workers y bases de datos: terminan trabajos y sacan de la cola.
      if (hasCapacity(kind) && !s.node.down) {
        if (s.busy.length) {
          const finished = s.busy.filter((j) => j.doneAt <= now + 1e-9);
          if (finished.length) {
            s.busy = s.busy.filter((j) => j.doneAt > now + 1e-9);
            finished.sort((x, y) => x.doneAt - y.doneAt);
            for (const j of finished) {
              this.afterService(s, j.req);
              // El trabajador libre toma el siguiente en el instante exacto en que terminó, no al final del
              // paso: si no, la discretización le robaría hasta un paso por trabajo a la capacidad.
              if (s.queue.length && !s.node.down) this.startFromQueue(s, j.doneAt);
            }
          }
        }
        this.fillWorkers(s);
      }
      // 5. Colas de mensajes: entregan a sus consumidores según su capacidad libre.
      if (kind === "queue" && !s.node.down) this.dispatch(s);
      // 6. API gateway: rellena fichas.
      if (kind === "gateway") {
        const rate = paramValue("gateway", s.node.params, "rateLimit");
        s.tokens = Math.min(rate, s.tokens + rate * this.dt);
      }
      // 7. Balanceadores: chequeo de salud.
      if (kind === "balancer" && !s.node.down && s.nextCheck <= now) {
        for (const e of this.out.get(s.node.id) ?? []) {
          s.healthy.set(e.target, !e.down && !this.nodes.get(e.target)!.node.down);
        }
        s.nextCheck = now + paramValue("balancer", s.node.params, "healthCheckMs") / 1000;
      }
      // 8. Sobrecarga sostenida (la usa el supervisor para tumbar nodos).
      s.overloadFor = this.isOverloaded(s) ? s.overloadFor + this.dt : 0;
    }

    // 9. Tiempos de espera de los clientes.
    if (this.steps % TIMEOUT_CHECK_EVERY === 0) this.checkTimeouts();

    // 10. Ventanas de métricas.
    const cutoff = now - METRICS_WINDOW;
    trimFront(this.done, (d) => d.t < cutoff);
    trimFront(this.retryLog, (t) => t < cutoff);
    trimFront(this.asyncLog, (t) => t < cutoff);
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
    const cap = hasCapacity(kind);
    const queueLen = kind === "queue" ? s.backlog.length : s.queue.length;
    const queueMax = cap || kind === "queue" ? paramValue(kind, params, "queueMax") : 0;
    const limit = cap
      ? paramValue(kind, params, "capacity")
      : kind === "gateway"
        ? paramValue(kind, params, "rateLimit")
        : 0;
    const rho = limit > 0 ? arrivalRate / limit : 0;
    const q = queueMax > 0 ? queueLen / queueMax : 0;
    const busy = kind === "queue" ? sum([...s.inflight.values()]) : s.busy.length;

    let status: Health;
    if (down) status = "down";
    else if (arrivalRate === 0 && queueLen === 0 && busy === 0 && dropRate === 0) status = "idle";
    else if (dropRate > 0 || q > THRESHOLDS.hotQueue || (cap && rho >= THRESHOLDS.hotRho)) status = "hot";
    else if (q > THRESHOLDS.warnQueue || rho >= THRESHOLDS.warnRho || s.node.slow) status = "warn";
    else status = "ok";

    return {
      arrivalRate,
      dropRate,
      queue: queueLen,
      queueMax,
      busy,
      workers: cap ? this.workers(s) : 0,
      rho,
      status,
      overloadFor: s.overloadFor,
    };
  }

  metrics(): Metrics {
    const span = Math.min(METRICS_WINDOW, Math.max(this.now, this.dt));
    const ok: number[] = [];
    let err = 0;
    for (const d of this.done) {
      if (d.error) err++;
      else ok.push(d.latency);
    }
    let inFlight = this.transits.length;
    let backlog = 0;
    for (const s of this.nodes.values()) {
      inFlight += s.queue.length + s.busy.length;
      backlog += s.backlog.length;
    }
    ok.sort((a, b) => a - b);
    const avg = ok.length ? sum(ok) / ok.length : 0;
    const p95 = ok.length ? ok[Math.min(ok.length - 1, Math.floor(ok.length * 0.95))] : 0;
    return {
      throughput: ok.length / span,
      avgLatencyMs: avg * 1000,
      p95LatencyMs: p95 * 1000,
      errorRate: ok.length + err ? err / (ok.length + err) : 0,
      retryRate: this.retryLog.length / span,
      asyncThroughput: this.asyncLog.length / span,
      backlog,
      inFlight,
    };
  }

  // ── Clientes: intentos, reintentos y tiempos de espera ───

  private newLogical(s: NodeState) {
    const logical: Logical = {
      client: s.node.id,
      attempt: 0,
      retries: Math.max(0, Math.round(paramValue("client", s.node.params, "retries"))),
      timeout: paramValue("client", s.node.params, "timeoutMs") / 1000,
      base: 0,
      current: null,
      settled: false,
    };
    if (logical.timeout > 0) s.pending.push(logical);
    this.attempt(logical);
  }

  private attempt(logical: Logical) {
    if (logical.settled) return;
    const s = this.nodes.get(logical.client);
    const out = s && !s.node.down ? this.out.get(s.node.id) : undefined;
    if (!s || !out?.length) return this.settle(logical, null);
    logical.attempt++;
    const req = this.newRequest("client", s.node.id);
    req.logical = logical;
    logical.current = req;
    this.send(req, this.pick(s, out), 1);
  }

  /** El intento actual falló (error o tiempo agotado): reintenta con espera exponencial o se rinde. */
  private attemptFailed(logical: Logical, req: Request) {
    if (req.abandoned) return;
    req.abandoned = true;
    if (logical.settled || logical.current !== req) return;
    logical.base += this.simElapsed(req);
    if (logical.attempt <= logical.retries) {
      const backoff = 0.1 * 2 ** (logical.attempt - 1) * (0.8 + 0.4 * this.rng());
      logical.base += backoff;
      this.retryLog.push(this.now);
      this.timers.push({ at: this.now + backoff, fn: () => this.attempt(logical) });
    } else {
      this.settle(logical, null);
    }
  }

  private settle(logical: Logical, success: Request | null) {
    if (logical.settled) return;
    logical.settled = true;
    this.done.push(
      success
        ? { t: this.now, latency: logical.base + this.simElapsed(success), error: false }
        : { t: this.now, latency: 0, error: true },
    );
  }

  private checkTimeouts() {
    for (const s of this.nodes.values()) {
      if (s.node.kind !== "client" || !s.pending.length) continue;
      s.pending = s.pending.filter((l) => !l.settled);
      for (const l of s.pending) {
        const cur = l.current;
        if (cur && !cur.abandoned && l.base + this.simElapsed(cur) > l.timeout) this.attemptFailed(l, cur);
      }
    }
  }

  /** Tiempo simulado de una petición hasta ahora, incluida la espera en cola y los hijos pendientes. */
  private simElapsed(r: Request): number {
    let t = r.sim + (r.queuedAt !== null ? this.now - r.queuedAt : 0);
    if (r.children) {
      let m = r.childMax ?? 0;
      for (const c of r.children) if (!c.done) m = Math.max(m, this.simElapsed(c));
      t += m;
    }
    return t;
  }

  // ── Comportamiento de cada componente ────────────────────

  private onRequest(m: Transit) {
    const edge = this.edges.get(m.edge)!;
    const s = this.nodes.get(edge.target)!;
    const req = m.req;
    req.path.push({ node: s.node.id, edge: edge.id });
    this.bump(s.arrivals);

    if (s.node.down || req.path.length > MAX_HOPS) return this.fail(s, req);
    if (s.node.slow && !hasCapacity(s.node.kind)) {
      req.sim += SLOW_DELAY;
      this.timers.push({
        at: this.now + SLOW_DELAY,
        fn: () => (s.node.down ? this.fail(s, req) : this.process(s, req)),
      });
      return;
    }
    this.process(s, req);
  }

  private process(s: NodeState, req: Request) {
    const { kind, params } = s.node;
    req.sim += INSTANT[kind] ?? 0;
    const out = this.out.get(s.node.id) ?? [];

    switch (kind) {
      case "balancer": {
        const candidates = out.filter((e) => !e.down && s.healthy.get(e.target) !== false);
        if (!candidates.length) return this.fail(s, req);
        let edge: SimEdge;
        if (paramValue("balancer", params, "lbAlgorithm") === 1) {
          const start = s.rr++ % candidates.length;
          edge = candidates[start];
          for (let i = 1; i < candidates.length; i++) {
            const e = candidates[(start + i) % candidates.length];
            if ((s.outstanding.get(e.target) ?? 0) < (s.outstanding.get(edge.target) ?? 0)) edge = e;
          }
        } else {
          edge = this.pick(s, candidates);
        }
        s.outstanding.set(edge.target, (s.outstanding.get(edge.target) ?? 0) + 1);
        return this.send(req, edge, 1);
      }
      case "gateway": {
        if (s.tokens < 1) return this.fail(s, req);
        s.tokens -= 1;
        return out.length ? this.send(req, this.pick(s, out), 1) : this.respond(req);
      }
      case "cdn":
      case "cache": {
        const hit = this.rng() * 100 < paramValue(kind, params, "hitRate");
        if (hit || !out.length) return this.respond(req);
        return this.send(req, this.pick(s, out), 1);
      }
      case "queue": {
        if (s.backlog.length >= paramValue("queue", params, "queueMax")) return this.fail(s, req);
        const msg = this.newRequest("async", s.node.id);
        msg.queuedAt = this.now;
        s.backlog.push(msg);
        return this.respond(req); // confirma al momento
      }
      case "server":
      case "worker":
      case "database": {
        if (s.busy.length < this.workers(s)) return this.startJob(s, req);
        if (s.queue.length < paramValue(kind, params, "queueMax")) {
          req.queuedAt = this.now;
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
    const edge = this.edges.get(m.edge);
    const src = edge && this.nodes.get(edge.source);
    if (edge && src?.node.kind === "balancer") {
      src.outstanding.set(edge.target, Math.max(0, (src.outstanding.get(edge.target) ?? 0) - 1));
    }
    const req = m.req;
    req.path.pop();
    if (req.path.length === 0) return this.arrived(req);
    this.respond(req);
  }

  /** La petición volvió a su origen. */
  private arrived(req: Request) {
    if (req.kind === "client") {
      if (!req.error && !req.abandoned && req.logical) this.settle(req.logical, req);
    } else if (req.kind === "child") {
      this.childDone(req);
    } else {
      this.asyncDone(req);
    }
  }

  private afterService(s: NodeState, req: Request) {
    if (req.kind === "async" && req.credit && req.consumer === s.node.id) this.releaseCredit(req);
    const next = this.out.get(s.node.id);
    if (!next?.length) return this.respond(req);
    const fanout = s.node.kind === "server" && paramValue("server", s.node.params, "fanout") === 1 && next.length > 1;
    if (!fanout) return this.send(req, this.pick(s, next), 1);
    req.children = [];
    req.childMax = 0;
    req.childError = false;
    for (let i = 0; i < next.length; i++) {
      const child = this.newRequest("child", s.node.id);
      child.parent = req;
      req.children.push(child);
    }
    // Se envían después de crear todos: un fallo inmediato no debe cerrar el fan-out antes de tiempo.
    req.children.forEach((child, i) => this.send(child, next[i], 1));
  }

  private childDone(child: Request) {
    if (child.done) return;
    child.done = true;
    const parent = child.parent;
    if (!parent?.children) return;
    parent.childMax = Math.max(parent.childMax ?? 0, child.sim);
    if (child.error) parent.childError = true;
    if (parent.children.some((c) => !c.done)) return;
    parent.sim += parent.childMax ?? 0;
    parent.children = null;
    const s = this.nodes.get(child.origin);
    if (parent.childError) {
      if (s) this.fail(s, parent);
      else this.lose(parent);
    } else {
      this.respond(parent);
    }
  }

  private dispatch(q: NodeState) {
    if (!q.backlog.length) return;
    const consumers = (this.out.get(q.node.id) ?? []).filter((e) => !e.down && !this.nodes.get(e.target)!.node.down);
    if (!consumers.length) return;
    for (let i = 0; i < consumers.length && q.backlog.length; i++) {
      const e = consumers[(q.rr + i) % consumers.length];
      const target = this.nodes.get(e.target)!;
      // Como el prefetch de RabbitMQ/Kafka: lo que puede procesar a la vez más lo que cabe en su cola local,
      // más lo que cabe "en el cable" (aquí el viaje va a cámara lenta y, si no, frenaría al consumidor).
      const travel = e.travelTime ?? DEFAULT_TRAVEL;
      const prefetch = hasCapacity(target.node.kind)
        ? this.workers(target) +
          paramValue(target.node.kind, target.node.params, "queueMax") +
          Math.ceil(paramValue(target.node.kind, target.node.params, "capacity") * travel)
        : DEFAULT_PREFETCH;
      while ((q.inflight.get(e.target) ?? 0) < prefetch && q.backlog.length) {
        const msg = q.backlog.shift()!;
        msg.sim += this.now - (msg.queuedAt ?? this.now);
        msg.queuedAt = null;
        msg.consumer = e.target;
        msg.credit = true;
        msg.path = [];
        q.inflight.set(e.target, (q.inflight.get(e.target) ?? 0) + 1);
        this.send(msg, e, 1);
      }
    }
    q.rr = (q.rr + 1) % 1_000_000;
  }

  /** Un mensaje de cola terminó: si falló, vuelve a la cola (entrega al menos una vez). */
  private asyncDone(msg: Request) {
    const q = this.nodes.get(msg.origin);
    if (!q) return;
    if (msg.credit) this.releaseCredit(msg);
    msg.consumer = undefined;
    if (msg.error) {
      msg.error = false;
      msg.queuedAt = this.now;
      msg.path = [];
      q.backlog.unshift(msg);
      return;
    }
    this.asyncLog.push(this.now);
  }

  /** El consumidor terminó de procesar (o falló): deja un hueco libre para el siguiente mensaje. */
  private releaseCredit(msg: Request) {
    msg.credit = false;
    const q = this.nodes.get(msg.origin);
    if (q && msg.consumer) q.inflight.set(msg.consumer, Math.max(0, (q.inflight.get(msg.consumer) ?? 0) - 1));
  }

  private fillWorkers(s: NodeState) {
    const workers = this.workers(s);
    while (s.busy.length < workers && s.queue.length) this.startFromQueue(s, this.now);
  }

  private startFromQueue(s: NodeState, at: number) {
    const req = s.queue.shift()!;
    const start = Math.max(at, req.queuedAt ?? at);
    req.sim += start - (req.queuedAt ?? start);
    req.queuedAt = null;
    this.startJob(s, req, start);
  }

  private startJob(s: NodeState, req: Request, at = this.now) {
    const service = this.serviceTime(s);
    req.sim += service;
    s.busy.push({ req, doneAt: at + service });
  }

  /** Un nodo cae: lo que tenía dentro falla. Una cola conserva sus mensajes (es duradera). */
  private crash(s: NodeState) {
    const inside = [...s.queue, ...s.busy.map((j) => j.req)];
    s.queue = [];
    s.busy = [];
    for (const r of inside) {
      r.queuedAt = null;
      this.fail(s, r);
    }
  }

  private fail(s: NodeState, req: Request) {
    this.bump(s.drops);
    if (!req.error) {
      req.error = true;
      // El cliente se entera al momento (conexión rechazada); el tren rojo que vuelve es solo visual.
      if (req.kind === "client" && req.logical) this.attemptFailed(req.logical, req);
    }
    this.respond(req);
  }

  /** La respuesta vuelve por la arista por la que llegó la petición al último nodo. */
  private respond(req: Request) {
    const hop = req.path[req.path.length - 1];
    const edge = hop && this.edges.get(hop.edge);
    if (!edge) return this.lose(req);
    this.send(req, edge, -1);
  }

  /** La petición no puede seguir (arista o nodo borrado, línea cortada): falla para quien la espera. */
  private lose(req: Request) {
    if (req.kind === "client") {
      if (req.logical) this.attemptFailed(req.logical, req);
    } else if (req.kind === "child") {
      req.error = true;
      this.childDone(req);
    } else {
      req.error = true;
      this.asyncDone(req);
    }
  }

  private send(req: Request, edge: SimEdge, dir: 1 | -1) {
    if (edge.down) {
      if (dir === -1) return this.lose(req);
      const from = this.nodes.get(edge.source);
      // Sin ruta: falla en el nodo que intentaba enviar (o se pierde si sale del origen).
      return from && req.path.length ? this.fail(from, req) : this.lose(req);
    }
    const latency = edge.latencyMs ?? 0;
    req.sim += (NET_MS + latency) / 1000;
    const travel = (edge.travelTime ?? DEFAULT_TRAVEL) + Math.min(latency / 1000, 1.5);
    const kind: TrainKind = req.error ? "error" : dir === -1 ? "response" : req.kind === "async" ? "async" : "request";
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

  // ── Utilidades ───────────────────────────────────────────

  private newRequest(kind: ReqKind, origin: string): Request {
    return { id: this.nextId++, kind, origin, path: [], error: false, sim: 0, queuedAt: null };
  }

  private freshState(node: SimNode): NodeState {
    return {
      node,
      rr: 0,
      queue: [],
      busy: [],
      arrivals: new Array(BUCKETS).fill(0),
      drops: new Array(BUCKETS).fill(0),
      overloadFor: 0,
      nextEmit: this.now,
      pending: [],
      healthy: new Map(),
      nextCheck: this.now,
      outstanding: new Map(),
      tokens: node.kind === "gateway" ? paramValue("gateway", node.params, "rateLimit") : 0,
      backlog: [],
      inflight: new Map(),
    };
  }

  private isOverloaded(s: NodeState): boolean {
    if (s.node.down) return false;
    if (s.node.kind === "queue") {
      const max = paramValue("queue", s.node.params, "queueMax");
      return s.backlog.length >= max * THRESHOLDS.overloadQueue;
    }
    if (!hasCapacity(s.node.kind)) return false;
    // Rechazando en el último segundo, o con la cola casi llena.
    const max = paramValue(s.node.kind, s.node.params, "queueMax");
    return sum(s.drops) > 0 || (max > 0 && s.queue.length >= max * THRESHOLDS.overloadQueue);
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
    const base = this.workers(s) / Math.max(1e-6, paramValue(s.node.kind, s.node.params, "capacity"));
    return s.node.slow ? base * SLOW_FACTOR : base;
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

/** Quita del principio los elementos que cumplen `old` (las ventanas están ordenadas por tiempo). */
function trimFront<T>(xs: T[], old: (x: T) => boolean) {
  let cut = 0;
  while (cut < xs.length && old(xs[cut])) cut++;
  if (cut) xs.splice(0, cut);
}
