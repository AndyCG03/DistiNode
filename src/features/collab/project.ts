/**
 * Archivo de proyecto (.distinode.json): el diagrama completo para guardarlo o compartirlo fuera de la sala.
 * `parseProject` valida todo lo que entra: un archivo importado es entrada no confiable.
 */

import { COMPONENTS, isComponentKind, type ParamKey, type Params } from "@/sim/components";
import { clampTraffic, newId } from "./ops";
import type { DiagramState, EdgeData, NodeData } from "./types";

export const PROJECT_VERSION = 1;
export const MAX_NODES = 300;
export const MAX_EDGES = 1200;

export interface ProjectFile {
  app: "distinode";
  version: number;
  name: string;
  exportedAt: string;
  sim: { traffic: number; chaos?: boolean; autoCrash?: boolean; restartSec?: number };
  nodes: {
    id: string;
    kind: string;
    label: string;
    x: number;
    y: number;
    params: Params;
    down?: boolean;
    slow?: boolean;
  }[];
  edges: { id: string; source: string; target: string; latencyMs?: number; down?: boolean }[];
}

export function toProject(diagram: DiagramState, name: string): ProjectFile {
  return {
    app: "distinode",
    version: PROJECT_VERSION,
    name,
    exportedAt: new Date().toISOString(),
    sim: {
      traffic: diagram.sim.traffic,
      chaos: diagram.sim.chaos ?? false,
      autoCrash: diagram.sim.autoCrash ?? false,
      restartSec: diagram.sim.restartSec ?? 8,
    },
    nodes: Object.values(diagram.nodes).map((n) => ({
      id: n.id,
      kind: n.kind,
      label: n.label,
      x: n.x,
      y: n.y,
      params: n.params,
      // Las caídas temporales (caos, sobrecarga) no se guardan; las manuales sí.
      ...(n.down && !n.downUntil ? { down: true } : {}),
      ...(n.slow && !n.slowUntil ? { slow: true } : {}),
    })),
    edges: Object.values(diagram.edges).map((e) => ({
      id: e.id,
      source: e.source,
      target: e.target,
      ...(e.latencyMs ? { latencyMs: e.latencyMs } : {}),
      ...(e.down && !e.downUntil ? { down: true } : {}),
    })),
  };
}

export type ParsedProject = {
  name: string;
  nodes: NodeData[];
  edges: EdgeData[];
  sim: { traffic: number; chaos: boolean; autoCrash: boolean; restartSec: number };
};

type Result = { ok: true; project: ParsedProject } | { ok: false; error: string };

const isObj = (v: unknown): v is Record<string, unknown> => typeof v === "object" && v !== null && !Array.isArray(v);
const num = (v: unknown, lo: number, hi: number, def: number) =>
  typeof v === "number" && Number.isFinite(v) ? Math.min(hi, Math.max(lo, v)) : def;
const text = (v: unknown, max: number, def: string) =>
  typeof v === "string" && v.trim() ? v.trim().slice(0, max) : def;

/** Valida y normaliza un proyecto importado. Los ids se regeneran para no chocar con los de la sala. */
export function parseProject(raw: unknown): Result {
  if (!isObj(raw) || raw.app !== "distinode") return { ok: false, error: "No es un proyecto de DistiNode." };
  if (typeof raw.version !== "number" || raw.version > PROJECT_VERSION) {
    return { ok: false, error: "El proyecto es de una versión más nueva de DistiNode." };
  }
  if (!Array.isArray(raw.nodes) || !Array.isArray(raw.edges)) return { ok: false, error: "Faltan nodos o conexiones." };
  if (raw.nodes.length > MAX_NODES || raw.edges.length > MAX_EDGES) {
    return { ok: false, error: `El proyecto es demasiado grande (máximo ${MAX_NODES} componentes).` };
  }

  const ids = new Map<string, string>();
  const nodes: NodeData[] = [];
  for (const n of raw.nodes) {
    if (!isObj(n) || !isComponentKind(n.kind) || typeof n.id !== "string") {
      return { ok: false, error: "Hay un componente que no se reconoce." };
    }
    if (ids.has(n.id)) return { ok: false, error: "Hay componentes repetidos." };
    const spec = COMPONENTS[n.kind];
    const params: Params = { ...spec.defaults };
    const rawParams = isObj(n.params) ? n.params : {};
    for (const p of spec.params) {
      params[p.key as ParamKey] = num(rawParams[p.key], p.min, p.max, spec.defaults[p.key] ?? p.min);
    }
    const id = newId();
    ids.set(n.id, id);
    nodes.push({
      id,
      kind: n.kind,
      label: text(n.label, 40, spec.name),
      x: Math.round(num(n.x, -1e6, 1e6, 0)),
      y: Math.round(num(n.y, -1e6, 1e6, 0)),
      params,
      down: n.down === true,
      slow: n.slow === true,
    });
  }

  const edges: EdgeData[] = [];
  const seen = new Set<string>();
  for (const e of raw.edges) {
    if (!isObj(e)) return { ok: false, error: "Hay una conexión mal formada." };
    const source = typeof e.source === "string" ? ids.get(e.source) : undefined;
    const target = typeof e.target === "string" ? ids.get(e.target) : undefined;
    if (!source || !target) return { ok: false, error: "Hay una conexión a un componente que no existe." };
    const key = `${source}>${target}`;
    if (source === target || seen.has(key)) continue;
    seen.add(key);
    edges.push({
      id: newId(),
      source,
      target,
      ...(typeof e.latencyMs === "number" ? { latencyMs: num(e.latencyMs, 0, 2000, 0) } : {}),
      ...(e.down === true ? { down: true } : {}),
    });
  }

  const sim = isObj(raw.sim) ? raw.sim : {};
  return {
    ok: true,
    project: {
      name: text(raw.name, 60, "Proyecto"),
      nodes,
      edges,
      sim: {
        traffic: clampTraffic(num(sim.traffic, 1, 200, 20)),
        chaos: sim.chaos === true,
        autoCrash: sim.autoCrash === true,
        restartSec: num(sim.restartSec, 1, 120, 8),
      },
    },
  };
}

/** Nombre de archivo seguro a partir del nombre de la sala. */
export function fileSlug(name: string): string {
  const slug = name
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40);
  return slug || "diagrama";
}
