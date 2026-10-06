import Link from "next/link";
import { MetroHero } from "@/components/MetroHero";
import { SiteHeader } from "@/components/SiteHeader";
import { getUser } from "@/lib/supabase/server";

const steps = [
  { title: "Coloca estaciones", text: "Clientes, balanceadores, servidores, cachés y bases de datos." },
  { title: "Tiende las líneas", text: "Conecta los componentes como en un mapa de metro." },
  { title: "Dale al ▶", text: "Sube el tráfico, tumba un servidor y mira qué pasa." },
];

export default async function Home() {
  const user = await getUser().catch(() => null);
  const cta = user ? { href: "/salas", label: "Ir a mis salas" } : { href: "/entrar", label: "Empezar" };

  return (
    <>
      <SiteHeader>
        {!user && (
          <Link href="/entrar" className="btn btn-borde h-9 px-4 text-sm">
            Entrar
          </Link>
        )}
      </SiteHeader>
      <main className="mx-auto grid w-full max-w-6xl flex-1 items-center gap-10 px-5 pt-6 pb-16 md:grid-cols-[1fr_1.15fr] md:pt-16">
        <section>
          <h1 className="text-4xl leading-[1.08] font-bold tracking-tight text-balance md:text-[3.4rem]">
            Diseña sistemas distribuidos en equipo. <span className="text-verde">Y míralos funcionar.</span>
          </h1>
          <p className="mt-5 max-w-md text-lg text-gris-texto">
            Un lienzo compartido donde cada petición es un tren. Descubre por qué hace falta un balanceador cuando el
            servidor se pone en rojo.
          </p>
          <div className="mt-8 flex flex-wrap items-center gap-3">
            <Link href={cta.href} className="btn btn-primario">
              {cta.label}
            </Link>
            <span className="text-sm text-gris-texto">Gratis, en el navegador, sin instalar nada.</span>
          </div>
        </section>
        <div className="panel p-4 md:p-6">
          <MetroHero />
        </div>
      </main>
      <section aria-labelledby="como" className="mx-auto w-full max-w-6xl px-5 pb-20">
        <h2 id="como" className="sr-only">
          Cómo funciona
        </h2>
        <ol className="relative grid gap-8 md:grid-cols-3">
          <span
            aria-hidden="true"
            className="absolute top-[11px] right-[16%] left-[16%] hidden h-[6px] rounded-full bg-verde md:block"
          />
          {steps.map((s, i) => (
            <li key={s.title} className="relative flex gap-4 md:flex-col md:items-center md:text-center">
              <span
                aria-hidden="true"
                className="relative z-10 grid size-7 shrink-0 place-items-center rounded-full border-[5px] border-tinta bg-papel text-[0.7rem] font-bold"
              >
                {i + 1}
              </span>
              <div>
                <h3 className="font-semibold">{s.title}</h3>
                <p className="mt-1 text-gris-texto">{s.text}</p>
              </div>
            </li>
          ))}
        </ol>
      </section>
      <footer className="border-t border-linea py-6 text-center text-sm text-gris-texto">
        DistiNode · proyecto educativo de Sistemas Distribuidos — CUJAE
      </footer>
    </>
  );
}
