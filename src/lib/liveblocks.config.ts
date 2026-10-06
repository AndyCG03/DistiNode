import type { LiveMap, LiveObject } from "@liveblocks/client";
import type { ComponentKind, Params } from "@/sim/components";

/** Registro de un nodo en el almacenamiento compartido. */
export type NodeRecord = {
  id: string;
  kind: ComponentKind;
  label: string;
  x: number;
  y: number;
  /** LiveObject aparte: dos personas pueden editar parámetros distintos a la vez. */
  params: LiveObject<Params>;
  down: boolean;
};

export type EdgeRecord = {
  id: string;
  source: string;
  target: string;
};

export type SimShared = {
  running: boolean;
  /** Peticiones por segundo totales, 1–200. */
  traffic: number;
};

export type Cursor = { x: number; y: number };

declare global {
  interface Liveblocks {
    Presence: {
      cursor: Cursor | null;
      selected: string[];
    };
    Storage: {
      nodes: LiveMap<string, LiveObject<NodeRecord>>;
      edges: LiveMap<string, LiveObject<EdgeRecord>>;
      sim: LiveObject<SimShared>;
    };
    UserMeta: {
      id: string;
      info: { name: string; color: string; avatar?: string };
    };
    RoomEvent: { type: "notice"; text: string };
  }
}

export const roomIdFor = (id: string) => `distinode:${id}`;
