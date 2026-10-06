import { describe, expect, it } from "vitest";
import { COMPONENTS, nextLabel, type ComponentKind, type Params } from "./components";
import { Engine, MAX_FRAME } from "./engine";
import { createRng } from "./rng";
import type { SimEdge, SimGraph, SimNode } from "./types";

const node = (id: string, kind: ComponentKind, params: Params = {}, down = false): SimNode => ({
  id,
  kind,
  params: { ...COMPONENTS[kind].defaults, ...params },
  down,
});
const edge = (source: string, target: string, travelTime = 0.1): SimEdge => ({
  id: `${source}>${target}`,
  source,
  target,
  travelTime,
});

/** Cliente → Balanceador → Servidor(es) → Base de datos */
function example(servers = 1, opts: { serverDown?: string[] } = {}): SimGraph {
  const nodes = [node("c", "client"), node("lb", "balancer"), node("db", "database")];
  const edges = [edge("c", "lb")];
  for (let i = 1; i <= servers; i++) {
    const id = `s${i}`;
    nodes.push(node(id, "server", {}, opts.serverDown?.includes(id)));
    edges.push(edge("lb", id), edge(id, "db"));
  }
  return { nodes, edges };
}

function run(engine: Engine, seconds: number) {
  const steps = Math.round(seconds / engine.dt);
  for (let i = 0; i < steps; i++) engine.step();
}

describe("rng", () => {
  it("la misma semilla da la misma secuencia", () => {
    const a = createRng(42);
    const b = createRng(42);
    const c = createRng(43);
    const sa = Array.from({ length: 5 }, a);
    expect(Array.from({ length: 5 }, b)).toEqual(sa);
    expect(Array.from({ length: 5 }, c)).not.toEqual(sa);
    for (const x of sa) {
      expect(x).toBeGreaterThanOrEqual(0);
      expect(x).toBeLessThan(1);
    }
  });
});

describe("paso fijo", () => {
  it("advance acumula el tiempo real en pasos de dt", () => {
    const e = new Engine({ dt: 0.01 });
    expect(e.advance(0.025)).toBe(2);
    expect(e.advance(0.005)).toBe(1);
    expect(e.time).toBeCloseTo(0.03, 10);
  });

  it("no intenta recuperar más de MAX_FRAME tras una pausa larga", () => {
    const e = new Engine({ dt: 0.01 });
    expect(e.advance(10)).toBe(Math.round(MAX_FRAME / 0.01));
  });

  it("es determinista con la misma semilla", () => {
    const g: SimGraph = {
      nodes: [node("c", "client"), node("k", "cache", { hitRate: 50 }), node("db", "database")],
      edges: [edge("c", "k"), edge("k", "db")],
    };
    const a = new Engine({ seed: 7 });
    const b = new Engine({ seed: 7 });
    for (const e of [a, b]) {
      e.setGraph(g);
      e.setTraffic(80);
      run(e, 5);
    }
    expect(a.metrics()).toEqual(b.metrics());
    expect(a.nodeStats("db")).toEqual(b.nodeStats("db"));
  });
});

describe("flujo básico", () => {
  it("con poco tráfico todo responde, sin errores y en verde", () => {
    const e = new Engine();
    e.setGraph(example(1));
    e.setTraffic(20);
    run(e, 10);
    const m = e.metrics();
    expect(m.throughput).toBeGreaterThan(17);
    expect(m.throughput).toBeLessThan(23);
    expect(m.errorRate).toBe(0);
    // 80 ms en el servidor + 25 ms en la base de datos
    expect(m.avgLatencyMs).toBeGreaterThan(95);
    expect(m.avgLatencyMs).toBeLessThan(130);
    expect(e.nodeStats("s1")!.status).toBe("ok");
    expect(e.nodeStats("db")!.status).toBe("ok");
  });

  it("hay trenes de petición y de respuesta en tránsito", () => {
    const e = new Engine();
    e.setGraph(example(1));
    e.setTraffic(50);
    run(e, 3);
    const kinds = new Set(e.trains().map((t) => t.kind));
    expect(kinds.has("request")).toBe(true);
    expect(kinds.has("response")).toBe(true);
    for (const t of e.trains()) {
      expect(t.progress).toBeGreaterThanOrEqual(0);
      expect(t.progress).toBeLessThanOrEqual(1);
    }
  });

  it("sin tráfico los nodos quedan en reposo", () => {
    const e = new Engine();
    e.setGraph(example(1));
    e.setTraffic(0);
    run(e, 2);
    expect(e.trains()).toHaveLength(0);
    expect(e.nodeStats("s1")!.status).toBe("idle");
  });
});

