"use client";

import { LiveObject } from "@liveblocks/client";
import {
  shallow,
  useBroadcastEvent,
  useEventListener,
  useMutation,
  useOthersConnectionIds,
  useOthersMapped,
  useSelf,
  useStorage,
  useUpdateMyPresence,
} from "@liveblocks/react/suspense";
import { useCallback, useMemo, useState } from "react";
import { COMPONENTS, nextLabel, type ComponentKind, type ParamKey } from "@/sim/components";
import type { Template } from "@/sim/templates";
import { CollabProvider, createNoticeBus } from "./context";
import { buildTemplate, clampTraffic, newId } from "./ops";
import type { DiagramActions, DiagramState, EdgePatch, NodeStatePatch, SimPatch } from "./types";

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

  // Los avisos del sistema también se muestran a quien los genera (broadcast no se lo envía a uno mismo).
  const onAnnounce = useCallback((text: string) => notices.emit({ text, color: "var(--rojo)" }), [notices]);
  const actions = useLiveActions(meInfo.name, onAnnounce);

  // Líder: la conexión con el id más bajo ejecuta el supervisor (caos y reinicios) para toda la sala.
  const myConnection = useSelf((s) => s.connectionId);
  const othersIds = useOthersConnectionIds();
  const isLeader = othersIds.every((id) => myConnection < id);

  return (
    <CollabProvider
      value={{ mode: "live", isLeader, diagram, actions, me, people, cursors, selections, updatePresence, notices }}
    >
      {children}
    </CollabProvider>
  );
}

/** Escrituras atómicas en el almacenamiento de Liveblocks. */
function useLiveActions(myName: string, onAnnounce: (text: string) => void): DiagramActions {
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

  const setNodeState = useMutation(({ storage }, id: string, patch: NodeStatePatch) => {
    storage.get("nodes").get(id)?.update(patch);
  }, []);

  const setEdge = useMutation(({ storage }, id: string, patch: EdgePatch) => {
    storage.get("edges").get(id)?.update(patch);
  }, []);

  const setRunning = useMutation(({ storage }, running: boolean) => {
    storage.get("sim").set("running", running);
  }, []);

  const setTraffic = useMutation(({ storage }, traffic: number) => {
    storage.get("sim").set("traffic", clampTraffic(traffic));
  }, []);

  const setSimOptions = useMutation(({ storage }, patch: SimPatch) => {
    storage.get("sim").update(patch);
  }, []);

  /** Sustituye todo el diagrama en una sola operación (los demás lo ven de golpe). */
  const loadTemplate = useMutation(({ storage }, t: Template) => {
    const nodes = storage.get("nodes");
    const edges = storage.get("edges");
    for (const id of [...edges.keys()]) edges.delete(id);
    for (const id of [...nodes.keys()]) nodes.delete(id);
    const built = buildTemplate(t);
    for (const n of built.nodes) nodes.set(n.id, new LiveObject({ ...n, params: new LiveObject(n.params) }));
    for (const e of built.edges) edges.set(e.id, new LiveObject(e));
    storage.get("sim").set("traffic", t.traffic);
  }, []);

  return useMemo(
    () => ({
      addNode,
      moveNode,
      removeElements,
      connect,
      setParam,
      setLabel,
      setNodeState,
      setEdge,
      setRunning,
      setTraffic,
      setSimOptions,
      loadTemplate,
      notify: (action: string) => broadcast({ type: "notice", text: `${myName} ${action}` }),
      announce: (text: string) => {
        broadcast({ type: "notice", text });
        onAnnounce(text);
      },
    }),
    [
      addNode,
      moveNode,
      removeElements,
      connect,
      setParam,
      setLabel,
      setNodeState,
      setEdge,
      setRunning,
      setTraffic,
      setSimOptions,
      loadTemplate,
      broadcast,
      myName,
      onAnnounce,
    ],
  );
}
