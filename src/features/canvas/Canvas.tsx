"use client";

import "@xyflow/react/dist/base.css";

import {
  Background,
  BackgroundVariant,
  Controls,
  ReactFlow,
  useReactFlow,
  type Connection,
  type EdgeChange,
  type NodeChange,
  type OnDelete,
} from "@xyflow/react";
import { useEffect, useMemo, useState } from "react";
import { useActions, useDiagramState, useSelections, useUpdatePresence } from "@/features/collab/context";
import { isComponentKind } from "@/sim/components";
import { Cursors } from "./Cursors";
import { EmptyState } from "./EmptyState";
import { MetroEdge, type MetroEdgeType } from "./MetroEdge";
import { DND_TYPE } from "./Palette";
import { TrafficLayer } from "./TrafficLayer";
import type { Selection } from "./RoomView";
import { NODE_H, NODE_W, StationNode, type Selector, type StationNodeType } from "./StationNode";

const nodeTypes = { station: StationNode };
const edgeTypes = { metro: MetroEdge };
const DELETE_KEYS = ["Delete", "Backspace"];

type Size = { width: number; height: number };

export function Canvas({
  selection,
  onSelectionChange,
  readOnly,
  canLoadExample,
  children,
}: {
  selection: Selection;
  onSelectionChange: (s: Selection) => void;
  readOnly: boolean;
  canLoadExample: boolean;
  children?: React.ReactNode;
}) {
  const { nodes, edges } = useDiagramState();
  const othersSelection = useSelections();
  const updateMyPresence = useUpdatePresence();
  const diagram = useActions();
  const notify = diagram.notify;
  const flow = useReactFlow();
  const [measured, setMeasured] = useState<Record<string, Size>>({});

  // Solo cuenta lo que sigue existiendo (otro puede haber borrado lo que yo tenía seleccionado).
  const selNodes = useMemo(() => selection.nodes.filter((id) => id in nodes), [selection.nodes, nodes]);
  const selEdges = useMemo(() => selection.edges.filter((id) => id in edges), [selection.edges, edges]);

  useEffect(() => {
    updateMyPresence({ selected: selNodes });
  }, [selNodes, updateMyPresence]);

  const selectorsByNode = useMemo(() => {
    const map = new Map<string, Selector[]>();
    for (const o of othersSelection) {
      for (const id of o.selected) map.set(id, [...(map.get(id) ?? []), { name: o.name, color: o.color }]);
    }
    return map;
  }, [othersSelection]);

  const rfNodes = useMemo<StationNodeType[]>(() => {
    const sel = new Set(selNodes);
    return Object.values(nodes).map((n) => ({
      id: n.id,
      type: "station",
      position: { x: n.x, y: n.y },
      data: {
        label: n.label,
        kind: n.kind,
        down: n.down,
        downUntil: n.downUntil ?? null,
        downReason: n.downReason ?? null,
        slow: n.slow ?? false,
        params: n.params,
        selectedBy: selectorsByNode.get(n.id) ?? [],
      },
      selected: sel.has(n.id),
      measured: measured[n.id],
      width: NODE_W,
      height: NODE_H,
    }));
  }, [nodes, selNodes, selectorsByNode, measured]);

  const rfEdges = useMemo<MetroEdgeType[]>(() => {
    const sel = new Set(selEdges);
    return Object.values(edges).map((e) => ({
      id: e.id,
      type: "metro",
      source: e.source,
      target: e.target,
      selected: sel.has(e.id),
      data: { down: e.down ?? false, latencyMs: e.latencyMs ?? 0 },
    }));
  }, [edges, selEdges]);

  function onNodesChange(changes: NodeChange<StationNodeType>[]) {
    let nextSel: Set<string> | null = null;
    let sizes: Record<string, Size> | null = null;
    for (const c of changes) {
      if (c.type === "position" && c.position && !readOnly) {
        diagram.moveNode(c.id, c.position.x, c.position.y);
      } else if (c.type === "select") {
        nextSel ??= new Set(selNodes);
        if (c.selected) nextSel.add(c.id);
        else nextSel.delete(c.id);
      } else if (c.type === "dimensions" && c.dimensions) {
        const prev = measured[c.id];
        if (!prev || prev.width !== c.dimensions.width || prev.height !== c.dimensions.height) {
          sizes ??= { ...measured };
          sizes[c.id] = c.dimensions;
        }
      }
    }
    if (sizes) setMeasured(sizes);
    if (nextSel) onSelectionChange({ nodes: [...nextSel], edges: selEdges });
  }

  function onEdgesChange(changes: EdgeChange<MetroEdgeType>[]) {
    let nextSel: Set<string> | null = null;
    for (const c of changes) {
      if (c.type === "select") {
        nextSel ??= new Set(selEdges);
        if (c.selected) nextSel.add(c.id);
        else nextSel.delete(c.id);
      }
    }
    if (nextSel) onSelectionChange({ nodes: selNodes, edges: [...nextSel] });
  }

  const onDelete: OnDelete<StationNodeType, MetroEdgeType> = ({ nodes: gone, edges: goneEdges }) => {
    if (readOnly || (gone.length === 0 && goneEdges.length === 0)) return;
    diagram.removeElements(
      gone.map((n) => n.id),
      goneEdges.map((e) => e.id),
    );
    if (gone.length === 1) notify(`borró ${gone[0].data.label}`);
    else if (gone.length > 1) notify(`borró ${gone.length} componentes`);
    onSelectionChange({ nodes: [], edges: [] });
  };

  function onConnect(c: Connection) {
    if (!c.source || !c.target) return;
    if (diagram.connect(c.source, c.target)) {
      const a = nodes[c.source]?.label;
      const b = nodes[c.target]?.label;
      if (a && b) notify(`conectó ${a} → ${b}`);
    }
  }

  function onDrop(e: React.DragEvent) {
    const kind = e.dataTransfer.getData(DND_TYPE);
    if (!isComponentKind(kind) || readOnly) return;
    e.preventDefault();
    const p = flow.screenToFlowPosition({ x: e.clientX, y: e.clientY });
    const { id, label } = diagram.addNode(kind, p.x - NODE_W / 2, p.y - NODE_H / 2);
    onSelectionChange({ nodes: [id], edges: [] });
    notify(`añadió ${label}`);
  }

  return (
    <div
      className="absolute inset-0"
      onPointerMove={(e) => updateMyPresence({ cursor: flow.screenToFlowPosition({ x: e.clientX, y: e.clientY }) })}
      onPointerLeave={() => updateMyPresence({ cursor: null })}
      onDragOver={(e) => {
        if (e.dataTransfer.types.includes(DND_TYPE)) {
          e.preventDefault();
          e.dataTransfer.dropEffect = "move";
        }
      }}
      onDrop={onDrop}
    >
      <ReactFlow<StationNodeType, MetroEdgeType>
        nodes={rfNodes}
        edges={rfEdges}
        nodeTypes={nodeTypes}
        edgeTypes={edgeTypes}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        onConnect={onConnect}
        onDelete={onDelete}
        deleteKeyCode={readOnly ? null : DELETE_KEYS}
        panActivationKeyCode={null}
        nodesDraggable={!readOnly}
        nodesConnectable={!readOnly}
        elementsSelectable={!readOnly}
        connectionRadius={36}
        fitView
        fitViewOptions={{ padding: 0.35, maxZoom: 1.1 }}
        minZoom={0.25}
        maxZoom={2}
        attributionPosition="bottom-left"
        aria-label="Diagrama del sistema"
      >
        <Background variant={BackgroundVariant.Dots} gap={24} size={1.6} color="var(--punto)" />
        <Controls showInteractive={false} position="bottom-right" />
        {children}
      </ReactFlow>
      <TrafficLayer />
      <Cursors />
      {Object.keys(nodes).length === 0 && <EmptyState canLoad={canLoadExample} canEdit={!readOnly} />}
    </div>
  );
}
