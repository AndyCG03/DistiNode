"use client";

import { getNodesBounds, getViewportForBounds, useReactFlow } from "@xyflow/react";
import { toPng } from "html-to-image";
import { useEffect, useRef, useState } from "react";
import { useActions, useDiagramState } from "@/features/collab/context";
import { fileSlug, parseProject, toProject } from "@/features/collab/project";
import { fitOptions } from "./fit";

function download(href: string, filename: string) {
  const a = document.createElement("a");
  a.href = href;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
}

const css = (name: string) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();

/** Diagrama encuadrado a PNG, con una franja inferior con el nombre. */
async function diagramToPng(flow: ReturnType<typeof useReactFlow>, title: string): Promise<string | null> {
  const nodes = flow.getNodes();
  const viewport = document.querySelector<HTMLElement>(".react-flow__viewport");
  if (!nodes.length || !viewport) return null;
  const bounds = getNodesBounds(nodes);
  const width = Math.round(Math.min(4000, Math.max(900, bounds.width + 160)));
  const height = Math.round(Math.min(3000, Math.max(500, bounds.height + 200)));
  const vp = getViewportForBounds(bounds, width, height, 0.2, 1.5, 0.1);
  const background = css("--fondo");
  // html-to-image pierde el trazo de las líneas (viene de CSS): se fija como atributos SVG mientras se captura.
  const strokes = [...viewport.querySelectorAll<SVGPathElement>(".react-flow__edges path")];
  const ATTRS = ["stroke", "stroke-width", "fill", "stroke-dasharray", "stroke-linecap", "stroke-linejoin", "opacity"];
  const saved = strokes.map((p) => ATTRS.map((a) => p.getAttribute(a)));
  for (const p of strokes) {
    const cs = getComputedStyle(p);
    for (const a of ATTRS) p.setAttribute(a, cs.getPropertyValue(a));
  }
  let shot: string;
  try {
    shot = await toPng(viewport, {
      backgroundColor: background,
      width,
      height,
      pixelRatio: 2,
      style: {
        width: `${width}px`,
        height: `${height}px`,
        transform: `translate(${vp.x}px, ${vp.y}px) scale(${vp.zoom})`,
      },
    });
  } finally {
    strokes.forEach((p, i) =>
      ATTRS.forEach((a, j) => (saved[i][j] === null ? p.removeAttribute(a) : p.setAttribute(a, saved[i][j]!))),
    );
  }

  // Franja inferior: marca, nombre y fecha.
  const img = new Image();
  img.src = shot;
  await img.decode();
  const band = 64 * 2;
  const canvas = document.createElement("canvas");
  canvas.width = img.width;
  canvas.height = img.height + band;
  const ctx = canvas.getContext("2d")!;
  ctx.fillStyle = background;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(img, 0, 0);
  ctx.fillStyle = css("--linea");
  ctx.fillRect(0, img.height, canvas.width, 2);
  const font = getComputedStyle(document.body).fontFamily;
  ctx.textBaseline = "middle";
  const y = img.height + band / 2;
  ctx.font = `700 40px ${font}`;
  ctx.fillStyle = css("--verde");
  ctx.fillText("Disti", 48, y);
  const disti = ctx.measureText("Disti").width;
  ctx.fillStyle = css("--tinta");
  ctx.fillText("Node", 48 + disti, y);
  ctx.font = `400 32px ${font}`;
  ctx.fillStyle = css("--gris-texto");
  const date = new Intl.DateTimeFormat("es", { dateStyle: "long" }).format(new Date());
  const right = `${title} · ${date}`;
  ctx.fillText(right, canvas.width - 48 - ctx.measureText(right).width, y);
  return canvas.toDataURL("image/png");
}

