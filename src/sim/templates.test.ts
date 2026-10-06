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
    edges: t.edges.map(([a, b]) => ({ id: `${a}>${b}`, source: a, target: b, travelTime: 0.3 })),
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
});
