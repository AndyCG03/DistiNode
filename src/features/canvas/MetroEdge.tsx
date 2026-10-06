"use client";

import { BaseEdge, useInternalNode, type Edge, type EdgeProps } from "@xyflow/react";
import { memo } from "react";
import { endpoints, metroPoints, roundedPath } from "./geometry";

export type MetroEdgeType = Edge<Record<string, never>, "metro">;

function MetroEdgeImpl({ id, source, target, selected }: EdgeProps<MetroEdgeType>) {
  const s = useInternalNode(source);
  const t = useInternalNode(target);
  if (!s || !t) return null;

  const { s: a, t: b } = endpoints(
    { ...s.internals.positionAbsolute, width: s.measured.width ?? 0, height: s.measured.height ?? 0 },
    { ...t.internals.positionAbsolute, width: t.measured.width ?? 0, height: t.measured.height ?? 0 },
  );
  const path = roundedPath(metroPoints(a, b));
  const arrow = `M${b.x - 13},${b.y - 7} L${b.x - 2},${b.y} L${b.x - 13},${b.y + 7} Z`;

  return (
    <g className="metro-edge" data-selected={selected || undefined}>
      {selected && <path d={path} className="metro-edge-halo" fill="none" />}
      <BaseEdge id={id} path={path} className="metro-edge-line" interactionWidth={18} />
      <path d={arrow} className="metro-edge-arrow" />
    </g>
  );
}

export const MetroEdge = memo(MetroEdgeImpl);