describe("saturación", () => {
  it("con más tráfico que capacidad el servidor se pone rojo, sube la latencia y aparecen errores", () => {
    const e = new Engine();
    e.setGraph(example(1));
    e.setTraffic(120);
    run(e, 12);
    const s = e.nodeStats("s1")!;
    expect(s.status).toBe("hot");
    expect(s.rho).toBeGreaterThan(1);
    expect(s.queue).toBeGreaterThan(s.queueMax * 0.5);
    const m = e.metrics();
    expect(m.errorRate).toBeGreaterThan(0.3);
    expect(m.avgLatencyMs).toBeGreaterThan(400);
    // El servidor no puede entregar más de su capacidad.
    expect(m.throughput).toBeLessThan(55);
  });

  it("cerca del límite se pone ámbar", () => {
    const e = new Engine();
    e.setGraph(example(1));
    e.setTraffic(44);
    run(e, 8);
    expect(e.nodeStats("s1")!.status).toBe("warn");
  });

  it("un segundo servidor detrás del balanceador lo devuelve a verde", () => {
    const e = new Engine();
    e.setGraph(example(1));
    e.setTraffic(70);
    run(e, 8);
    expect(e.nodeStats("s1")!.status).toBe("hot");

    e.setGraph(example(2));
    run(e, 10);
    expect(e.nodeStats("s1")!.status).toBe("ok");
    expect(e.nodeStats("s2")!.status).toBe("ok");
    expect(e.nodeStats("s1")!.arrivalRate).toBeCloseTo(35, -1);
    const m = e.metrics();
    expect(m.errorRate).toBe(0);
    expect(m.throughput).toBeGreaterThan(64);
  });
});

describe("caídas y chequeo de salud", () => {
  it("al tumbar un servidor hay errores y, tras el chequeo, el balanceador lo esquiva", () => {
    const e = new Engine();
    e.setGraph(example(2));
    e.setTraffic(40);
    run(e, 5);
    expect(e.metrics().errorRate).toBe(0);

    e.setGraph(example(2, { serverDown: ["s1"] }));
    // Los errores se ven al momento, sin esperar a que el tren rojo vuelva al cliente.
    run(e, 0.5);
    expect(e.metrics().errorRate).toBeGreaterThan(0);
    run(e, 1);
    expect(e.nodeStats("s1")!.status).toBe("down");

    // Chequeo cada 1 s: pasada la ventana de métricas ya no quedan errores.
    run(e, 3);
    const m = e.metrics();
    expect(m.errorRate).toBe(0);
    expect(m.throughput).toBeGreaterThan(35);
    expect(e.nodeStats("s1")!.arrivalRate).toBe(0);
    expect(e.nodeStats("s2")!.arrivalRate).toBeGreaterThan(35);
  });

  it("al revivirlo vuelve a recibir tráfico", () => {
    const e = new Engine();
    e.setGraph(example(2, { serverDown: ["s1"] }));
    e.setTraffic(40);
    run(e, 3);
    e.setGraph(example(2));
    run(e, 3);
    expect(e.nodeStats("s1")!.arrivalRate).toBeGreaterThan(15);
  });

  it("sin destinos sanos el balanceador falla las peticiones", () => {
    const e = new Engine();
    e.setGraph(example(1, { serverDown: ["s1"] }));
    e.setTraffic(20);
    run(e, 4);
    expect(e.metrics().errorRate).toBe(1);
    expect(e.nodeStats("lb")!.status).toBe("hot");
    expect(e.trains().some((t) => t.kind === "error")).toBe(true);
  });

  it("lo que había en la cola de un nodo que cae, falla", () => {
    const e = new Engine();
    e.setGraph(example(1));
    e.setTraffic(150);
    run(e, 4);
    expect(e.nodeStats("s1")!.queue).toBeGreaterThan(0);
    e.setGraph(example(1, { serverDown: ["s1"] }));
    expect(e.nodeStats("s1")!.queue).toBe(0);
    expect(e.trains().filter((t) => t.kind === "error").length).toBeGreaterThan(10);
  });
});

