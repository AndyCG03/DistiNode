import type { Cursor, EdgeRecord, SimShared } from "@/lib/liveblocks.config";
import type { ComponentKind, ParamKey, Params } from "@/sim/components";

/** Un nodo tal y como lo ve la interfaz (sin tipos de Liveblocks). */
export type NodeData = {
  id: string;
  kind: ComponentKind;
  label: string;
  x: number;
  y: number;
  params: Params;
  down: boolean;
};
export type EdgeData = EdgeRecord;

export type DiagramState = {
  nodes: Readonly<Record<string, NodeData>>;
  edges: Readonly<Record<string, EdgeData>>;
  sim: SimShared;
};

/** Todas las escrituras al diagrama. Dos implementaciones: Liveblocks (salas) y local (demo). */
export interface DiagramActions {
  addNode(kind: ComponentKind, x: number, y: number): { id: string; label: string };
  moveNode(id: string, x: number, y: number): void;
  removeElements(nodeIds: string[], edgeIds: string[]): void;
  connect(source: string, target: string): boolean;
  setParam(id: string, key: ParamKey, value: number): void;
  setLabel(id: string, label: string): void;
  setDown(id: string, down: boolean): void;
  setRunning(running: boolean): void;
  setTraffic(traffic: number): void;
  loadExample(): boolean;
  /** Aviso breve para los demás: "Ana tumbó Servidor 2". */
  notify(action: string): void;
}

export type Person = { key: string; name: string; color: string; avatar?: string };
export type PersonCursor = Person & { cursor: Cursor | null };
export type PersonSelection = Person & { selected: readonly string[] };
export type Notice = { text: string; color: string };
export type PresenceUpdate = Partial<{ cursor: Cursor | null; selected: string[] }>;
export type CollabMode = "live" | "local";
