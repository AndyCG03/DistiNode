"use client";

import { ReactFlowProvider } from "@xyflow/react";
import { useState } from "react";
import { useCollabMode } from "@/features/collab/context";
import { useIsMobile } from "@/lib/use-media";
import { Canvas } from "./Canvas";
import { Notices } from "./Notices";
import { Palette } from "./Palette";
import { PropertiesPanel } from "./PropertiesPanel";
import { RoomHeader } from "./RoomHeader";
import { SimBar } from "./SimBar";
import { SimProvider } from "./SimContext";
import { Supervisor } from "./Supervisor";

export type RoomInfo = { id: string; code: string; name: string };
export type Selection = { nodes: string[]; edges: string[] };

/** Vista de una sala. Necesita un CollabProvider (LiveblocksBridge o LocalBridge) por encima. */
export function RoomView({ room }: { room: RoomInfo | null }) {
  const [selection, setSelection] = useState<Selection>({ nodes: [], edges: [] });
  const mobile = useIsMobile();
  // En una sala compartida el móvil solo mira; en la demo puede cargar el ejemplo y darle al ▶.
  const mode = useCollabMode();
  const lockSim = mobile && mode === "live";

  return (
    <ReactFlowProvider>
      <SimProvider>
        <Supervisor />
        <div className="flex h-dvh flex-col overflow-hidden">
          <RoomHeader room={room} readOnly={mobile} />
          <div className="relative flex min-h-0 flex-1">
            {!mobile && <Palette />}
            <main className="relative min-w-0 flex-1" aria-label="Lienzo">
              <Canvas
                selection={selection}
                onSelectionChange={setSelection}
                readOnly={mobile}
                canLoadExample={!lockSim}
              />
              <SimBar readOnly={lockSim} />
              <Notices />
            </main>
            {!mobile && (
              <PropertiesPanel selection={selection} onClear={() => setSelection({ nodes: [], edges: [] })} />
            )}
          </div>
        </div>
      </SimProvider>
    </ReactFlowProvider>
  );
}