describe("caché", () => {
  it("con 70 % de aciertos solo ~30 % llega a la base de datos", () => {
    const e = new Engine({ seed: 3 });
    e.setGraph({
      nodes: [node("c", "client"), node("k", "cache", { hitRate: 70 }), node("db", "database")],
      edges: [edge("c", "k"), edge("k", "db")],
    });
    e.setTraffic(100);
    run(e, 10);
    const ratio = e.nodeStats("db")!.arrivalRate / e.nodeStats("k")!.arrivalRate;
    expect(ratio).toBeGreaterThan(0.2);
    expect(ratio).toBeLessThan(0.4);
  });
});

describe("cambios del grafo", () => {
  it("borrar un nodo con tráfico en vuelo no rompe nada", () => {
    const e = new Engine();
    e.setGraph(example(2));
    e.setTraffic(60);
    run(e, 3);
    const g = example(2);
    g.nodes = g.nodes.filter((n) => n.id !== "s2");
    g.edges = g.edges.filter((ed) => ed.source !== "s2" && ed.target !== "s2");
    e.setGraph(g);
    expect(() => run(e, 3)).not.toThrow();
    expect(e.nodeStats("s2")).toBeNull();
    expect(e.trains().every((t) => !t.edgeId.includes("s2"))).toBe(true);
  });

  it("un ciclo no se queda dando vueltas para siempre", () => {
    const e = new Engine();
    e.setGraph({
      nodes: [node("c", "client"), node("a", "balancer"), node("b", "balancer")],
      edges: [edge("c", "a", 0.01), edge("a", "b", 0.01), edge("b", "a", 0.01)],
    });
    e.setTraffic(10);
    run(e, 5);
    expect(e.metrics().errorRate).toBe(1);
  });

  it("reset vuelve a t = 0 y conserva el grafo", () => {
    const e = new Engine();
    e.setGraph(example(1));
    e.setTraffic(30);
    run(e, 2);
    e.reset();
    expect(e.time).toBe(0);
    expect(e.trains()).toHaveLength(0);
    expect(e.nodeStats("s1")).not.toBeNull();
  });
});

