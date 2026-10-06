"use client";

import { useEventListener } from "@liveblocks/react/suspense";
import { useState } from "react";

type Notice = { id: number; text: string; color: string };
let seq = 0;

/** Avisos breves de lo que hacen los demás. */
export function Notices() {
  const [items, setItems] = useState<Notice[]>([]);

  useEventListener(({ event, user }) => {
    if (event.type !== "notice") return;
    const id = ++seq;
    setItems((prev) => [...prev.slice(-3), { id, text: event.text, color: user?.info.color ?? "var(--gris)" }]);
    setTimeout(() => setItems((prev) => prev.filter((n) => n.id !== id)), 3500);
  });

  return (
    <div aria-live="polite" className="pointer-events-none absolute bottom-24 left-4 z-20 flex flex-col gap-2">
      {items.map((n) => (
        <p
          key={n.id}
          className="flex max-w-xs items-center gap-2 rounded-full border border-linea bg-papel py-1.5 pr-4 pl-2 text-sm shadow-flota motion-safe:animate-[aviso_200ms_ease-out]"
        >
          <span aria-hidden="true" className="size-2.5 shrink-0 rounded-full" style={{ background: n.color }} />
          {n.text}
        </p>
      ))}
    </div>
  );
}
