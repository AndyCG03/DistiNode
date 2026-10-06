import { COMPONENTS, nextLabel, type ComponentKind } from "@/sim/components";
import type { DiagramState, NodeData } from "./types";

export const newId = () => crypto.randomUUID().slice(0, 12);

export const EMPTY_DIAGRAM: DiagramState = { nodes: {}, edges: {}, sim: { running: false, traffic: 20 } };

/** Cliente → Balanceador → Servidor → Base de datos. */
export const EXAMPLE: { kind: ComponentKind; label: string; x: number; y: number }[] = [
  { kind: "client", label: "Cliente", x: 0, y: 0 },
  { kind: "balancer", label: "Balanceador", x: 260, y: 0 },
  { kind: "server", label: "Servidor 1", x: 520, y: 0 },
  { kind: "database", label: "Base de datos 1", x: 800, y: 0 },
];

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
