import type { Metadata } from "next";
import Link from "next/link";
import { SiteHeader } from "@/components/SiteHeader";
import { HexIcon } from "@/features/canvas/icons";
import { TemplatePreview } from "@/features/canvas/templates";
import { COMPONENTS, COMPONENT_ORDER, GROUPS } from "@/sim/components";
import { THRESHOLDS } from "@/sim/engine";
import { TEMPLATES } from "@/sim/templates";

export const metadata: Metadata = {
  title: "Guía",
  description: "Cómo funciona DistiNode: componentes, métricas, fallos, plantillas y retos para practicar.",
};

const TOC = [
  { id: "como-funciona", label: "Cómo funciona" },
  { id: "componentes", label: "Componentes" },
  { id: "metricas", label: "Métricas y colores" },
  { id: "fallos", label: "Fallos" },
  { id: "plantillas", label: "Plantillas" },
  { id: "retos", label: "Retos" },
  { id: "equipo", label: "Trabajo en equipo y atajos" },
  { id: "glosario", label: "Glosario" },
];

const RETOS = [
  {
    title: "200 pet/s sin errores",
    goal: "Partiendo de «Lo esencial», llega a 200 pet/s con 0 % de errores y p95 por debajo de 200 ms.",
    hint: "Más servidores detrás del balanceador… y luego mira quién es el siguiente cuello de botella.",
  },
  {
    title: "Sobrevive al caos",
    goal: "Con «Caos» activado durante un minuto, mantén los errores por debajo del 2 %.",
    hint: "Redundancia en cada capa, reintentos moderados (1–2) y chequeos de salud más frecuentes.",
  },
  {
    title: "Para la tormenta",
    goal: "En «Tormenta de reintentos», sube a 60 pet/s sin que el sistema colapse y sin quitar los reintentos.",
    hint: "Un API Gateway con límite delante del servidor convierte la avalancha en rechazos rápidos.",
  },
  {
    title: "El catálogo lento",
    goal: "En «Microservicios», degrada el Servicio Catálogo y consigue que la p95 vuelva por debajo de 250 ms.",
    hint: "Más aciertos en su caché, o una segunda instancia del servicio tras un balanceador.",
  },
  {
    title: "Que los pedidos no se pierdan",
    goal: "En «Trabajo en segundo plano», tumba la base de datos 20 s y comprueba que no se pierde ningún trabajo.",
    hint: "Fíjate en la cola: los mensajes que fallan vuelven a ella (entrega al menos una vez).",
  },
  {
    title: "Al otro lado del océano",
    goal: "Añade 80 ms de latencia a la línea Cliente → primer componente y mantén la p95 por debajo de 300 ms.",
    hint: "Lo que no viaja no tarda: una CDN con muchos aciertos responde antes de cruzar el océano.",
  },
];

const GLOSARIO: [string, string][] = [
  ["Cuello de botella", "El componente que se satura primero y limita a todo el sistema."],
  ["Punto único de fallo", "Pieza sin copia: si cae, cae todo. Se evita con redundancia."],
  ["Redundancia", "Tener varias copias de un componente para que la caída de una no se note."],
  ["Chequeo de salud", "Consulta periódica del balanceador para saber qué destinos responden."],
  ["Round-robin", "Repartir por turnos: uno a cada destino, en orden."],
  [
    "Latencia p95",
    "El 95 % de las peticiones tarda menos que este valor. Muestra lo que sufren los usuarios peor atendidos.",
  ],
  ["Rendimiento", "Peticiones atendidas con éxito por segundo."],
  ["Limitación de ritmo", "Rechazar a propósito lo que pasa de un umbral para proteger lo de detrás (HTTP 429)."],
  [
    "Tormenta de reintentos",
    "Los reintentos de muchos clientes multiplican la carga justo cuando el sistema está peor.",
  ],
  ["Espera exponencial", "Esperar cada vez el doble antes de reintentar, para no empeorar una saturación."],
  ["Fan-out", "Una petición que se convierte en varias en paralelo; tarda lo que la más lenta."],
  ["Entrega al menos una vez", "Una cola reentrega los mensajes que fallan; el consumidor debe tolerar duplicados."],
  ["Partición de red", "Dos partes del sistema dejan de verse entre sí aunque ambas sigan vivas."],
  ["Degradación", "Un componente que sigue vivo pero responde mucho más lento: a veces peor que caído."],
];