describe("componentes nuevos", () => {
  it("el API Gateway rechaza lo que pasa de su límite", () => {
    const e = new Engine();
    e.setGraph({
      nodes: [node("c", "client"), node("g", "gateway", { rateLimit: 50 }), node("s", "server", { capacity: 200 })],
      edges: [edge("c", "g"), edge("g", "s")],
    });
    e.setTraffic(100);
    run(e, 6);
    const m = e.metrics();
    expect(m.errorRate).toBeGreaterThan(0.4);
    expect(m.errorRate).toBeLessThan(0.6);
    expect(m.throughput).toBeCloseTo(50, -1);
    expect(e.nodeStats("g")!.status).toBe("hot");
    expect(e.nodeStats("s")!.arrivalRate).toBeLessThan(55);
  });

  it("una CDN con 80 % de aciertos solo deja pasar ~20 %", () => {
    const e = new Engine({ seed: 5 });
    e.setGraph({
      nodes: [node("c", "client"), node("cdn", "cdn", { hitRate: 80 }), node("s", "server")],
      edges: [edge("c", "cdn"), edge("cdn", "s")],
    });
    e.setTraffic(100);
    run(e, 8);
    const ratio = e.nodeStats("s")!.arrivalRate / e.nodeStats("cdn")!.arrivalRate;
    expect(ratio).toBeGreaterThan(0.12);
    expect(ratio).toBeLessThan(0.28);
  });

  it("una cola responde al momento y los workers procesan a su ritmo", () => {
    const e = new Engine();
    e.setGraph({
      nodes: [
        node("c", "client"),
        node("q", "queue", { queueMax: 1000 }),
        node("w", "worker", { capacity: 10, processingMs: 100 }),
      ],
      edges: [edge("c", "q"), edge("q", "w")],
    });
    e.setTraffic(40);
    run(e, 10);
    const m = e.metrics();
    expect(m.errorRate).toBe(0);
    expect(m.throughput).toBeGreaterThan(35); // el cliente no espera al worker
    expect(m.avgLatencyMs).toBeLessThan(20);
    expect(m.asyncThroughput).toBeCloseTo(10, -1);
    expect(m.backlog).toBeGreaterThan(200); // se acumula trabajo
  });

  it("si un worker cae, sus mensajes vuelven a la cola y se procesan al revivir", () => {
    const g = (down: boolean): SimGraph => ({
      nodes: [node("c", "client"), node("q", "queue"), node("w", "worker", {}, down)],
      edges: [edge("c", "q"), edge("q", "w")],
    });
    const e = new Engine();
    e.setGraph(g(false));
    e.setTraffic(20);
    run(e, 3);
    e.setGraph(g(true));
    run(e, 3);
    expect(e.metrics().asyncThroughput).toBe(0);
    const waiting = e.metrics().backlog;
    expect(waiting).toBeGreaterThan(50);
    expect(e.metrics().errorRate).toBe(0); // la cola sigue aceptando
    e.setGraph(g(false));
    run(e, 6);
    expect(e.metrics().asyncThroughput).toBeGreaterThan(15);
    expect(e.metrics().backlog).toBeLessThan(waiting);
  });

  it("en modo «a todos» el servidor espera al más lento y falla si falla uno", () => {
    const g = (dbDown: boolean): SimGraph => ({
      nodes: [
        node("c", "client"),
        node("s", "server", { fanout: 1, capacity: 100 }),
        node("a", "database", { processingMs: 20 }),
        node("b", "database", { processingMs: 200, capacity: 200 }, dbDown),
      ],
      edges: [edge("c", "s"), edge("s", "a"), edge("s", "b")],
    });
    const e = new Engine();
    e.setGraph(g(false));
    e.setTraffic(20);
    run(e, 6);
    const lat = e.metrics().avgLatencyMs;
    expect(lat).toBeGreaterThan(280); // 80 (servidor) + 200 (la BD lenta)
    expect(lat).toBeLessThan(330);
    expect(e.metrics().errorRate).toBe(0);
    e.setGraph(g(true));
    run(e, 4);
    expect(e.metrics().errorRate).toBe(1);
  });

  it("menos conexiones manda más tráfico al servidor rápido", () => {
    const g = (algo: number): SimGraph => ({
      nodes: [
        node("c", "client"),
        node("lb", "balancer", { lbAlgorithm: algo }),
        node("fast", "server", { capacity: 100, processingMs: 20 }),
        node("slow", "server", { capacity: 100, processingMs: 300 }),
      ],
      edges: [edge("c", "lb"), edge("lb", "fast"), edge("lb", "slow")],
    });
    const share = (algo: number) => {
      const e = new Engine();
      e.setGraph(g(algo));
      e.setTraffic(80);
      run(e, 8);
      return e.nodeStats("fast")!.arrivalRate / (e.nodeStats("fast")!.arrivalRate + e.nodeStats("slow")!.arrivalRate);
    };
    expect(share(0)).toBeCloseTo(0.5, 1);
    expect(share(1)).toBeGreaterThan(0.6);
  });
});

