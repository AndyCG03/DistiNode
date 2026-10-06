import { describe, expect, it } from "vitest";
import { COMPONENTS } from "./components";
import { Engine } from "./engine";
import { TEMPLATES } from "./templates";
import type { SimGraph } from "./types";

function graphOf(id: string): SimGraph {
  const t = TEMPLATES.find((x) => x.id === id)!;
  return {
    nodes: t.nodes.map((n) => ({
      id: n.key,
      kind: n.kind,
      params: { ...COMPONENTS[n.kind].defaults, ...n.params },
      down: false,
    })),
    edges: t.edges.map(([a, b, opts]) => ({
      id: `${a}>${b}`,
      source: a,
      target: b,
      travelTime: 0.3,
      latencyMs: opts?.latencyMs,
    })),
  };
}

describe("plantillas", () => {
  it("tienen claves únicas y aristas válidas", () => {
    for (const t of TEMPLATES) {
      const keys = new Set(t.nodes.map((n) => n.key));
      expect(keys.size).toBe(t.nodes.length);
      for (const [a, b] of t.edges) {
        expect(keys.has(a), `${t.id}: ${a}`).toBe(true);
        expect(keys.has(b), `${t.id}: ${b}`).toBe(true);
      }
    }
  });

  for (const t of TEMPLATES) {
    it(`«${t.name}» arranca sana con su tráfico por defecto`, () => {
      const e = new Engine({ seed: 11 });
      e.setGraph(graphOf(t.id));
      e.setTraffic(t.traffic);
      for (let i = 0; i < 1200; i++) e.step(); // 12 s
      const m = e.metrics();
      expect(m.errorRate, t.id).toBeLessThan(0.02);
      expect(m.throughput, t.id).toBeGreaterThan(t.traffic * 0.85);
      // El trabajo en segundo plano no se acumula sin control.
      expect(m.backlog, t.id).toBeLessThan(150);
    });
  }

  it("la tormenta de reintentos colapsa con un poco más de tráfico", () => {
    const e = new Engine({ seed: 3 });
    e.setGraph(graphOf("tormenta-de-reintentos"));
    e.setTraffic(58);
    for (let i = 0; i < 1500; i++) e.step();
    const m = e.metrics();
    expect(m.retryRate).toBeGreaterThan(15);
    expect(m.errorRate).toBeGreaterThan(0.2);
  });

  it("streaming: sin la CDN el origen se hunde", () => {
    const g = graphOf("streaming-video");
    g.nodes.find((n) => n.id === "cdn")!.params.hitRate = 50;
    const e = new Engine({ seed: 4 });
    e.setGraph(g);
    e.setTraffic(200);
    for (let i = 0; i < 1000; i++) e.step();
    expect(e.nodeStats("p1")!.status).toBe("hot");
    expect(e.metrics().errorRate).toBeGreaterThan(0.1);
  });

  it("mensajería: con la base de datos caída no se pierde ningún mensaje", () => {
    const g = graphOf("mensajeria");
    const e = new Engine({ seed: 4 });
    e.setGraph(g);
    e.setTraffic(150);
    for (let i = 0; i < 300; i++) e.step();
    g.nodes.find((n) => n.id === "db")!.down = true;
    e.setGraph(g);
    for (let i = 0; i < 1000; i++) e.step();
    expect(e.metrics().errorRate).toBe(0); // los usuarios no lo notan
    const stuck = e.metrics().backlog;
    expect(stuck).toBeGreaterThan(500);
    g.nodes.find((n) => n.id === "db")!.down = false;
    e.setGraph(g);
    for (let i = 0; i < 2500; i++) e.step();
    expect(e.metrics().backlog).toBeLessThan(stuck / 4); // se pone al día
  });

  it("dos regiones: si se corta Europa, todo va a América con más latencia", () => {
    const g = graphOf("multi-region");
    const e = new Engine({ seed: 4 });
    e.setGraph(g);
    e.setTraffic(80);
    for (let i = 0; i < 600; i++) e.step();
    const before = e.metrics().avgLatencyMs;
    g.edges = g.edges.map((ed) => (ed.id === "glb>eu" ? { ...ed, down: true } : ed));
    e.setGraph(g);
    for (let i = 0; i < 600; i++) e.step();
    expect(e.nodeStats("eu")!.arrivalRate).toBe(0);
    expect(e.metrics().errorRate).toBe(0);
    expect(e.metrics().avgLatencyMs).toBeGreaterThan(before + 60);
  });
});
