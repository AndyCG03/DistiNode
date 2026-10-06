"use client";

import { useEffect, useRef } from "react";
import { useActions, useDiagramState, useIsLeader } from "@/features/collab/context";
import { SIM_DEFAULTS } from "@/lib/liveblocks.config";
import { useSimRuntime } from "./SimContext";

/** Segundos seguidos saturado antes de caerse (si "Caídas por sobrecarga" está activo). */
export const OVERLOAD_SECONDS = 5;
const SLOW_SECONDS = 10;
const CUT_SECONDS = 6;
/** Probabilidad de un evento de caos en cada segundo. */
const CHAOS_PER_SECOND = 0.15;
const MAX_CHAOS_DOWN = 2;

/**
 * Supervisor de fallos. Solo lo ejecuta un navegador por sala (el líder), que escribe los cambios en el
 * estado compartido: así todos ven las mismas caídas aunque cada uno simule localmente.
 * - Reinicia lo que se cayó solo cuando vence su tiempo.
 * - Con "Caídas por sobrecarga": tumba los nodos saturados demasiado tiempo.
 * - Con "Caos": tumba, degrada o corta conexiones al azar.
 */
export function Supervisor() {
  const isLeader = useIsLeader();
  const diagram = useDiagramState();
  const actions = useActions();
  const runtime = useSimRuntime();
  const latest = useRef({ diagram, actions });
  useEffect(() => {
    latest.current = { diagram, actions };
  });

  useEffect(() => {
    if (!isLeader) return;
    let lastChaos = Date.now();
    const timer = setInterval(() => {
      const { diagram: d, actions: a } = latest.current;
      const now = Date.now();
      const opts = { ...SIM_DEFAULTS, ...d.sim };
      const nodes = Object.values(d.nodes);
      const edges = Object.values(d.edges);

      // 1. Reinicios y recuperaciones programadas.
      for (const n of nodes) {
        if (n.down && n.downUntil && now >= n.downUntil) {
          a.setNodeState(n.id, { down: false, downUntil: null, downReason: null });
          a.announce(`${n.label} volvió a arrancar`);
        }
        if (n.slow && n.slowUntil && now >= n.slowUntil) a.setNodeState(n.id, { slow: false, slowUntil: null });
      }
      for (const e of edges) {
        if (e.down && e.downUntil && now >= e.downUntil) a.setEdge(e.id, { down: false, downUntil: null });
      }
      if (!d.sim.running) return;

      // 2. Caídas por sobrecarga sostenida.
      if (opts.autoCrash) {
        for (const n of nodes) {
          if (n.down) continue;
          const s = runtime.engine.nodeStats(n.id);
          if (s && s.overloadFor >= OVERLOAD_SECONDS) {
            a.setNodeState(n.id, { down: true, downReason: "sobrecarga", downUntil: now + opts.restartSec * 1000 });
            a.announce(`💥 ${n.label} se cayó por sobrecarga`);
          }
        }
      }

      // 3. Caos.
      if (!opts.chaos || now - lastChaos < 1000) return;
      lastChaos = now;
      if (Math.random() > CHAOS_PER_SECOND) return;
      const pickOne = <T,>(xs: T[]) => xs[Math.floor(Math.random() * xs.length)];
      const alive = nodes.filter((n) => !n.down && n.kind !== "client");
      const chaosDown = nodes.filter((n) => n.down && n.downReason === "caos").length;
      const roll = Math.random();
      if (roll < 0.55 && alive.length && chaosDown < MAX_CHAOS_DOWN) {
        const n = pickOne(alive);
        a.setNodeState(n.id, { down: true, downReason: "caos", downUntil: now + opts.restartSec * 1000 });
        a.announce(`⚡ Caos: ${n.label} se cayó`);
      } else if (roll < 0.8 && alive.length) {
        const n = pickOne(alive.filter((x) => !x.slow).length ? alive.filter((x) => !x.slow) : alive);
        a.setNodeState(n.id, { slow: true, slowUntil: now + SLOW_SECONDS * 1000 });
        a.announce(`⚡ Caos: ${n.label} va lento`);
      } else {
        const candidates = edges.filter((e) => !e.down);
        if (!candidates.length) return;
        const e = pickOne(candidates);
        a.setEdge(e.id, { down: true, downUntil: now + CUT_SECONDS * 1000 });
        a.announce(`⚡ Caos: se cortó ${d.nodes[e.source]?.label ?? "?"} → ${d.nodes[e.target]?.label ?? "?"}`);
      }
    }, 500);
    return () => clearInterval(timer);
  }, [isLeader, runtime]);

  return null;
}
