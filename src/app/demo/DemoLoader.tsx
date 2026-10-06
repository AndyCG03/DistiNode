"use client";

import dynamic from "next/dynamic";

// Solo en el navegador: lee localStorage y mide el lienzo.
const DemoRoom = dynamic(() => import("@/features/canvas/DemoRoom"), {
  ssr: false,
  loading: () => (
    <div className="grid flex-1 place-items-center" role="status">
      <span className="inline-block size-3 animate-pulse rounded-full bg-verde" aria-hidden="true" />
    </div>
  ),
});

export function DemoLoader() {
  return <DemoRoom />;
}
