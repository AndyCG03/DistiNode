/**
 * Registro de componentes. Única fuente de verdad sobre qué piezas existen:
 * la barra lateral, el panel de propiedades, la guía (/guia) y el motor leen de aquí.
 * Para añadir un componente: una entrada aquí + su comportamiento en engine.ts.
 */

export type ComponentKind =
  "client" | "cdn" | "gateway" | "balancer" | "server" | "worker" | "cache" | "queue" | "database";

export type ParamKey =
  | "capacity"
  | "processingMs"
  | "queueMax"
  | "hitRate"
  | "healthCheckMs"
  | "lbAlgorithm"
  | "fanout"
  | "rateLimit"
  | "timeoutMs"
  | "retries";

export type Params = Partial<Record<ParamKey, number>>;

export interface ParamSpec {
  key: ParamKey;
  label: string;
  unit: string;
  min: number;
  max: number;
  step: number;
  help: string;
  /** Valores con nombre: se muestran como selector en lugar de deslizador. */
  options?: { value: number; label: string }[];
  /** Tope del deslizador; el campo numérico permite llegar a `max`. */
  sliderMax?: number;
}

export type ComponentGroup = "Tráfico" | "Cómputo" | "Datos";

export interface ComponentDocs {
  /** Qué es, en dos o tres frases. */
  what: string;
  /** Cuándo ponerlo en un diseño. */
  when: string;
  /** Cómo se comporta en la simulación. */
  model: string;
  /** Tecnologías reales que cumplen ese papel. */
  realWorld: string[];
}

export interface ComponentSpec {
  kind: ComponentKind;
  name: string;
  group: ComponentGroup;
  /** Una frase: qué hace. Se muestra como tooltip en la barra lateral. */
  tooltip: string;
  defaults: Params;
  params: ParamSpec[];
  docs: ComponentDocs;
}

const capacity = (def: number): ParamSpec => ({
  key: "capacity",
  label: "Capacidad",
  unit: "pet/s",
  min: 1,
  max: 2000,
  step: 1,
  sliderMax: 300,
  help: `Peticiones por segundo que puede atender sin formar cola (por defecto ${def}).`,
});

const processing = (def: number): ParamSpec => ({
  key: "processingMs",
  label: "Tiempo de proceso",
  unit: "ms",
  min: 1,
  max: 5000,
  step: 1,
  sliderMax: 500,
  help: `Lo que tarda en atender una petición sin esperar (por defecto ${def} ms).`,
});

const queue = (def: number): ParamSpec => ({
  key: "queueMax",
  label: "Tamaño de la cola",
  unit: "pet",
  min: 0,
  max: 5000,
  step: 1,
  sliderMax: 200,
  help: `Peticiones que pueden esperar; con la cola llena, las nuevas fallan (por defecto ${def}).`,
});

const hitRate = (def: number, who: string): ParamSpec => ({
  key: "hitRate",
  label: "Aciertos",
  unit: "%",
  min: 0,
  max: 100,
  step: 1,
  help: `Porcentaje de peticiones que ${who} responde sin preguntar a nadie (por defecto ${def} %).`,
});

