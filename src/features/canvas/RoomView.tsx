"use client";

import { ReactFlowProvider } from "@xyflow/react";
import { useState } from "react";
import { useIsMobile } from "@/lib/use-media";
import { Canvas } from "./Canvas";
import { MobileAdd } from "./MobileSheets";
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
  const clear = () => setSelection({ nodes: [], edges: [] });

  return (
    <ReactFlowProvider>
      <SimProvider>
        <Supervisor />
        <div className="flex h-dvh flex-col overflow-hidden">
          <RoomHeader room={room} compact={mobile} />
          <div className="relative flex min-h-0 flex-1">
            {!mobile && <Palette />}
            <main className="relative min-w-0 flex-1" aria-label="Lienzo">
              <Canvas selection={selection} onSelectionChange={setSelection} readOnly={false} canLoadExample />
              <SimBar readOnly={false} compact={mobile} />
              <Notices />
              {mobile && (
                <>
                  <MobileAdd onAdded={(id) => setSelection({ nodes: [id], edges: [] })} />
                  <PropertiesPanel selection={selection} onClear={clear} variant="sheet" />
                </>
              )}
            </main>
            {!mobile && <PropertiesPanel selection={selection} onClear={clear} />}
          </div>
        </div>
      </SimProvider>
    </ReactFlowProvider>
  );
}