export default function GuiaPage() {
  return (
    <>
      <SiteHeader>
        <Link href="/demo" className="btn btn-borde h-9 px-4 text-sm">
          Abrir la demo
        </Link>
      </SiteHeader>
      <div className="mx-auto grid w-full max-w-6xl gap-10 px-5 pt-6 pb-24 lg:grid-cols-[200px_1fr]">
        <nav aria-label="Contenido de la guía" className="hidden lg:block">
          <ul className="sticky top-6 flex flex-col gap-1 border-l-[5px] border-verde pl-4 text-sm">
            {TOC.map((t) => (
              <li key={t.id}>
                <a href={`#${t.id}`} className="block rounded py-1 text-gris-texto hover:text-tinta">
                  {t.label}
                </a>
              </li>
            ))}
          </ul>
        </nav>

        <main className="min-w-0 max-w-3xl">
          <h1 className="text-4xl font-bold tracking-tight">Guía de DistiNode</h1>
          <p className="mt-3 text-lg text-gris-texto">
            Todo lo que necesitas para diseñar, romper y arreglar sistemas distribuidos en el lienzo.
          </p>

          <Section id="como-funciona" title="Cómo funciona">
            <p>
              Cada sistema es un <strong>mapa de metro</strong>: los componentes son estaciones y las conexiones,
              líneas. Las peticiones viajan como trenes en el sentido de la flecha y la respuesta vuelve por la misma
              línea.
            </p>
            <ul className="my-4 grid gap-2 sm:grid-cols-2">
              <Legend shape="pill" fill="var(--papel)" stroke="var(--tinta)" text="Petición de un cliente" />
              <Legend shape="pill" fill="var(--gris-tren)" text="Respuesta correcta" />
              <Legend shape="pill" fill="var(--rojo)" text="Error que vuelve al cliente" />
              <Legend shape="diamond" fill="var(--tinta)" text="Mensaje de una cola hacia un worker" />
            </ul>
            <p>
              <strong>Dos relojes.</strong> Los trenes van a cámara lenta para que se vean (unas décimas de segundo por
              línea). Las métricas usan el tiempo <em>simulado</em>: lo que tardan de verdad la espera en colas, el
              proceso y la latencia de red. Por eso un sistema sano marca ~100 ms aunque el tren tarde más en volver.
            </p>
            <p>
              <strong>Cada navegador simula por su cuenta</strong> con el mismo diagrama, tráfico y fallos, así que
              entre pantallas puede haber pequeñas diferencias de trenes. Las caídas, en cambio, son compartidas.
            </p>
          </Section>

          <Section id="componentes" title="Componentes">
            <p>
              Hay {COMPONENT_ORDER.length} componentes, en tres familias. Pulsa el <strong>?</strong> del panel de
              propiedades para llegar aquí desde el lienzo.
            </p>
            {GROUPS.map((group) => (
              <div key={group} className="mt-8">
                <h3 className="mb-3 text-sm font-semibold text-gris-texto">{group}</h3>
                <div className="flex flex-col gap-8">
                  {COMPONENT_ORDER.filter((k) => COMPONENTS[k].group === group).map((kind) => {
                    const c = COMPONENTS[kind];
                    return (
                      <article key={kind} id={kind} className="scroll-mt-6">
                        <header className="flex items-center gap-3">
                          <HexIcon kind={kind} size={40} className="text-verde" />
                          <h4 className="text-xl font-bold">{c.name}</h4>
                        </header>
                        <p className="mt-2">{c.docs.what}</p>
                        <dl className="mt-3 grid gap-x-6 gap-y-2 text-[0.95rem] sm:grid-cols-[9rem_1fr]">
                          <dt className="font-semibold">Cuándo usarlo</dt>
                          <dd className="text-gris-texto">{c.docs.when}</dd>
                          <dt className="font-semibold">En la simulación</dt>
                          <dd className="text-gris-texto">{c.docs.model}</dd>
                          {c.params.length > 0 && (
                            <>
                              <dt className="font-semibold">Ajustes</dt>
                              <dd className="text-gris-texto">
                                <ul className="flex flex-col gap-1">
                                  {c.params.map((p) => (
                                    <li key={p.key}>
                                      <span className="font-semibold text-tinta">{p.label}</span>
                                      {p.options ? ` (${p.options.map((o) => o.label).join(" / ")})` : ""}: {p.help}
                                    </li>
                                  ))}
                                </ul>
                              </dd>
                            </>
                          )}
                          <dt className="font-semibold">En el mundo real</dt>
                          <dd className="flex flex-wrap gap-1.5">
                            {c.docs.realWorld.map((r) => (
                              <span key={r} className="rounded-md bg-verde-suave px-2 py-0.5 text-sm text-verde">
                                {r}
                              </span>
                            ))}
                          </dd>
                        </dl>
                      </article>
                    );
                  })}
                </div>
              </div>
            ))}
          </Section>

          <Section id="metricas" title="Métricas y colores">
            <dl className="grid gap-x-6 gap-y-3 sm:grid-cols-[10rem_1fr]">
              <dt className="font-semibold">Completadas</dt>
              <dd className="text-gris-texto">
                Respuestas correctas que llegan a los clientes por segundo (últimos 2 s).
              </dd>
              <dt className="font-semibold">Latencia p95</dt>
              <dd className="text-gris-texto">
                El 95 % de las respuestas tarda menos. La media está en el tooltip; la p95 enseña mejor los problemas.
              </dd>
              <dt className="font-semibold">Errores</dt>
              <dd className="text-gris-texto">
                Peticiones que fallaron: rechazadas, nodo caído, línea cortada o tiempo de espera agotado. Con
                reintentos, solo cuenta si fallan todos los intentos.
              </dd>
              <dt className="font-semibold">Reintentos</dt>
              <dd className="text-gris-texto">Aparece cuando algún cliente reintenta. Si crece mucho: tormenta.</dd>
              <dt className="font-semibold">En segundo plano</dt>
              <dd className="text-gris-texto">
                Mensajes procesados por los workers y mensajes esperando en las colas.
              </dd>
            </dl>
            <p className="mt-4">El borde de cada estación indica su estado mientras la simulación corre:</p>
            <ul className="mt-2 flex flex-col gap-2">
              <StateRow
                color="var(--verde)"
                label="Verde"
                text={`carga por debajo del ${THRESHOLDS.warnRho * 100} %.`}
              />
              <StateRow
                color="var(--ambar)"
                label="Ámbar"
                text={`carga a partir del ${THRESHOLDS.warnRho * 100} %, cola por encima del ${THRESHOLDS.warnQueue * 100} %, o degradado.`}
              />
              <StateRow
                color="var(--rojo)"
                label="Rojo"
                text={`saturado: carga del 100 % o más, cola por encima del ${THRESHOLDS.hotQueue * 100} %, o rechazando peticiones.`}
              />
              <StateRow
                color="var(--gris)"
                label="Gris discontinuo"
                text="caído. Si se cayó solo, muestra la cuenta atrás del reinicio."
                dashed
              />
            </ul>
          </Section>

          <Section id="fallos" title="Fallos">
            <p>
              Los sistemas reales fallan de muchas maneras. Puedes provocar cada una a mano o dejar que pasen solas.
            </p>
            <dl className="mt-4 grid gap-x-6 gap-y-3 sm:grid-cols-[11rem_1fr]">
              <dt className="font-semibold">Tumbar</dt>
              <dd className="text-gris-texto">
                El componente deja de responder y lo que tenía dentro falla. Sigue caído hasta que alguien lo revive.
              </dd>
              <dt className="font-semibold">Degradar (lento)</dt>
              <dd className="text-gris-texto">
                Sigue vivo pero procesa 4 veces más lento (o añade 150 ms si no hace cola). El balanceador no lo
                detecta: su chequeo solo mira si responde.
              </dd>
              <dt className="font-semibold">Cortar conexión</dt>
              <dd className="text-gris-texto">
                Selecciona una línea y córtala: es una partición de red. Lo que viaja por ella falla.
              </dd>
              <dt className="font-semibold">Latencia de red</dt>
              <dd className="text-gris-texto">
                Añade milisegundos a una línea (ida y vuelta): distancia o red congestionada.
              </dd>
              <dt className="font-semibold">Caos</dt>
              <dd className="text-gris-texto">
                Interruptor de la barra inferior. Cada segundo hay una probabilidad de que algo se caiga, se vuelva
                lento o se corte una línea; todo vuelve solo a los pocos segundos. Como Chaos Monkey de Netflix.
              </dd>
              <dt className="font-semibold">Sobrecarga tumba</dt>
              <dd className="text-gris-texto">
                Un componente saturado más de 5 s se cae y tarda unos segundos en reiniciar. Sin redundancia, su caída
                arrastra a los demás: la cascada típica de un pico de tráfico.
              </dd>
            </dl>
            <p className="mt-4">
              En una sala compartida, un solo navegador (el primero que entró) decide los fallos automáticos y los
              escribe en el estado compartido, así que todos ven las mismas caídas y los mismos avisos.
            </p>
          </Section>

          <Section id="plantillas" title="Plantillas">
            <p>
              Desde un lienzo vacío o con el botón <strong>Plantillas…</strong> de la barra lateral. Cargar una
              plantilla sustituye el diagrama para todos los de la sala.
            </p>
            <ul className="mt-4 flex flex-col gap-4">
              {TEMPLATES.map((t) => (
                <li key={t.id} className="flex flex-col gap-3 rounded-xl border border-linea bg-papel p-4 sm:flex-row">
                  <span className="self-start rounded-lg bg-fondo p-1.5">
                    <TemplatePreview template={t} width={160} height={72} />
                  </span>
                  <div>
                    <h3 className="font-bold">{t.name}</h3>
                    <p className="text-gris-texto">{t.summary}</p>
                    <p className="mt-2 text-[0.95rem]">
                      <span className="font-semibold">Prueba esto: </span>
                      {t.tryThis}
                    </p>
                  </div>
                </li>
              ))}
            </ul>
          </Section>

          <Section id="retos" title="Retos">
            <p>Para clase o para practicar en equipo. Cada uno se resuelve con piezas de la barra lateral.</p>
            <ol className="mt-4 flex flex-col gap-4">
              {RETOS.map((r, i) => (
                <li key={r.title} className="flex gap-4">
                  <span
                    aria-hidden="true"
                    className="grid size-8 shrink-0 place-items-center rounded-full border-[4px] border-tinta bg-papel text-sm font-bold"
                  >
                    {i + 1}
                  </span>
                  <div>
                    <h3 className="font-bold">{r.title}</h3>
                    <p>{r.goal}</p>
                    <details className="mt-1 text-gris-texto">
                      <summary className="cursor-pointer text-sm font-semibold text-verde">Pista</summary>
                      <p className="mt-1">{r.hint}</p>
                    </details>
                  </div>
                </li>
              ))}
            </ol>
          </Section>

          <Section id="equipo" title="Trabajo en equipo y atajos">
            <ul className="flex list-disc flex-col gap-2 pl-5">
              <li>Crea una sala en «Mis salas» y comparte el enlace o el código de 6 caracteres.</li>
              <li>
                Ves el cursor y el nombre de los demás; el borde de color indica quién tiene seleccionada cada estación.
              </li>
              <li>▶/⏸, el tráfico, las caídas y los interruptores de fallos son compartidos. Todo se guarda solo.</li>
              <li>
                <kbd className="font-semibold">Espacio</kbd> pone en marcha o pausa ·{" "}
                <kbd className="font-semibold">Supr</kbd> o <kbd className="font-semibold">Retroceso</kbd> borra lo
                seleccionado · arrastra con el ratón para mover el lienzo y usa la rueda para acercar.
              </li>
              <li>En el móvil, las salas se pueden ver pero no editar.</li>
            </ul>
          </Section>

          <Section id="glosario" title="Glosario">
            <dl className="grid gap-x-6 gap-y-3 sm:grid-cols-[13rem_1fr]">
              {GLOSARIO.map(([term, def]) => (
                <div key={term} className="contents">
                  <dt className="font-semibold">{term}</dt>
                  <dd className="text-gris-texto">{def}</dd>
                </div>
              ))}
            </dl>
          </Section>
        </main>
      </div>
    </>
  );
}

