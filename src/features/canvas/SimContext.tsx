"use client";

import { useStorage } from "@liveblocks/react/suspense";
import { createContext, useContext, useEffect, useState, useSyncExternalStore } from "react";
import type { Metrics, NodeStats } from "@/sim/types";
import { SimRuntime } from "./simRuntime";

const SimContext = createContext<SimRuntime | null>(null);

/** Crea el motor local y lo mantiene al día con el estado compartido de la sala. */
export function SimProvider({ children }: { children: React.ReactNode }) {
  const [runtime] = useState(() => new SimRuntime());
  const nodes = useStorage((root) => root.nodes);
  const edges = useStorage((root) => root.edges);
  const running = useStorage((root) => root.sim.running);
  const traffic = useStorage((root) => root.sim.traffic);

  useEffect(() => runtime.sync(nodes, edges), [runtime, nodes, edges]);
  useEffect(() => runtime.setTraffic(traffic), [runtime, traffic]);
  useEffect(() => runtime.setRunning(running), [runtime, running]);

  return <SimContext.Provider value={runtime}>{children}</SimContext.Provider>;
}

export function useSimRuntime(): SimRuntime {
  const rt = useContext(SimContext);
  if (!rt) throw new Error("useSimRuntime fuera de <SimProvider>");
  return rt;
}

export function useNodeStats(id: string): NodeStats | null {
  const rt = useSimRuntime();
  return useSyncExternalStore(
    rt.subscribe,
    () => rt.getStats(id),
    () => null,
  );
}

export function useMetrics(): Metrics {
  const rt = useSimRuntime();
  return useSyncExternalStore(rt.subscribe, rt.getMetrics, rt.getMetrics);
}
