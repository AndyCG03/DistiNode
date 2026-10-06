"use client";

import { LocalBridge } from "@/features/collab/LocalBridge";
import { RoomView } from "./RoomView";

/** Demo sin cuentas: mismo lienzo y simulación, el diagrama se guarda en este navegador. */
export default function DemoRoom() {
  return (
    <LocalBridge storageKey="distinode-demo">
      <RoomView room={null} />
    </LocalBridge>
  );
}
