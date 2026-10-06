"use client";

import { LiveMap, LiveObject } from "@liveblocks/client";
import { ClientSideSuspense, LiveblocksProvider, RoomProvider } from "@liveblocks/react/suspense";
import { useErrorListener } from "@liveblocks/react/suspense";
import Link from "next/link";
import { useState } from "react";
import { ErrorBoundary } from "@/components/ErrorBoundary";
import { roomIdFor } from "@/lib/liveblocks.config";
import { LiveblocksBridge } from "@/features/collab/LiveblocksBridge";
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
          <AccessGuard>
            <ClientSideSuspense
              fallback={
                <Centered>
                  <span className="inline-block size-3 animate-pulse rounded-full bg-verde" aria-hidden="true" />
                  <p className="mt-3 text-gris-texto">Conectando con la sala…</p>
                </Centered>
              }
            >
              <LiveblocksBridge>
                <RoomView room={room} />
              </LiveblocksBridge>
            </ClientSideSuspense>
          </AccessGuard>
        </ErrorBoundary>
      </RoomProvider>
    </LiveblocksProvider>
  );
}

/** Si Liveblocks rechaza el acceso (no eres miembro, sesión caducada), lo decimos en vez de esperar. */
function AccessGuard({ children }: { children: React.ReactNode }) {
  const [problem, setProblem] = useState<"denied" | "full" | null>(null);
  useErrorListener((error) => {
    if (error.context.type !== "ROOM_CONNECTION_ERROR") return;
    setProblem(error.context.code === 4005 ? "full" : "denied");
  });
  if (!problem) return children;
  return (
    <Centered>
      <p className="font-semibold">{problem === "full" ? "La sala está llena." : "No tienes acceso a esta sala."}</p>
      <p className="mt-1 text-gris-texto">
        {problem === "full" ? "Prueba de nuevo en un rato." : "Puede que tu sesión haya caducado. Vuelve a entrar."}
      </p>
      <Link href="/salas" className="btn btn-primario mt-5">
        Ir a mis salas
      </Link>
    </Centered>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid flex-1 place-items-center p-6 text-center" role="status">
      <div className="flex flex-col items-center">{children}</div>
    </div>
  );
}
