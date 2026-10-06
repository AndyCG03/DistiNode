"use client";

import { LiveMap, LiveObject } from "@liveblocks/client";
import { ClientSideSuspense, LiveblocksProvider, RoomProvider } from "@liveblocks/react/suspense";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { roomIdFor } from "@/lib/liveblocks.config";
import { RoomView, type RoomInfo } from "./RoomView";

export function Room({ room, authEndpoint = "/api/liveblocks-auth" }: { room: RoomInfo; authEndpoint?: string }) {
  return (
    <LiveblocksProvider
      authEndpoint={authEndpoint}
      baseUrl={process.env.NEXT_PUBLIC_LIVEBLOCKS_BASE_URL || undefined}
      throttle={16}
      preventUnsavedChanges
    >
      <RoomProvider
        id={roomIdFor(room.id)}
        initialPresence={{ cursor: null, selected: [] }}
        initialStorage={() => ({
          nodes: new LiveMap(),
          edges: new LiveMap(),
          sim: new LiveObject({ running: false, traffic: 20 }),
        })}
      >
        <ErrorBoundary
          fallback={
            <Centered>
              <p className="font-semibold">No pudimos conectar con la sala.</p>
              <p className="mt-1 text-gris-texto">Comprueba tu conexión y recarga la página.</p>
            </Centered>
          }
        >
          <ClientSideSuspense
            fallback={
              <Centered>
                <span className="inline-block size-3 animate-pulse rounded-full bg-verde" aria-hidden="true" />
                <p className="mt-3 text-gris-texto">Conectando con la sala…</p>
              </Centered>
            }
          >
            <RoomView room={room} />
          </ClientSideSuspense>
        </ErrorBoundary>
      </RoomProvider>
    </LiveblocksProvider>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid flex-1 place-items-center p-6 text-center" role="status">
      <div className="flex flex-col items-center">{children}</div>
    </div>
  );
}
