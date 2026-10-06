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
  /** Si se cayó solo (caos o sobrecarga): cuándo vuelve a arrancar (ms desde epoch). */
  downUntil?: number | null;
  downReason?: DownReason | null;
  /** Degradado: procesa más lento. */
  slow?: boolean;
  slowUntil?: number | null;
};

export type DownReason = "manual" | "caos" | "sobrecarga";

export type EdgeRecord = {
  id: string;
  source: string;
  target: string;
  /** Latencia de red añadida (ms). */
  latencyMs?: number;
  /** Conexión cortada. */
  down?: boolean;
  downUntil?: number | null;
};

export type SimShared = {
  running: boolean;
  /** Peticiones por segundo totales, 1–200. */
  traffic: number;
  /** Modo caos: caídas, cortes y degradaciones al azar. */
  chaos?: boolean;
  /** Un nodo saturado demasiado tiempo se cae y se reinicia solo. */
  autoCrash?: boolean;
  /** Segundos que tarda en volver un nodo caído solo. */
  restartSec?: number;
};

export const SIM_DEFAULTS = { chaos: false, autoCrash: false, restartSec: 8 } as const;

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