function Section({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  return (
    <section id={id} aria-labelledby={`${id}-t`} className="mt-14 scroll-mt-6 leading-relaxed">
      <h2 id={`${id}-t`} className="mb-3 text-2xl font-bold tracking-tight">
        {title}
      </h2>
      <div className="flex flex-col gap-3">{children}</div>
    </section>
  );
}

function Legend({
  shape,
  fill,
  stroke,
  text,
}: {
  shape: "pill" | "diamond";
  fill: string;
  stroke?: string;
  text: string;
}) {
  return (
    <li className="flex items-center gap-3">
      <svg width="40" height="16" viewBox="0 0 40 16" aria-hidden="true">
        <line x1="0" y1="8" x2="40" y2="8" stroke="var(--verde)" strokeWidth="6" strokeLinecap="round" />
        {shape === "pill" ? (
          <rect x="12" y="4" width="16" height="8" rx="4" fill={fill} stroke={stroke ?? "none"} strokeWidth="1.5" />
        ) : (
          <path d="M20 2 L26 8 L20 14 L14 8 Z" fill={fill} stroke="var(--papel)" strokeWidth="1.5" />
        )}
      </svg>
      {text}
    </li>
  );
}

function StateRow({ color, label, text, dashed }: { color: string; label: string; text: string; dashed?: boolean }) {
  return (
    <li className="flex items-center gap-3">
      <span
        aria-hidden="true"
        className="inline-block h-5 w-10 shrink-0 rounded-full border-[3.5px] bg-papel"
        style={{ borderColor: color, borderStyle: dashed ? "dashed" : "solid" }}
      />
      <span>
        <span className="font-semibold">{label}:</span> {text}
      </span>
    </li>
  );
}
