"use client";

import { LiveObject } from "@liveblocks/client";
import {
  shallow,
  useBroadcastEvent,
  useEventListener,
  useMutation,
  useOthersMapped,
  useSelf,
  useStorage,
  useUpdateMyPresence,
} from "@liveblocks/react/suspense";
import { useMemo, useState } from "react";
import { COMPONENTS, nextLabel, type ComponentKind, type ParamKey } from "@/sim/components";
import { CollabProvider, createNoticeBus } from "./context";
import { clampTraffic, EXAMPLE, newId } from "./ops";
import type { DiagramActions, DiagramState } from "./types";

/** Conecta la sala de Liveblocks con la interfaz. Debe ir dentro de RoomProvider + ClientSideSuspense. */
export function LiveblocksBridge({ children }: { children: React.ReactNode }) {
  const nodes = useStorage((root) => root.nodes);
  const edges = useStorage((root) => root.edges);
  const sim = useStorage((root) => root.sim);
  const diagram = useMemo<DiagramState>(() => ({ nodes, edges, sim }), [nodes, edges, sim]);

  const meInfo = useSelf((s) => s.info);
  const meId = useSelf((s) => s.id ?? String(s.connectionId));
  const me = useMemo(() => ({ key: meId, ...meInfo }), [meId, meInfo]);

  const peopleRaw = useOthersMapped((o) => o.info, shallow);
  const cursorsRaw = useOthersMapped((o) => ({ ...o.info, cursor: o.presence.cursor }), shallow);
  const selectionsRaw = useOthersMapped((o) => ({ ...o.info, selected: o.presence.selected }), shallow);
  const people = useMemo(() => peopleRaw.map(([k, info]) => ({ key: String(k), ...info })), [peopleRaw]);
  const cursors = useMemo(() => cursorsRaw.map(([k, c]) => ({ key: String(k), ...c })), [cursorsRaw]);
  const selections = useMemo(() => selectionsRaw.map(([k, s]) => ({ key: String(k), ...s })), [selectionsRaw]);

  const updatePresence = useUpdateMyPresence();
  const [notices] = useState(createNoticeBus);
  useEventListener(({ event, user }) => {
    if (event.type === "notice") notices.emit({ text: event.text, color: user?.info.color ?? "var(--gris)" });
  });

  const actions = useLiveActions(meInfo.name);

  return (
    <CollabProvider
      value={{ mode: "live", diagram, actions, me, people, cursors, selections, updatePresence, notices }}
    >
      {children}
    </CollabProvider>
  );
}

/** Escrituras atómicas en el almacenamiento de Liveblocks. */
function useLiveActions(myName: string): DiagramActions {
  const broadcast = useBroadcastEvent();

  const addNode = useMutation(({ storage }, kind: ComponentKind, x: number, y: number) => {
    const nodes = storage.get("nodes");
    const id = newId();
    const label = nextLabel(
      kind,
      [...nodes.values()].map((n) => n.get("label")),
    );
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
    storage.get("sim").set("traffic", clampTraffic(traffic));
  }, []);

  const loadExample = useMutation(({ storage }) => {
    const nodes = storage.get("nodes");
    const edges = storage.get("edges");
    if (nodes.size > 0) return false;
    let prev: string | null = null;
    for (const { kind, label, x, y } of EXAMPLE) {
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

  return useMemo(
    () => ({
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
      notify: (action: string) => broadcast({ type: "notice", text: `${myName} ${action}` }),
    }),
    [
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
      broadcast,
      myName,
    ],
  );
}
