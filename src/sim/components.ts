/**
 * Registro de componentes. Única fuente de verdad sobre qué piezas existen:
 * la barra lateral, el panel de propiedades y el motor leen de aquí.
 * Para añadir un componente: una entrada aquí + su comportamiento en engine.ts.
 */

export type ComponentKind = "client" | "balancer" | "server" | "cache" | "database";

export type ParamKey = "capacity" | "processingMs" | "queueMax" | "hitRate" | "healthCheckMs";

export type Params = Partial<Record<ParamKey, number>>;

export interface ParamSpec {
  key: ParamKey;
  label: string;
  unit: string;
  min: number;
  max: number;
  step: number;
  help: string;
}

export interface ComponentSpec {
  kind: ComponentKind;
  name: string;
  /** Una frase: qué hace. Se muestra como tooltip en la barra lateral. */
  tooltip: string;
  defaults: Params;
  params: ParamSpec[];
}

const capacity = (def: number): ParamSpec => ({
  key: "capacity",
  label: "Capacidad",
  unit: "pet/s",
  min: 1,
  max: 1000,
  step: 1,
  help: `Peticiones por segundo que puede atender sin formar cola (por defecto ${def}).`,
});

const processing = (def: number): ParamSpec => ({
  key: "processingMs",
  label: "Tiempo de proceso",
  unit: "ms",
  min: 1,
  max: 2000,
  step: 1,
  help: `Lo que tarda en atender una petición sin esperar (por defecto ${def} ms).`,
});

const queue = (def: number): ParamSpec => ({
  key: "queueMax",
  label: "Tamaño de la cola",
  unit: "pet",
  min: 0,
  max: 1000,
  step: 1,
  help: `Peticiones que pueden esperar; con la cola llena, las nuevas fallan (por defecto ${def}).`,
});

export const COMPONENTS: Record<ComponentKind, ComponentSpec> = {
  client: {
    kind: "client",
    name: "Cliente",
    tooltip: "Genera las peticiones de los usuarios: el tráfico sale de aquí.",
    defaults: {},
    params: [],
  },
  balancer: {
    kind: "balancer",
    name: "Balanceador",
    tooltip: "Reparte las peticiones por turnos entre los servidores que siguen sanos.",
    defaults: { healthCheckMs: 1000 },
    params: [
      {
        key: "healthCheckMs",
        label: "Chequeo de salud cada",
        unit: "ms",
        min: 100,
        max: 10000,
        step: 100,
        help: "Cada cuánto comprueba si sus destinos responden. Más corto = esquiva antes los caídos.",
      },
    ],
  },
  server: {
    kind: "server",
    name: "Servidor",
    tooltip: "Procesa peticiones; si llegan más de las que aguanta, se forma una cola.",
    defaults: { capacity: 50, processingMs: 80, queueMax: 40 },
    params: [capacity(50), processing(80), queue(40)],
  },
  cache: {
    kind: "cache",
    name: "Caché",
    tooltip: "Guarda respuestas recientes para no tener que preguntar a la base de datos.",
    defaults: { hitRate: 70 },
    params: [
      {
        key: "hitRate",
        label: "Aciertos",
        unit: "%",
        min: 0,
        max: 100,
        step: 1,
        help: "Porcentaje de peticiones que la caché responde sin preguntar a nadie.",
      },
    ],
  },
  database: {
    kind: "database",
    name: "Base de datos",
    tooltip: "Guarda los datos; es la pieza más difícil de multiplicar.",
    defaults: { capacity: 120, processingMs: 25, queueMax: 100 },
    params: [capacity(120), processing(25), queue(100)],
  },
};

export const COMPONENT_ORDER: ComponentKind[] = ["client", "balancer", "server", "cache", "database"];

export function isComponentKind(v: unknown): v is ComponentKind {
  return typeof v === "string" && v in COMPONENTS;
}

/** "Servidor 2": el primer número libre para ese tipo. */
export function nextLabel(kind: ComponentKind, existing: Iterable<string>): string {
  const base = COMPONENTS[kind].name;
  const taken = new Set(existing);
  if (kind === "client" || kind === "balancer") {
    if (!taken.has(base)) return base;
  }
  for (let n = 1; ; n++) {
    const label = `${base} ${n}`;
    if (!taken.has(label)) return label;
  }
}

export function paramValue(kind: ComponentKind, params: Params | undefined, key: ParamKey): number {
  return params?.[key] ?? COMPONENTS[kind].defaults[key] ?? 0;
}
