"use client";

import { LiveObject } from "@liveblocks/client";
import { useBroadcastEvent, useMutation, useSelf } from "@liveblocks/react/suspense";
import { useCallback } from "react";
import { COMPONENTS, nextLabel, type ComponentKind, type ParamKey } from "@/sim/components";

const newId = () => crypto.randomUUID().slice(0, 12);

/** Avisos breves para los demás: "Ana tumbó Servidor 2". */
export function useNotify() {
  const broadcast = useBroadcastEvent();
  const name = useSelf((me) => me.info.name);
  return useCallback((action: string) => broadcast({ type: "notice", text: `${name} ${action}` }), [broadcast, name]);
}

/** Todas las escrituras al diagrama compartido. Cada una es atómica en Liveblocks. */
export function useDiagram() {
  const addNode = useMutation(({ storage }, kind: ComponentKind, x: number, y: number) => {
    const nodes = storage.get("nodes");
    const labels = [...nodes.values()].map((n) => n.get("label"));
    const id = newId();
    const label = nextLabel(kind, labels);
    nodes.set(
      id,
      new LiveObject({
        id,
        kind,
        label,
        x: Math.round(x),
        y: Math.round(y),
        params: new LiveObject({ ...COMPONENTS[kind].defaults }),
        down: false,
      }),
    );
    return { id, label };
  }, []);

  const moveNode = useMutation(({ storage }, id: string, x: number, y: number) => {
    storage
      .get("nodes")
      .get(id)
      ?.update({ x: Math.round(x), y: Math.round(y) });
  }, []);

  const removeElements = useMutation(({ storage }, nodeIds: string[], edgeIds: string[]) => {
    const nodes = storage.get("nodes");
    const edges = storage.get("edges");
    const gone = new Set(nodeIds);
    for (const id of edgeIds) edges.delete(id);
    for (const [id, e] of [...edges.entries()]) {
      if (gone.has(e.get("source")) || gone.has(e.get("target"))) edges.delete(id);
    }
    for (const id of nodeIds) nodes.delete(id);
  }, []);

  const connect = useMutation(({ storage }, source: string, target: string) => {
    if (source === target) return false;
    const edges = storage.get("edges");
    for (const e of edges.values()) {
      if (e.get("source") === source && e.get("target") === target) return false;
    }
    const id = newId();
    edges.set(id, new LiveObject({ id, source, target }));
    return true;
  }, []);

  const setParam = useMutation(({ storage }, id: string, key: ParamKey, value: number) => {
    storage.get("nodes").get(id)?.get("params").set(key, value);
  }, []);

  const setLabel = useMutation(({ storage }, id: string, label: string) => {
    storage.get("nodes").get(id)?.set("label", label.slice(0, 40));
  }, []);

  const setDown = useMutation(({ storage }, id: string, down: boolean) => {
    storage.get("nodes").get(id)?.set("down", down);
  }, []);

  const setRunning = useMutation(({ storage }, running: boolean) => {
    storage.get("sim").set("running", running);
  }, []);

  const setTraffic = useMutation(({ storage }, traffic: number) => {
    storage.get("sim").set("traffic", Math.min(200, Math.max(1, Math.round(traffic))));
  }, []);

  /** Cliente → Balanceador → Servidor → Base de datos, en una sola operación. */
  const loadExample = useMutation(({ storage }) => {
    const nodes = storage.get("nodes");
    const edges = storage.get("edges");
    if (nodes.size > 0) return false;
    const chain: [ComponentKind, string, number, number][] = [
      ["client", "Cliente", 0, 0],
      ["balancer", "Balanceador", 260, 0],
      ["server", "Servidor 1", 520, 0],
      ["database", "Base de datos 1", 800, 0],
    ];
    let prev: string | null = null;
    for (const [kind, label, x, y] of chain) {
      const id = newId();
      nodes.set(
        id,
        new LiveObject({
          id,
          kind,
          label,
          x,
          y,
          params: new LiveObject({ ...COMPONENTS[kind].defaults }),
          down: false,
        }),
      );
      if (prev) {
        const eid = newId();
        edges.set(eid, new LiveObject({ id: eid, source: prev, target: id }));
      }
      prev = id;
    }
    return true;
  }, []);

  return {
    addNode,
    moveNode,
    removeElements,
    connect,
    setParam,
    setLabel,
    setDown,
    setRunning,
    setTraffic,
    loadExample,
  };
}