describe("tiempos de espera, reintentos y degradación", () => {
  const saturated = (client: Params): SimGraph => ({
    nodes: [node("c", "client", client), node("s", "server", { capacity: 50, queueMax: 200 })],
    edges: [edge("c", "s")],
  });

  it("con poco tiempo de espera, la cola de un servidor saturado se convierte en errores", () => {
    const strict = new Engine();
    strict.setGraph(saturated({ timeoutMs: 300 }));
    strict.setTraffic(70);
    run(strict, 10);
    const patient = new Engine();
    patient.setGraph(saturated({ timeoutMs: 0 }));
    patient.setTraffic(70);
    run(patient, 10);
    expect(strict.metrics().errorRate).toBeGreaterThan(patient.metrics().errorRate + 0.1);
    expect(strict.metrics().p95LatencyMs).toBeLessThanOrEqual(300);
  });

  it("los reintentos multiplican la carga sobre un servidor saturado (tormenta de reintentos)", () => {
    const calm = new Engine();
    calm.setGraph(saturated({ timeoutMs: 500, retries: 0 }));
    calm.setTraffic(60);
    run(calm, 10);
    const storm = new Engine();
    storm.setGraph(saturated({ timeoutMs: 500, retries: 3 }));
    storm.setTraffic(60);
    run(storm, 10);
    expect(storm.metrics().retryRate).toBeGreaterThan(10);
    expect(storm.nodeStats("s")!.arrivalRate).toBeGreaterThan(calm.nodeStats("s")!.arrivalRate * 1.3);
  });

  it("un reintento salva los fallos sueltos", () => {
    const g = (retries: number, bDown: boolean): SimGraph => ({
      nodes: [
        node("c", "client", { retries }),
        node("lb", "balancer", { healthCheckMs: 10000 }),
        node("a", "server"),
        node("b", "server", {}, bDown),
      ],
      edges: [edge("c", "lb"), edge("lb", "a"), edge("lb", "b")],
    });
    const withRetries = (retries: number) => {
      const e = new Engine();
      e.setGraph(g(retries, false));
      e.setTraffic(20);
      run(e, 1);
      e.setGraph(g(retries, true)); // b cae justo después de un chequeo
      run(e, 4);
      return e;
    };
    const once = withRetries(0);
    const twice = withRetries(3);
    // El balanceador aún no sabe que b está caído: la mitad falla sin reintentos.
    expect(once.metrics().errorRate).toBeGreaterThan(0.3);
    expect(twice.metrics().errorRate).toBeLessThan(0.12);
  });

  it("un servidor degradado procesa cuatro veces más lento", () => {
    const g = (slow: boolean): SimGraph => ({
      nodes: [node("c", "client"), { ...node("s", "server", { capacity: 100 }), slow }],
      edges: [edge("c", "s")],
    });
    const e = new Engine();
    e.setGraph(g(true));
    e.setTraffic(10);
    run(e, 5);
    expect(e.metrics().avgLatencyMs).toBeGreaterThan(300);
    expect(e.nodeStats("s")!.status).toBe("warn");
  });

  it("una línea cortada falla y el balanceador la esquiva tras el chequeo", () => {
    const g = (cut: boolean): SimGraph => {
      const base = example(2);
      base.edges = base.edges.map((ed) => (ed.id === "lb>s1" ? { ...ed, down: cut } : ed));
      return base;
    };
    const e = new Engine();
    e.setGraph(g(false));
    e.setTraffic(40);
    run(e, 3);
    e.setGraph(g(true));
    run(e, 0.5);
    expect(e.metrics().errorRate).toBeGreaterThan(0);
    run(e, 3);
    expect(e.metrics().errorRate).toBe(0);
    expect(e.nodeStats("s1")!.arrivalRate).toBe(0);
  });

  it("la latencia de red de una línea cuenta en ida y vuelta", () => {
    const g = (latencyMs: number): SimGraph => ({
      nodes: [node("c", "client"), node("s", "server")],
      edges: [{ ...edge("c", "s"), latencyMs }],
    });
    const lat = (ms: number) => {
      const e = new Engine();
      e.setGraph(g(ms));
      e.setTraffic(10);
      run(e, 6);
      return e.metrics().avgLatencyMs;
    };
    expect(lat(50) - lat(0)).toBeCloseTo(100, -1);
  });

  it("la sobrecarga sostenida se mide para que el supervisor pueda tumbar el nodo", () => {
    const e = new Engine();
    e.setGraph(example(1));
    e.setTraffic(150);
    run(e, 8);
    expect(e.nodeStats("s1")!.overloadFor).toBeGreaterThan(3);
    e.setTraffic(5);
    run(e, 8);
    expect(e.nodeStats("s1")!.overloadFor).toBe(0);
  });
});

describe("registro de componentes", () => {
  it("numera las etiquetas con el primer hueco libre", () => {
    expect(nextLabel("server", [])).toBe("Servidor 1");
    expect(nextLabel("server", ["Servidor 1", "Servidor 3"])).toBe("Servidor 2");
    expect(nextLabel("client", [])).toBe("Cliente");
    expect(nextLabel("client", ["Cliente"])).toBe("Cliente 1");
    expect(nextLabel("gateway", [])).toBe("API Gateway");
  });
});
