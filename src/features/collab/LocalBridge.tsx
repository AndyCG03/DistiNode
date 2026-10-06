"use client";

import { useEffect, useMemo, useState, useSyncExternalStore } from "react";
import { PERSON_COLORS } from "@/lib/colors";
import { CollabProvider, createNoticeBus } from "./context";
import { LocalStore } from "./localStore";
import type { Person } from "./types";

const ME: Person = { key: "yo", name: "Tú", color: PERSON_COLORS[0] };
const NONE: never[] = [];
const noop = () => {};

/** Modo demo: el diagrama vive en este navegador (localStorage), sin cuentas ni servidor. */
export function LocalBridge({ storageKey, children }: { storageKey: string; children: React.ReactNode }) {
  const [store] = useState(() => new LocalStore(storageKey));
  const diagram = useSyncExternalStore(store.subscribe, store.getSnapshot, store.getSnapshot);
  const [notices] = useState(createNoticeBus);
  const actions = useMemo(() => store.actions(), [store]);
  useEffect(() => {
    store.setNoticeHandler(notices.emit);
    return () => store.setNoticeHandler(null);
  }, [store, notices]);

  return (
    <CollabProvider
      value={{
        mode: "local",
        isLeader: true,
        diagram,
        actions,
        me: ME,
        people: NONE,
        cursors: NONE,
        selections: NONE,
        updatePresence: noop,
        notices,
      }}
    >
      {children}
    </CollabProvider>
  );
}
