import { COMPONENTS, nextLabel, type ComponentKind } from "@/sim/components";
import { GRID, type Template } from "@/sim/templates";
import type { DiagramState, EdgeData, NodeData } from "./types";

export const newId = () => crypto.randomUUID().slice(0, 12);

export const EMPTY_DIAGRAM: DiagramState = { nodes: {}, edges: {}, sim: { running: false, traffic: 20 } };

export const clampTraffic = (t: number) => Math.min(200, Math.max(1, Math.round(t)));

export function makeNode(
  kind: ComponentKind,
  x: number,
  y: number,
  existingLabels: Iterable<string>,
  label?: string,
): NodeData {
  return {
    id: newId(),
    kind,
    label: label ?? nextLabel(kind, existingLabels),
    x: Math.round(x),
    y: Math.round(y),
    params: { ...COMPONENTS[kind].defaults },
    down: false,
  };
}

/** Nodos y aristas de una plantilla, con ids nuevos y posiciones en píxeles. */
export function buildTemplate(t: Template): { nodes: NodeData[]; edges: EdgeData[] } {
  const ids = new Map<string, string>();
  const nodes = t.nodes.map((n) => {
    const node: NodeData = {
      ...makeNode(n.kind, n.col * GRID.x, n.row * GRID.y, [], n.label),
      params: { ...COMPONENTS[n.kind].defaults, ...n.params },
    };
    ids.set(n.key, node.id);
    return node;
  });
  const edges = t.edges.map(([a, b]) => ({ id: newId(), source: ids.get(a)!, target: ids.get(b)! }));
  return { nodes, edges };
}
