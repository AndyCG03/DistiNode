/**
 * Plantillas: sistemas listos para cargar en un lienzo vacío (o sustituyendo el actual).
 * Datos puros: la interfaz las dibuja, las pruebas las simulan y las futuras lecciones las reutilizarán.
 */

import type { ComponentKind, Params } from "./components";

export interface TemplateNode {
  key: string;
  kind: ComponentKind;
  label: string;
  /** Columna y fila en la rejilla de la plantilla. */
  col: number;
  row: number;
  params?: Params;
}

export type TemplateCategory = "Patrones" | "Sistemas reales";

export type TemplateEdge = [from: string, to: string, opts?: { latencyMs?: number }];

export interface Template {
  id: string;
  name: string;
  category: TemplateCategory;
  /** Una frase: qué es. */
  summary: string;
  /** Qué probar una vez cargada. */
  tryThis: string;
  traffic: number;
  nodes: TemplateNode[];
  edges: TemplateEdge[];
}

export const GRID = { x: 250, y: 110 } as const;

const n = (
  key: string,
  kind: ComponentKind,
  label: string,
  col: number,
  row: number,
  params?: Params,
): TemplateNode => ({
  key,
  kind,
  label,
  col,
  row,
  params,
});

export const TEMPLATES: Template[] = [
  {
    id: "basico",
    name: "Lo esencial",
    category: "Patrones",
    summary: "Cliente → Balanceador → Servidor → Base de datos.",
    tryThis: "Sube el tráfico a 70 pet/s: el servidor se pone rojo. Añade un segundo servidor detrás del balanceador.",
    traffic: 20,
    nodes: [
      n("c", "client", "Cliente", 0, 0),
      n("lb", "balancer", "Balanceador", 1, 0),
      n("s1", "server", "Servidor 1", 2, 0),
      n("db", "database", "Base de datos 1", 3, 0),
    ],
    edges: [
      ["c", "lb"],
      ["lb", "s1"],
      ["s1", "db"],
    ],
  },
  {
    id: "alta-disponibilidad",
    name: "Alta disponibilidad",
    category: "Patrones",
    summary: "Tres servidores tras un balanceador, con caché delante de la base de datos.",
    tryThis:
      "Activa «Caos» y mira cómo el balanceador esquiva servidores caídos. ¿Qué pasa cuando cae la caché o la base de datos? Ese es un punto único de fallo.",
    traffic: 100,
    nodes: [
      n("c", "client", "Cliente", 0, 1),
      n("lb", "balancer", "Balanceador", 1, 1),
      n("s1", "server", "Servidor 1", 2, 0),
      n("s2", "server", "Servidor 2", 2, 1),
      n("s3", "server", "Servidor 3", 2, 2),
      n("cache", "cache", "Caché 1", 3, 1),
      n("db", "database", "Base de datos 1", 4, 1),
    ],
    edges: [
      ["c", "lb"],
      ["lb", "s1"],
      ["lb", "s2"],
      ["lb", "s3"],
      ["s1", "cache"],
      ["s2", "cache"],
      ["s3", "cache"],
      ["cache", "db"],
    ],
  },
  {
    id: "web-a-escala",
    name: "Web a gran escala",
    category: "Patrones",
    summary: "CDN, API Gateway, granja de servidores, caché y réplicas de la base de datos.",
    tryThis:
      "Pon el tráfico a 200 pet/s. Baja los aciertos de la CDN a 0 % y mira dónde aparece el cuello de botella. Luego baja el límite del gateway para protegerlo.",
    traffic: 180,
    nodes: [
      n("c", "client", "Cliente", 0, 1),
      n("cdn", "cdn", "CDN", 1, 1),
      n("gw", "gateway", "API Gateway", 2, 1, { rateLimit: 200 }),
      n("lb", "balancer", "Balanceador web", 3, 1),
      n("s1", "server", "Servidor 1", 4, 0),
      n("s2", "server", "Servidor 2", 4, 1),
      n("s3", "server", "Servidor 3", 4, 2),
      n("cache", "cache", "Caché 1", 5, 1),
      n("lbdb", "balancer", "Balanceador BD", 6, 1),
      n("db1", "database", "Réplica 1", 7, 0.5),
      n("db2", "database", "Réplica 2", 7, 1.5),
    ],
    edges: [
      ["c", "cdn"],
      ["cdn", "gw"],
      ["gw", "lb"],
      ["lb", "s1"],
      ["lb", "s2"],
      ["lb", "s3"],
      ["s1", "cache"],
      ["s2", "cache"],
      ["s3", "cache"],
      ["cache", "lbdb"],
      ["lbdb", "db1"],
      ["lbdb", "db2"],
    ],
  },
  {
    id: "asincrono",
    name: "Trabajo en segundo plano",
    category: "Patrones",
    summary: "La API deja el trabajo en una cola y responde; tres workers lo procesan a su ritmo.",
    tryThis:
      "Tumba los tres workers: la cola crece, pero los clientes siguen recibiendo respuesta. Revívelos y mira cómo se vacía la cola.",
    traffic: 60,
    nodes: [
      n("c", "client", "Cliente", 0, 1),
      n("gw", "gateway", "API Gateway", 1, 1),
      n("api", "server", "Servidor API", 2, 1, { capacity: 100 }),
      n("q", "queue", "Cola de mensajes 1", 3, 1),
      n("w1", "worker", "Worker 1", 4, 0),
      n("w2", "worker", "Worker 2", 4, 1),
      n("w3", "worker", "Worker 3", 4, 2),
      n("db", "database", "Base de datos 1", 5, 1),
    ],
    edges: [
      ["c", "gw"],
      ["gw", "api"],
      ["api", "q"],
      ["q", "w1"],
      ["q", "w2"],
      ["q", "w3"],
      ["w1", "db"],
      ["w2", "db"],
      ["w3", "db"],
    ],
  },
  {
    id: "microservicios",
    name: "Microservicios",
    category: "Patrones",
    summary: "Un BFF consulta en paralelo a usuarios, catálogo y pedidos; cada servicio tiene sus datos.",
    tryThis:
      "La latencia es la del servicio más lento. Degrada el Servicio Catálogo y mira la p95. Tumba Usuarios: todo falla, porque el BFF necesita a los tres.",
    traffic: 60,
    nodes: [
      n("c", "client", "Cliente", 0, 1.5),
      n("gw", "gateway", "API Gateway", 1, 1.5),
      n("lb", "balancer", "Balanceador", 2, 1.5),
      n("bff1", "server", "BFF 1", 3, 1, { fanout: 1, capacity: 80 }),
      n("bff2", "server", "BFF 2", 3, 2, { fanout: 1, capacity: 80 }),
      n("users", "server", "Servicio Usuarios", 4, 0, { capacity: 150, processingMs: 30 }),
      n("catalog", "server", "Servicio Catálogo", 4, 1.5, { capacity: 150, processingMs: 40 }),
      n("orders", "server", "Servicio Pedidos", 4, 3, { capacity: 150, processingMs: 50 }),
      n("dbu", "database", "BD Usuarios", 5, 0),
      n("cachec", "cache", "Caché Catálogo", 5, 1.5, { hitRate: 85 }),
      n("dbc", "database", "BD Catálogo", 6, 1.5),
      n("qo", "queue", "Cola Pedidos", 5, 3),
      n("wpay", "worker", "Worker Pagos", 6, 3, { capacity: 80, processingMs: 100 }),
      n("dbo", "database", "BD Pedidos", 7, 3),
    ],
    edges: [
      ["c", "gw"],
      ["gw", "lb"],
      ["lb", "bff1"],
      ["lb", "bff2"],
      ["bff1", "users"],
      ["bff1", "catalog"],
      ["bff1", "orders"],
      ["bff2", "users"],
      ["bff2", "catalog"],
      ["bff2", "orders"],
      ["users", "dbu"],
      ["catalog", "cachec"],
      ["cachec", "dbc"],
      ["orders", "qo"],
      ["qo", "wpay"],
      ["wpay", "dbo"],
    ],
  },
  {
    id: "tormenta-de-reintentos",
    name: "Tormenta de reintentos",
    category: "Patrones",
    summary: "Clientes impacientes que reintentan 3 veces contra un servidor al límite.",
    tryThis:
      "Sube el tráfico a 55 pet/s: los reintentos multiplican la carga y el sistema colapsa. Prueba con 0 reintentos, o pon un API Gateway con límite delante.",
    traffic: 45,
    nodes: [
      n("c", "client", "Cliente", 0, 0, { timeoutMs: 400, retries: 3 }),
      n("s", "server", "Servidor 1", 1, 0, { capacity: 50, queueMax: 100 }),
      n("db", "database", "Base de datos 1", 2, 0),
    ],
    edges: [
      ["c", "s"],
      ["s", "db"],
    ],
  },
  // ── Sistemas reales ──────────────────────────────────────────────
  {
    id: "tienda-online",
    name: "Tienda online",
    category: "Sistemas reales",
    summary: "Catálogo con CDN y caché; cada compra deja el pedido en una cola que procesan los workers de pagos.",
    tryThis:
      "Black Friday: sube a 200 pet/s. ¿Quién se satura primero? Luego tumba un worker de pagos: los clientes no lo notan, la cola sí.",
    traffic: 120,
    nodes: [
      n("c", "client", "Compradores", 0, 1.5),
      n("cdn", "cdn", "CDN imágenes", 1, 1.5, { hitRate: 60 }),
      n("gw", "gateway", "API Gateway", 2, 1.5, { rateLimit: 250 }),
      n("lb", "balancer", "Balanceador", 3, 1.5),
      n("w1", "server", "Web 1", 4, 0.5, { fanout: 1 }),
      n("w2", "server", "Web 2", 4, 1.5, { fanout: 1 }),
      n("w3", "server", "Web 3", 4, 2.5, { fanout: 1 }),
      n("cache", "cache", "Caché productos", 5, 0.5),
      n("dbp", "database", "BD productos", 6, 0.5),
      n("q", "queue", "Cola pedidos", 5, 2.5),
      n("pay1", "worker", "Pagos 1", 6, 2),
      n("pay2", "worker", "Pagos 2", 6, 3),
      n("dbo", "database", "BD pedidos", 7, 2.5),
    ],
    edges: [
      ["c", "cdn"],
      ["cdn", "gw"],
      ["gw", "lb"],
      ["lb", "w1"],
      ["lb", "w2"],
      ["lb", "w3"],
      ["w1", "cache"],
      ["w2", "cache"],
      ["w3", "cache"],
      ["w1", "q"],
      ["w2", "q"],
      ["w3", "q"],
      ["cache", "dbp"],
      ["q", "pay1"],
      ["q", "pay2"],
      ["pay1", "dbo"],
      ["pay2", "dbo"],
    ],
  },
  {
    id: "streaming-video",
    name: "Streaming de vídeo",
    category: "Sistemas reales",
    summary: "Casi todo el vídeo sale de la CDN; el origen solo atiende lo que falta y registra lo que se ve.",
    tryThis:
      "Baja los aciertos de la CDN al 50 %: el origen, pensado para una pequeña parte del tráfico, se hunde. Así se nota cuánto trabajo hace una CDN.",
    traffic: 200,
    nodes: [
      n("c", "client", "Espectadores", 0, 1),
      n("cdn", "cdn", "CDN de vídeo", 1, 1, { hitRate: 95 }),
      n("gw", "gateway", "API Gateway", 2, 1),
      n("lb", "balancer", "Balanceador", 3, 1),
      n("p1", "server", "Reproducción 1", 4, 0.5, { fanout: 1 }),
      n("p2", "server", "Reproducción 2", 4, 1.5, { fanout: 1 }),
      n("meta", "cache", "Caché metadatos", 5, 0.5, { hitRate: 90 }),
      n("dbc", "database", "BD catálogo", 6, 0.5),
      n("ev", "queue", "Eventos de visionado", 5, 1.5),
      n("rec", "worker", "Recomendaciones", 6, 1.5),
      n("dba", "database", "BD analítica", 7, 1.5),
    ],
    edges: [
      ["c", "cdn"],
      ["cdn", "gw"],
      ["gw", "lb"],
      ["lb", "p1"],
      ["lb", "p2"],
      ["p1", "meta"],
      ["p2", "meta"],
      ["p1", "ev"],
      ["p2", "ev"],
      ["meta", "dbc"],
      ["ev", "rec"],
      ["rec", "dba"],
    ],
  },
  {
    id: "mensajeria",
    name: "Mensajería instantánea",
    category: "Sistemas reales",
    summary: "Servidores de chat que guardan cada mensaje en una cola y consultan la presencia en una caché.",
    tryThis:
      "Tumba la base de datos de mensajes 15 s: no se pierde ninguno, la cola los guarda y los reentrega al volver. Compara con quitar la cola.",
    traffic: 150,
    nodes: [
      n("c", "client", "Usuarios", 0, 1),
      n("lb", "balancer", "Balanceador", 1, 1, { lbAlgorithm: 1 }),
      n("s1", "server", "Chat 1", 2, 0, { fanout: 1, capacity: 80 }),
      n("s2", "server", "Chat 2", 2, 1, { fanout: 1, capacity: 80 }),
      n("s3", "server", "Chat 3", 2, 2, { fanout: 1, capacity: 80 }),
      n("pres", "cache", "Presencia", 3, 0, { hitRate: 100 }),
      n("q", "queue", "Cola mensajes", 3, 1.5, { queueMax: 3000 }),
      n("d1", "worker", "Entrega 1", 4, 1, { capacity: 100 }),
      n("d2", "worker", "Entrega 2", 4, 2, { capacity: 100 }),
      n("db", "database", "BD mensajes", 5, 1.5, { capacity: 250 }),
    ],
    edges: [
      ["c", "lb"],
      ["lb", "s1"],
      ["lb", "s2"],
      ["lb", "s3"],
      ["s1", "pres"],
      ["s2", "pres"],
      ["s3", "pres"],
      ["s1", "q"],
      ["s2", "q"],
      ["s3", "q"],
      ["q", "d1"],
      ["q", "d2"],
      ["d1", "db"],
      ["d2", "db"],
    ],
  },
  {
    id: "pagos",
    name: "Pasarela de pagos",
    category: "Sistemas reales",
    summary: "Cada pago consulta a la vez al antifraude y a la base de transacciones; el cliente reintenta una vez.",
    tryThis:
      "Degrada el servicio antifraude: todos los pagos esperan por él. Baja el tiempo de espera del cliente a 300 ms y mira cómo los pagos lentos se convierten en errores.",
    traffic: 60,
    nodes: [
      n("c", "client", "Tiendas", 0, 1, { timeoutMs: 3000, retries: 1 }),
      n("gw", "gateway", "API Gateway", 1, 1, { rateLimit: 100 }),
      n("lb", "balancer", "Balanceador", 2, 1),
      n("p1", "server", "Pagos 1", 3, 0.5, { fanout: 1 }),
      n("p2", "server", "Pagos 2", 3, 1.5, { fanout: 1 }),
      n("af", "server", "Antifraude", 4, 0.5, { capacity: 100, processingMs: 120 }),
      n("dbf", "database", "BD fraude", 5, 0.5),
      n("dbt", "database", "BD transacciones", 4, 1.5, { capacity: 80 }),
    ],
    edges: [
      ["c", "gw"],
      ["gw", "lb"],
      ["lb", "p1"],
      ["lb", "p2"],
      ["p1", "af"],
      ["p2", "af"],
      ["p1", "dbt"],
      ["p2", "dbt"],
      ["af", "dbf"],
    ],
  },
  {
    id: "red-social",
    name: "Red social",
    category: "Sistemas reales",
    summary: "El feed junta en paralelo las publicaciones (con caché y réplicas) y los anuncios.",
    tryThis:
      "Tumba una réplica de la base de datos: el balanceador la esquiva. Ahora baja los aciertos de la caché del timeline al 20 %: la réplica que queda no da abasto.",
    traffic: 150,
    nodes: [
      n("c", "client", "Usuarios", 0, 1),
      n("cdn", "cdn", "CDN fotos", 1, 1, { hitRate: 50 }),
      n("lb", "balancer", "Balanceador", 2, 1),
      n("f1", "server", "Feed 1", 3, 0.5, { fanout: 1, capacity: 60 }),
      n("f2", "server", "Feed 2", 3, 1.5, { fanout: 1, capacity: 60 }),
      n("tl", "cache", "Caché timeline", 4, 0.5, { hitRate: 80 }),
      n("lbdb", "balancer", "Balanceador BD", 5, 0.5),
      n("r1", "database", "Réplica 1", 6, 0),
      n("r2", "database", "Réplica 2", 6, 1),
      n("ads", "server", "Anuncios", 4, 1.5, { capacity: 100 }),
      n("dbads", "database", "BD anuncios", 5, 1.5),
    ],
    edges: [
      ["c", "cdn"],
      ["cdn", "lb"],
      ["lb", "f1"],
      ["lb", "f2"],
      ["f1", "tl"],
      ["f2", "tl"],
      ["f1", "ads"],
      ["f2", "ads"],
      ["tl", "lbdb"],
      ["lbdb", "r1"],
      ["lbdb", "r2"],
      ["ads", "dbads"],
    ],
  },
  {
    id: "iot",
    name: "Sensores IoT",
    category: "Sistemas reales",
    summary:
      "Miles de sensores envían lecturas a una cola de ingesta; los workers las guardan en una base de series temporales.",
    tryThis:
      "Tumba la base de datos: los sensores siguen enviando y la cola lo guarda todo. Al revivirla, mira cuánto tarda en ponerse al día.",
    traffic: 200,
    nodes: [
      n("a", "client", "Sensores A", 0, 0),
      n("b", "client", "Sensores B", 0, 1),
      n("c", "client", "Sensores C", 0, 2),
      n("gw", "gateway", "Gateway IoT", 1, 1, { rateLimit: 300 }),
      n("q", "queue", "Cola ingesta", 2, 1, { queueMax: 5000 }),
      n("w1", "worker", "Ingesta 1", 3, 0, { capacity: 80 }),
      n("w2", "worker", "Ingesta 2", 3, 1, { capacity: 80 }),
      n("w3", "worker", "Ingesta 3", 3, 2, { capacity: 80 }),
      n("db", "database", "BD series temporales", 4, 1, { capacity: 300 }),
    ],
    edges: [
      ["a", "gw"],
      ["b", "gw"],
      ["c", "gw"],
      ["gw", "q"],
      ["q", "w1"],
      ["q", "w2"],
      ["q", "w3"],
      ["w1", "db"],
      ["w2", "db"],
      ["w3", "db"],
    ],
  },
  {
    id: "viajes",
    name: "App de viajes",
    category: "Sistemas reales",
    summary: "Pasajeros y conductores; cada viaje consulta ubicación y precio y avisa por notificación.",
    tryThis:
      "Añade 150 ms de latencia a la línea hacia Precios (está en otra región): toda petición de viaje la paga. ¿Cómo lo arreglarías?",
    traffic: 100,
    nodes: [
      n("pas", "client", "Pasajeros", 0, 0.5),
      n("con", "client", "Conductores", 0, 1.5),
      n("gw", "gateway", "API Gateway", 1, 1),
      n("lb", "balancer", "Balanceador", 2, 1),
      n("t1", "server", "Viajes 1", 3, 0.5, { fanout: 1, capacity: 80 }),
      n("t2", "server", "Viajes 2", 3, 1.5, { fanout: 1, capacity: 80 }),
      n("loc", "server", "Ubicación", 4, 0, { capacity: 150, processingMs: 20 }),
      n("geo", "cache", "Caché geo", 5, 0, { hitRate: 95 }),
      n("dbg", "database", "BD ubicaciones", 6, 0),
      n("price", "server", "Precios", 4, 1, { capacity: 150, processingMs: 40 }),
      n("dbp", "database", "BD tarifas", 5, 1),
      n("nq", "queue", "Notificaciones", 4, 2),
      n("nw", "worker", "Envío push", 5, 2, { capacity: 120 }),
    ],
    edges: [
      ["pas", "gw"],
      ["con", "gw"],
      ["gw", "lb"],
      ["lb", "t1"],
      ["lb", "t2"],
      ["t1", "loc"],
      ["t2", "loc"],
      ["t1", "price"],
      ["t2", "price"],
      ["t1", "nq"],
      ["t2", "nq"],
      ["loc", "geo"],
      ["geo", "dbg"],
      ["price", "dbp"],
      ["nq", "nw"],
    ],
  },
  {
    id: "multi-region",
    name: "Dos regiones",
    category: "Sistemas reales",
    summary: "Un balanceador global reparte entre Europa y América; América está a 80 ms.",
    tryThis:
      "Corta la línea hacia Europa: tras el chequeo, todo va a América y sube la latencia. Si América no tiene capacidad para todo, ¿qué pasa?",
    traffic: 120,
    nodes: [
      n("c", "client", "Usuarios", 0, 1.5),
      n("glb", "balancer", "Balanceador global", 1, 1.5, { healthCheckMs: 500, lbAlgorithm: 1 }),
      n("eu", "balancer", "Balanceador Europa", 2, 0.5),
      n("am", "balancer", "Balanceador América", 2, 2.5),
      n("eu1", "server", "Europa 1", 3, 0),
      n("eu2", "server", "Europa 2", 3, 1),
      n("am1", "server", "América 1", 3, 2),
      n("am2", "server", "América 2", 3, 3),
      n("dbeu", "database", "BD Europa", 4, 0.5),
      n("dbam", "database", "BD América", 4, 2.5),
    ],
    edges: [
      ["c", "glb"],
      ["glb", "eu"],
      ["glb", "am", { latencyMs: 80 }],
      ["eu", "eu1"],
      ["eu", "eu2"],
      ["am", "am1"],
      ["am", "am2"],
      ["eu1", "dbeu"],
      ["eu2", "dbeu"],
      ["am1", "dbam"],
      ["am2", "dbam"],
    ],
  },
];

export const TEMPLATE_CATEGORIES: TemplateCategory[] = ["Patrones", "Sistemas reales"];

export function templateById(id: string): Template | undefined {
  return TEMPLATES.find((t) => t.id === id);
}
