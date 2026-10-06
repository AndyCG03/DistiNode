"use client";

import { useEffect, useState } from "react";

/** Segundos que faltan hasta `until` (ms desde epoch), actualizados cada medio segundo. */
export function useSecondsLeft(until: number | null | undefined): number | null {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!until) return;
    const t = setInterval(() => setNow(Date.now()), 500);
    return () => clearInterval(t);
  }, [until]);
  if (!until) return null;
  return Math.max(0, Math.ceil((until - now) / 1000));
}
