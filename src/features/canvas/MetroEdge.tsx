"use client";

import { BaseEdge, useInternalNode, type Edge, type EdgeProps } from "@xyflow/react";
import { memo } from "react";
import { endpoints, metroPoints, pointAt, polyline, roundedPath } from "./geometry";

export type MetroEdgeData = { down?: boolean; latencyMs?: number };
export type MetroEdgeType = Edge<MetroEdgeData, "metro">;

function MetroEdgeImpl({ id, source, target, selected, data }: EdgeProps<MetroEdgeType>) {
  const s = useInternalNode(source);
  const t = useInternalNode(target);
  if (!s || !t) return null;

  const { s: a, t: b } = endpoints(
    { ...s.internals.positionAbsolute, width: s.measured.width ?? 0, height: s.measured.height ?? 0 },
    { ...t.internals.positionAbsolute, width: t.measured.width ?? 0, height: t.measured.height ?? 0 },
  );
  const pts = metroPoints(a, b);
  const path = roundedPath(pts);
  const arrow = `M${b.x - 13},${b.y - 7} L${b.x - 2},${b.y} L${b.x - 13},${b.y + 7} Z`;
  const down = data?.down ?? false;
  const latency = data?.latencyMs ?? 0;
  const tag = down ? "cortada" : latency > 0 ? `+${latency} ms` : null;
  const mid = tag ? pointAt(polyline(pts), 0.5) : null;
  const tagW = tag ? tag.length * 6.6 + 14 : 0;

  return (
    <g className="metro-edge" data-selected={selected || undefined} data-down={down || undefined}>
      {selected && <path d={path} className="metro-edge-halo" fill="none" />}
      <BaseEdge id={id} path={path} className="metro-edge-line" interactionWidth={18} />
      <path d={arrow} className="metro-edge-arrow" />
      {tag && mid && (
        <g
          transform={`translate(${mid.x}, ${mid.y - 16})`}
          aria-label={down ? "Conexión cortada" : `Latencia añadida ${latency} ms`}
        >
          <rect
            x={-tagW / 2}
            y={-10}
            width={tagW}
            height={20}
            rx={10}
            fill="var(--papel)"
            stroke={down ? "var(--rojo)" : "var(--ambar)"}
            strokeWidth={1.5}
          />
          <text textAnchor="middle" y={4} className="metro-edge-tag" fill={down ? "var(--rojo)" : "var(--ambar)"}>
            {tag}
          </text>
        </g>
      )}
    </g>
  );
}

export const MetroEdge = memo(MetroEdgeImpl);