/** Menú "Proyecto": exportar imagen, guardar e importar el diagrama. */
export function ProjectMenu({ name, compact = false }: { name: string; compact?: boolean }) {
  const [open, setOpen] = useState(false);
  const [status, setStatus] = useState<{ kind: "ok" | "error"; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const flow = useReactFlow();
  const diagram = useDiagramState();
  const actions = useActions();
  const fileRef = useRef<HTMLInputElement>(null);
  const rootRef = useRef<HTMLDivElement>(null);
  const empty = Object.keys(diagram.nodes).length === 0;
  const slug = fileSlug(name);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: PointerEvent) => {
      if (!rootRef.current?.contains(e.target as Node)) setOpen(false);
    };
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("pointerdown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("pointerdown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  function flash(kind: "ok" | "error", text: string) {
    setStatus({ kind, text });
    setTimeout(() => setStatus(null), 4000);
  }

  async function exportImage() {
    setBusy(true);
    try {
      const url = await diagramToPng(flow, name);
      if (url) {
        download(url, `${slug}.png`);
        flash("ok", "Imagen descargada.");
      }
    } catch {
      flash("error", "No se pudo crear la imagen.");
    } finally {
      setBusy(false);
      setOpen(false);
    }
  }

  function save() {
    const json = JSON.stringify(toProject(diagram, name), null, 2);
    const url = URL.createObjectURL(new Blob([json], { type: "application/json" }));
    download(url, `${slug}.distinode.json`);
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    setOpen(false);
    flash("ok", "Proyecto guardado.");
  }

  async function onFile(file: File | undefined) {
    if (!file) return;
    setOpen(false);
    if (file.size > 2_000_000) return flash("error", "El archivo es demasiado grande.");
    let raw: unknown;
    try {
      raw = JSON.parse(await file.text());
    } catch {
      return flash("error", "El archivo no es un JSON válido.");
    }
    const parsed = parseProject(raw);
    if (!parsed.ok) return flash("error", parsed.error);
    if (
      !empty &&
      !window.confirm(`Importar «${parsed.project.name}» sustituye el diagrama actual para todos. ¿Seguir?`)
    ) {
      return;
    }
    actions.replaceDiagram(parsed.project.nodes, parsed.project.edges, { ...parsed.project.sim });
    actions.notify(`importó el proyecto «${parsed.project.name}»`);
    flash("ok", `Importado: ${parsed.project.nodes.length} componentes.`);
    setTimeout(() => flow.fitView({ ...fitOptions(), duration: 400 }), 150);
  }

  const item =
    "flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-left text-sm hover:bg-verde-suave disabled:opacity-50 disabled:hover:bg-transparent";

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((o) => !o)}
        className="flex h-9 items-center gap-1.5 rounded-full px-3 text-sm font-semibold text-gris-texto hover:bg-verde-suave hover:text-tinta"
        title="Exportar imagen, guardar o importar el proyecto"
      >
        <svg
          width="18"
          height="18"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden="true"
        >
          <path d="M4 7a2 2 0 0 1 2-2h3l2 2h7a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2Z" />
        </svg>
        <span className={compact ? "sr-only" : ""}>Proyecto</span>
      </button>
      {open && (
        <div
          role="menu"
          className="absolute top-full right-0 z-50 mt-2 w-64 rounded-xl border border-linea bg-papel p-1.5 shadow-flota"
        >
          <button type="button" role="menuitem" className={item} onClick={exportImage} disabled={empty || busy}>
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
              className="shrink-0 text-verde"
            >
              <rect x="3" y="4" width="18" height="16" rx="2" />
              <circle cx="9" cy="10" r="2" />
              <path d="m21 16-5-5-9 9" />
            </svg>
            <span>
              <span className="block font-semibold">{busy ? "Creando imagen…" : "Exportar imagen"}</span>
              <span className="block text-xs text-gris-texto">PNG del diagrama completo</span>
            </span>
          </button>
          <button type="button" role="menuitem" className={item} onClick={save} disabled={empty}>
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
              className="shrink-0 text-verde"
            >
              <path d="M12 4v11" />
              <path d="m7 10 5 5 5-5" />
              <path d="M5 20h14" />
            </svg>
            <span>
              <span className="block font-semibold">Guardar proyecto</span>
              <span className="block text-xs text-gris-texto">Archivo .distinode.json</span>
            </span>
          </button>
          <button type="button" role="menuitem" className={item} onClick={() => fileRef.current?.click()}>
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
              className="shrink-0 text-verde"
            >
              <path d="M12 20V9" />
              <path d="m7 14 5-5 5 5" />
              <path d="M5 4h14" />
            </svg>
            <span>
              <span className="block font-semibold">Importar proyecto…</span>
              <span className="block text-xs text-gris-texto">Sustituye el diagrama actual</span>
            </span>
          </button>
        </div>
      )}
      <input
        ref={fileRef}
        type="file"
        accept=".json,application/json"
        className="hidden"
        onChange={(e) => {
          void onFile(e.target.files?.[0]);
          e.target.value = "";
        }}
      />
      {status && (
        <p
          role="status"
          className={`absolute top-full right-0 z-40 mt-2 w-max max-w-72 rounded-lg border bg-papel px-3 py-2 text-sm shadow-flota ${
            status.kind === "ok" ? "border-verde text-verde" : "border-rojo text-rojo"
          }`}
        >
          {status.text}
        </p>
      )}
    </div>
  );
}