export const COMPONENTS: Record<ComponentKind, ComponentSpec> = {
  client: {
    kind: "client",
    name: "Cliente",
    group: "Tráfico",
    tooltip: "Genera las peticiones de los usuarios: el tráfico sale de aquí.",
    defaults: { timeoutMs: 2000, retries: 0 },
    params: [
      {
        key: "timeoutMs",
        label: "Tiempo de espera",
        unit: "ms",
        min: 0,
        max: 30000,
        step: 50,
        sliderMax: 5000,
        help: "Si la respuesta tarda más, el cliente se rinde y la cuenta como error. 0 = espera siempre.",
      },
      {
        key: "retries",
        label: "Reintentos",
        unit: "",
        min: 0,
        max: 5,
        step: 1,
        help: "Cuántas veces repite una petición fallida. Ayuda con fallos sueltos… y empeora una saturación.",
      },
    ],
    docs: {
      what: "Representa a los usuarios (navegadores, apps móviles) que hacen peticiones al sistema.",
      when: "Siempre: es el origen del tráfico. Si hay varios clientes, el tráfico total se reparte entre ellos.",
      model:
        "Emite peticiones a ritmo regular. Espera la respuesta hasta su tiempo de espera; si falla o se agota, puede reintentar con espera exponencial (100 ms, 200 ms, 400 ms…).",
      realWorld: ["Navegador web", "App móvil", "Otro servicio que nos llama"],
    },
  },
  cdn: {
    kind: "cdn",
    name: "CDN",
    group: "Tráfico",
    tooltip: "Copias del contenido cerca del usuario: responde al instante lo que ya conoce.",
    defaults: { hitRate: 60 },
    params: [hitRate(60, "la CDN")],
    docs: {
      what: "Red de servidores repartidos por el mundo que guardan copias de imágenes, scripts y páginas.",
      when: "Delante de todo, cuando gran parte de las peticiones piden lo mismo (contenido estático o poco cambiante).",
      model: "Con probabilidad «Aciertos» responde ella misma en 2 ms; si no, pasa la petición hacia dentro.",
      realWorld: ["Cloudflare", "Akamai", "Amazon CloudFront", "Fastly"],
    },
  },
  gateway: {
    kind: "gateway",
    name: "API Gateway",
    group: "Tráfico",
    tooltip: "Puerta de entrada única: limita cuántas peticiones por segundo deja pasar.",
    defaults: { rateLimit: 150 },
    params: [
      {
        key: "rateLimit",
        label: "Límite",
        unit: "pet/s",
        min: 1,
        max: 5000,
        step: 1,
        sliderMax: 300,
        help: "Por encima de este ritmo rechaza peticiones (HTTP 429) para proteger lo que hay detrás.",
      },
    ],
    docs: {
      what: "Punto de entrada único de una API: autentica, enruta y limita el ritmo de las peticiones.",
      when: "Para proteger los servicios internos de picos de tráfico o de clientes abusivos.",
      model:
        "Cubo de fichas: se rellena a «Límite» fichas por segundo (máximo un segundo acumulado). Sin ficha, la petición se rechaza al momento.",
      realWorld: ["Kong", "NGINX", "AWS API Gateway", "Traefik"],
    },
  },
  balancer: {
    kind: "balancer",
    name: "Balanceador",
    group: "Tráfico",
    tooltip: "Reparte las peticiones entre los servidores que siguen sanos.",
    defaults: { healthCheckMs: 1000, lbAlgorithm: 0 },
    params: [
      {
        key: "lbAlgorithm",
        label: "Algoritmo",
        unit: "",
        min: 0,
        max: 1,
        step: 1,
        help: "Por turnos reparte a partes iguales; «menos conexiones» manda al que tiene menos trabajo pendiente.",
        options: [
          { value: 0, label: "Por turnos (round-robin)" },
          { value: 1, label: "Menos conexiones" },
        ],
      },
      {
        key: "healthCheckMs",
        label: "Chequeo de salud cada",
        unit: "ms",
        min: 100,
        max: 10000,
        step: 100,
        sliderMax: 5000,
        help: "Cada cuánto comprueba si sus destinos responden. Más corto = esquiva antes los caídos.",
      },
    ],
    docs: {
      what: "Reparte el tráfico entre varias copias de un servicio para sumar capacidad y tolerar caídas.",
      when: "En cuanto un servidor no basta, o cuando no puedes permitirte que la caída de uno tumbe el sistema.",
      model:
        "Cada «Chequeo de salud» marca como sanos los destinos encendidos y alcanzables. Entre chequeos no se entera de una caída: esas peticiones fallan. «Menos conexiones» cuenta las peticiones enviadas sin respuesta.",
      realWorld: ["HAProxy", "NGINX", "AWS ELB", "Envoy"],
    },
  },
  server: {
    kind: "server",
    name: "Servidor",
    group: "Cómputo",
    tooltip: "Procesa peticiones; si llegan más de las que aguanta, se forma una cola.",
    defaults: { capacity: 50, processingMs: 80, queueMax: 40, fanout: 0 },
    params: [
      capacity(50),
      processing(80),
      queue(40),
      {
        key: "fanout",
        label: "Llama a lo que tiene detrás",
        unit: "",
        min: 0,
        max: 1,
        step: 1,
        help: "«Uno por turno» pregunta a un solo destino; «a todos en paralelo» espera a todos (microservicios).",
        options: [
          { value: 0, label: "A uno, por turnos" },
          { value: 1, label: "A todos, en paralelo" },
        ],
      },
    ],
    docs: {
      what: "Una instancia de tu aplicación: ejecuta la lógica de cada petición.",
      when: "Siempre que haya trabajo que hacer. Para escalar, pon varios detrás de un balanceador.",
      model:
        "Atiende varias peticiones a la vez (capacidad × tiempo de proceso). Si están todos ocupados, la petición espera en cola; con la cola llena, falla. Si tiene destinos detrás, los llama tras procesar. En modo «a todos», espera la respuesta más lenta y falla si falla cualquiera.",
      realWorld: ["Node.js", "Spring Boot", "Django", "Un contenedor en Kubernetes"],
    },
  },
  worker: {
    kind: "worker",
    name: "Worker",
    group: "Cómputo",
    tooltip: "Procesa en segundo plano los mensajes que le entrega una cola.",
    defaults: { capacity: 30, processingMs: 150, queueMax: 10 },
    params: [capacity(30), processing(150), queue(10)],
    docs: {
      what: "Proceso que consume tareas de una cola: enviar correos, generar facturas, redimensionar imágenes…",
      when: "Detrás de una cola, para trabajo que no hace falta terminar antes de responder al usuario.",
      model:
        "Igual que un servidor. La cola solo le entrega tantos mensajes como puede procesar a la vez; si cae, los mensajes vuelven a la cola.",
      realWorld: ["Celery", "Sidekiq", "Consumidores de Kafka", "AWS Lambda"],
    },
  },
  cache: {
    kind: "cache",
    name: "Caché",
    group: "Datos",
    tooltip: "Guarda respuestas recientes para no tener que preguntar a la base de datos.",
    defaults: { hitRate: 70 },
    params: [hitRate(70, "la caché")],
    docs: {
      what: "Memoria muy rápida con resultados ya calculados o leídos.",
      when: "Delante de una base de datos o un servicio lento, si muchas lecturas se repiten.",
      model: "Con probabilidad «Aciertos» responde en 1 ms; si no, pregunta a lo que tiene detrás.",
      realWorld: ["Redis", "Memcached", "Varnish"],
    },
  },
  queue: {
    kind: "queue",
    name: "Cola de mensajes",
    group: "Datos",
    tooltip: "Acepta el trabajo al momento y lo reparte a los workers a su ritmo.",
    defaults: { queueMax: 500 },
    params: [
      {
        key: "queueMax",
        label: "Capacidad",
        unit: "msj",
        min: 1,
        max: 100000,
        step: 1,
        sliderMax: 2000,
        help: "Mensajes que puede guardar. Llena, rechaza los nuevos.",
      },
    ],
    docs: {
      what: "Intermediario asíncrono: quien envía no espera a que el trabajo se haga.",
      when: "Para absorber picos, desacoplar servicios y hacer en segundo plano lo que no urge.",
      model:
        "Confirma cada mensaje en cuanto lo guarda (el cliente recibe respuesta rápida) y lo entrega a sus consumidores según su capacidad libre. Si un consumidor falla, el mensaje vuelve a la cola (al menos una vez).",
      realWorld: ["RabbitMQ", "Apache Kafka", "Amazon SQS", "Redis Streams"],
    },
  },
  database: {
    kind: "database",
    name: "Base de datos",
    group: "Datos",
    tooltip: "Guarda los datos; es la pieza más difícil de multiplicar.",
    defaults: { capacity: 120, processingMs: 25, queueMax: 100 },
    params: [capacity(120), processing(25), queue(100)],
    docs: {
      what: "Donde viven los datos de forma duradera.",
      when: "Casi siempre. Es difícil de escalar: protégela con cachés, colas y réplicas de lectura (otra BD detrás de un balanceador).",
      model: "Igual que un servidor: capacidad, tiempo de proceso y cola. Suele ser el cuello de botella final.",
      realWorld: ["PostgreSQL", "MySQL", "MongoDB", "Cassandra"],
    },
  },
};

export const COMPONENT_ORDER: ComponentKind[] = [
  "client",
  "cdn",
  "gateway",
  "balancer",
  "server",
  "worker",
  "cache",
  "queue",
  "database",
];

export const GROUPS: ComponentGroup[] = ["Tráfico", "Cómputo", "Datos"];

/** Componentes con capacidad, trabajadores y cola propia. */
export const hasCapacity = (k: ComponentKind) => k === "server" || k === "worker" || k === "database";

export function isComponentKind(v: unknown): v is ComponentKind {
  return typeof v === "string" && v in COMPONENTS;
}

/** "Servidor 2": el primer número libre para ese tipo. */
export function nextLabel(kind: ComponentKind, existing: Iterable<string>): string {
  const base = COMPONENTS[kind].name;
  const taken = new Set(existing);
  if (kind === "client" || kind === "balancer" || kind === "cdn" || kind === "gateway") {
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
