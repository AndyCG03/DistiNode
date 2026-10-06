"use client";

import { shallow, useOthersMapped } from "@liveblocks/react/suspense";
import { useViewport } from "@xyflow/react";

/** Cursores de los demás, en coordenadas del lienzo convertidas a pantalla. */
export function Cursors() {
  const others = useOthersMapped((o) => ({ cursor: o.presence.cursor, name: o.info.name, color: o.info.color }), shallow);
  const { x, y, zoom } = useViewport();

  return (
    <div className="pointer-events-none absolute inset-0 z-10 overflow-hidden" aria-hidden="true">
      {others.map(([id, o]) =>
        o.cursor ? (
          <div
            key={id}
            className="absolute top-0 left-0 transition-transform duration-75 ease-linear"
            style={{ transform: `translate(${o.cursor.x * zoom + x}px, ${o.cursor.y * zoom + y}px)` }}
          >
            <svg width="18" height="20" viewBox="0 0 18 20">
              <path d="M1 1l6.5 17 2.6-7.1L17 8.3Z" fill={o.color} stroke="white" strokeWidth="1.5" strokeLinejoin="round" />
            </svg>
            <span
              className="absolute top-4 left-3 rounded-full px-2 py-0.5 text-xs font-semibold whitespace-nowrap text-white"
              style={{ background: o.color }}
            >
              {o.name}
            </span>
          </div>
        ) : null,
      )}
    </div>
  );
}
