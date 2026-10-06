"use client";

import { ReactFlowProvider } from "@xyflow/react";
import { useState } from "react";
import { useIsMobile } from "@/lib/use-media";
import { Canvas } from "./Canvas";
import { Notices } from "./Notices";
import { Palette } from "./Palette";
import { PropertiesPanel } from "./PropertiesPanel";
import { RoomHeader } from "./RoomHeader";

export type RoomInfo = { id: string; code: string; name: string };
export type Selection = { nodes: string[]; edges: string[] };

export function RoomView({ room }: { room: RoomInfo }) {
  const [selection, setSelection] = useState<Selection>({ nodes: [], edges: [] });
  const mobile = useIsMobile();

  return (
    <ReactFlowProvider>
      <div className="flex h-dvh flex-col overflow-hidden">
        <RoomHeader room={room} readOnly={mobile} />
        <div className="relative flex min-h-0 flex-1">
          {!mobile && <Palette />}
          <main className="relative min-w-0 flex-1" aria-label="Lienzo">
            <Canvas selection={selection} onSelectionChange={setSelection} readOnly={mobile} />
            <Notices />
          </main>
          {!mobile && <PropertiesPanel selection={selection} onClear={() => setSelection({ nodes: [], edges: [] })} />}
        </div>
      </div>
    </ReactFlowProvider>
  );
}
