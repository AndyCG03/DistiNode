"use client";

import { createContext, useContext, useEffect, useRef } from "react";
import type {
  CollabMode,
  DiagramActions,
  DiagramState,
  Notice,
  Person,
  PersonCursor,
  PersonSelection,
  PresenceUpdate,
} from "./types";

type NoticeBus = { subscribe(fn: (n: Notice) => void): () => void };

export type CollabValue = {
  mode: CollabMode;
  /** Quien ejecuta el supervisor (caos, reinicios). En una sala, la conexión con el id más bajo. */
  isLeader: boolean;
  diagram: DiagramState;
  actions: DiagramActions;
  me: Person;
  people: readonly Person[];
  cursors: readonly PersonCursor[];
  selections: readonly PersonSelection[];
  updatePresence: (p: PresenceUpdate) => void;
  notices: NoticeBus;
};

// Contextos separados: mover el ratón de otra persona solo re-renderiza los cursores.
const ModeCtx = createContext<CollabMode>("local");
const LeaderCtx = createContext(false);
const DiagramCtx = createContext<DiagramState | null>(null);
const ActionsCtx = createContext<DiagramActions | null>(null);
const MeCtx = createContext<Person | null>(null);
const PeopleCtx = createContext<readonly Person[]>([]);
const CursorsCtx = createContext<readonly PersonCursor[]>([]);
const SelectionsCtx = createContext<readonly PersonSelection[]>([]);
const PresenceCtx = createContext<(p: PresenceUpdate) => void>(() => {});
const NoticesCtx = createContext<NoticeBus>({ subscribe: () => () => {} });

export function CollabProvider({ value, children }: { value: CollabValue; children: React.ReactNode }) {
  return (
    <ModeCtx.Provider value={value.mode}>
      <LeaderCtx.Provider value={value.isLeader}>
        <DiagramCtx.Provider value={value.diagram}>
          <ActionsCtx.Provider value={value.actions}>
            <MeCtx.Provider value={value.me}>
              <PeopleCtx.Provider value={value.people}>
                <CursorsCtx.Provider value={value.cursors}>
                  <SelectionsCtx.Provider value={value.selections}>
                    <PresenceCtx.Provider value={value.updatePresence}>
                      <NoticesCtx.Provider value={value.notices}>{children}</NoticesCtx.Provider>
                    </PresenceCtx.Provider>
                  </SelectionsCtx.Provider>
                </CursorsCtx.Provider>
              </PeopleCtx.Provider>
            </MeCtx.Provider>
          </ActionsCtx.Provider>
        </DiagramCtx.Provider>
      </LeaderCtx.Provider>
    </ModeCtx.Provider>
  );
}

function required<T>(v: T | null, name: string): T {
  if (v === null) throw new Error(`${name} fuera de <CollabProvider>`);
  return v;
}

export const useCollabMode = () => useContext(ModeCtx);
export const useIsLeader = () => useContext(LeaderCtx);
export const useDiagramState = () => required(useContext(DiagramCtx), "useDiagramState");
export const useActions = () => required(useContext(ActionsCtx), "useActions");
export const useMe = () => required(useContext(MeCtx), "useMe");
export const usePeople = () => useContext(PeopleCtx);
export const useCursors = () => useContext(CursorsCtx);
export const useSelections = () => useContext(SelectionsCtx);
export const useUpdatePresence = () => useContext(PresenceCtx);

export function useNoticeListener(fn: (n: Notice) => void) {
  const bus = useContext(NoticesCtx);
  const ref = useRef(fn);
  useEffect(() => {
    ref.current = fn;
  });
  useEffect(() => bus.subscribe((n) => ref.current(n)), [bus]);
}

export function createNoticeBus() {
  const subs = new Set<(n: Notice) => void>();
  return {
    subscribe(fn: (n: Notice) => void) {
      subs.add(fn);
      return () => {
        subs.delete(fn);
      };
    },
    emit(n: Notice) {
      for (const fn of subs) fn(n);
    },
  };
}
