import Link from "next/link";
import { SiteHeader } from "@/components/SiteHeader";

/** Se muestra cuando el despliegue aún no tiene las claves de un servicio. */
export function SetupNotice({ service, vars }: { service: string; vars: string[] }) {
  return (
    <>
      <SiteHeader />
      <main className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center px-5 pb-24">
        <h1 className="text-2xl font-bold tracking-tight">Las salas compartidas aún no están activas</h1>
        <p className="mt-2 text-gris-texto">
          Este despliegue no tiene configurado {service}. Mientras tanto puedes usar la demo: el mismo lienzo y la misma
          simulación, guardados en tu navegador.
        </p>
        <Link href="/demo" className="btn btn-primario mt-6 self-start">
          Abrir la demo
        </Link>
        <details className="mt-8 text-sm text-gris-texto">
          <summary className="cursor-pointer font-semibold text-tinta">Para quien administra el sitio</summary>
          <p className="mt-2">
            Añade estas variables de entorno (Vercel → Settings → Environment Variables) y vuelve a desplegar:
          </p>
          <ul className="mt-2 flex flex-col gap-1">
            {vars.map((v) => (
              <li key={v}>
                <code className="rounded bg-verde-suave px-1.5 py-0.5 text-tinta">{v}</code>
              </li>
            ))}
          </ul>
          <p className="mt-2">El README explica de dónde sale cada una.</p>
        </details>
      </main>
    </>
  );
}
