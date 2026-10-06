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

export interface Template {
  id: string;
  name: string;
  /** Una frase: qué es. */
  summary: string;
  /** Qué probar una vez cargada. */
  tryThis: string;
  traffic: number;
  nodes: TemplateNode[];
  edges: [from: string, to: string][];
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
];

export function templateById(id: string): Template | undefined {
  return TEMPLATES.find((t) => t.id === id);
}
