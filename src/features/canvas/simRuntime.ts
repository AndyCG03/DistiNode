import type { EdgeRecord, NodeRecord } from "@/lib/liveblocks.config";
import type { Params } from "@/sim/components";
import { Engine } from "@/sim/engine";
import type { Metrics, NodeStats, SimGraph } from "@/sim/types";
import { endpoints, metroPoints, polyline, type Polyline } from "./geometry";
import { NODE_H, NODE_W } from "./StationNode";

/** Velocidad visual de los trenes (px del lienzo por segundo). */
const SPEED = 260;
const PUBLISH_MS = 200;

type NodeJson = Omit<NodeRecord, "params"> & { params: Params };

const ZERO: Metrics = { throughput: 0, avgLatencyMs: 0, errorRate: 0, inFlight: 0 };

/**
 * Puente entre el estado compartido (Liveblocks) y el motor local.
 * Cada navegador tiene el suyo; la interfaz lee instantáneas a 5 Hz y la capa de trenes a 60 fps.
 */
export class SimRuntime {
  readonly engine = new Engine({ seed: 2024 });
  readonly polylines = new Map<string, Polyline>();
  running = false;
  private stats = new Map<string, NodeStats | null>();
  private metricsSnap: Metrics = ZERO;
  private listeners = new Set<() => void>();
  private lastPublish = 0;
  private dirty = true;

  sync(nodes: Readonly<Record<string, NodeJson>>, edges: Readonly<Record<string, EdgeRecord>>) {
    this.polylines.clear();
    const graph: SimGraph = { nodes: [], edges: [] };
    for (const n of Object.values(nodes)) {
      graph.nodes.push({ id: n.id, kind: n.kind, params: n.params, down: n.down });
    }
    for (const e of Object.values(edges)) {
      const a = nodes[e.source];
      const b = nodes[e.target];
      if (!a || !b) continue;
      const { s, t } = endpoints(
        { x: a.x, y: a.y, width: NODE_W, height: NODE_H },
        { x: b.x, y: b.y, width: NODE_W, height: NODE_H },
      );
      const pl = polyline(metroPoints(s, t));
      this.polylines.set(e.id, pl);
      graph.edges.push({
        id: e.id,
        source: e.source,
        target: e.target,
        travelTime: clamp(pl.length / SPEED, 0.15, 1.4),
      });
    }
    this.engine.setGraph(graph);
    this.dirty = true;
  }

  setRunning(running: boolean) {
    this.running = running;
  }

  setTraffic(rps: number) {
    this.engine.setTraffic(rps);
  }

  /** Llamado en cada fotograma. */
  tick(dtSeconds: number, nowMs: number) {
    if (this.running) {
      this.engine.advance(dtSeconds);
      this.dirty = true;
    }
    if (this.dirty && nowMs - this.lastPublish >= PUBLISH_MS) {
      this.lastPublish = nowMs;
      this.dirty = false;
      this.publish();
    }
  }

  private publish() {
    this.stats.clear();
    this.metricsSnap = this.engine.metrics();
    for (const l of this.listeners) l();
  }

  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  /** Instantánea estable entre publicaciones (requisito de useSyncExternalStore). */
  getStats = (id: string): NodeStats | null => {
    if (!this.stats.has(id)) this.stats.set(id, this.engine.nodeStats(id));
    return this.stats.get(id) ?? null;
  };

  getMetrics = () => this.metricsSnap;
}

function clamp(v: number, lo: number, hi: number) {
  return Math.min(hi, Math.max(lo, v));
}
