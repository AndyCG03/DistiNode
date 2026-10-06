import { describe, expect, it } from "vitest";
import { TEMPLATES } from "@/sim/templates";
import { buildTemplate } from "./ops";
import { fileSlug, parseProject, toProject } from "./project";
import type { DiagramState } from "./types";

function diagramOf(id: string): DiagramState {
  const built = buildTemplate(TEMPLATES.find((t) => t.id === id)!);
  return {
    nodes: Object.fromEntries(built.nodes.map((n) => [n.id, n])),
    edges: Object.fromEntries(built.edges.map((e) => [e.id, e])),
    sim: { running: true, traffic: 120, chaos: true },
  };
}

describe("proyectos", () => {
  it("guardar y volver a abrir conserva el diagrama (con ids nuevos)", () => {
    const d = diagramOf("multi-region");
    const file = JSON.parse(JSON.stringify(toProject(d, "Mi sala")));
    const r = parseProject(file);
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    expect(r.project.name).toBe("Mi sala");
    expect(r.project.nodes).toHaveLength(Object.keys(d.nodes).length);
    expect(r.project.edges).toHaveLength(Object.keys(d.edges).length);
    expect(r.project.sim).toMatchObject({ traffic: 120, chaos: true });
    expect(r.project.edges.some((e) => e.latencyMs === 80)).toBe(true);
    const labels = (xs: { label: string }[]) => xs.map((n) => n.label).sort();
    expect(labels(r.project.nodes)).toEqual(labels(Object.values(d.nodes)));
    expect(r.project.nodes.every((n) => !(n.id in d.nodes))).toBe(true);
    // Las conexiones apuntan a los ids nuevos.
    const ids = new Set(r.project.nodes.map((n) => n.id));
    expect(r.project.edges.every((e) => ids.has(e.source) && ids.has(e.target))).toBe(true);
  });

  it("no guarda las caídas temporales del caos", () => {
    const d = diagramOf("basico");
    const [a, b] = Object.values(d.nodes);
    d.nodes = { ...d.nodes, [a.id]: { ...a, down: true, downUntil: Date.now() + 5000 }, [b.id]: { ...b, down: true } };
    const file = toProject(d, "x");
    expect(file.nodes.find((n) => n.id === a.id)!.down).toBeUndefined();
    expect(file.nodes.find((n) => n.id === b.id)!.down).toBe(true);
  });

  it("rechaza archivos que no son proyectos", () => {
    expect(parseProject(null).ok).toBe(false);
    expect(parseProject({ app: "otra" }).ok).toBe(false);
    expect(parseProject({ app: "distinode", version: 99, nodes: [], edges: [] }).ok).toBe(false);
    const bad = parseProject({ app: "distinode", version: 1, nodes: [{ id: "a", kind: "nave-espacial" }], edges: [] });
    expect(bad.ok).toBe(false);
    const dangling = parseProject({
      app: "distinode",
      version: 1,
      nodes: [{ id: "a", kind: "server", label: "S", x: 0, y: 0 }],
      edges: [{ id: "e", source: "a", target: "fantasma" }],
    });
    expect(dangling.ok).toBe(false);
  });

  it("acota los valores fuera de rango", () => {
    const r = parseProject({
      app: "distinode",
      version: 1,
      name: "  ",
      sim: { traffic: 99999 },
      nodes: [
        {
          id: "a",
          kind: "server",
          label: "<b>x</b>".repeat(20),
          x: 1e12,
          y: "no",
          params: { capacity: -5, queueMax: 1e9 },
        },
      ],
      edges: [],
    });
    expect(r.ok).toBe(true);
    if (!r.ok) return;
    const n = r.project.nodes[0];
    expect(n.params.capacity).toBe(1);
    expect(n.params.queueMax).toBe(5000);
    expect(n.label.length).toBeLessThanOrEqual(40);
    expect(n.x).toBe(1e6);
    expect(n.y).toBe(0);
    expect(r.project.sim.traffic).toBe(200);
    expect(r.project.name).toBe("Proyecto");
  });

  it("crea nombres de archivo seguros", () => {
    expect(fileSlug("Práctica 3 — Caché/BD")).toBe("practica-3-cache-bd");
    expect(fileSlug("***")).toBe("diagrama");
  });
});
