/// Plantillas: sistemas listos para cargar en un lienzo vacío (o sustituyendo el actual).
/// Datos puros, generados a partir de `src/sim/templates.ts` (tool/gen_templates.py).
library;

import 'components.dart';

class TemplateNode {
  final String key;
  final ComponentKind kind;
  final String label;

  /// Columna y fila en la rejilla de la plantilla.
  final double col;
  final double row;
  final Params params;
  const TemplateNode(this.key, this.kind, this.label, this.col, this.row, this.params);
}

enum TemplateCategory {
  patrones('Patrones'),
  reales('Sistemas reales');

  final String label;
  const TemplateCategory(this.label);
}

class TemplateEdge {
  final String from;
  final String to;
  final double? latencyMs;
  const TemplateEdge(this.from, this.to, {this.latencyMs});
}

class Template {
  final String id;
  final String name;
  final TemplateCategory category;

  /// Una frase: qué es.
  final String summary;

  /// Qué probar una vez cargada.
  final String tryThis;
  final double traffic;
  final List<TemplateNode> nodes;
  final List<TemplateEdge> edges;
  const Template({
    required this.id,
    required this.name,
    required this.category,
    required this.summary,
    required this.tryThis,
    required this.traffic,
    required this.nodes,
    required this.edges,
  });
}

const gridX = 250.0;
const gridY = 110.0;

TemplateNode _n(String key, ComponentKind kind, String label, num col, num row, [Params params = const {}]) =>
    TemplateNode(key, kind, label, col.toDouble(), row.toDouble(), params);

final List<Template> templates = [
  Template(
    id: 'basico',
    name: 'Lo esencial',
    category: TemplateCategory.patrones,
    summary: 'Cliente → Balanceador → Servidor → Base de datos.',
    tryThis: 'Sube el tráfico a 70 pet/s: el servidor se pone rojo. Añade un segundo servidor detrás del balanceador.',
    traffic: 20,
    nodes: [
      _n('c', ComponentKind.client, 'Cliente', 0, 0),
      _n('lb', ComponentKind.balancer, 'Balanceador', 1, 0),
      _n('s1', ComponentKind.server, 'Servidor 1', 2, 0),
      _n('db', ComponentKind.database, 'Base de datos 1', 3, 0),
    ],
    edges: [
      TemplateEdge('c', 'lb'),
      TemplateEdge('lb', 's1'),
      TemplateEdge('s1', 'db'),
    ],
  ),
  Template(
    id: 'alta-disponibilidad',
    name: 'Alta disponibilidad',
    category: TemplateCategory.patrones,
    summary: 'Tres servidores tras un balanceador, con caché delante de la base de datos.',
    tryThis: 'Activa «Caos» y mira cómo el balanceador esquiva servidores caídos. ¿Qué pasa cuando cae la caché o la base de datos? Ese es un punto único de fallo.',
    traffic: 100,
    nodes: [
      _n('c', ComponentKind.client, 'Cliente', 0, 1),
      _n('lb', ComponentKind.balancer, 'Balanceador', 1, 1),
      _n('s1', ComponentKind.server, 'Servidor 1', 2, 0),
      _n('s2', ComponentKind.server, 'Servidor 2', 2, 1),
      _n('s3', ComponentKind.server, 'Servidor 3', 2, 2),
      _n('cache', ComponentKind.cache, 'Caché 1', 3, 1),
      _n('db', ComponentKind.database, 'Base de datos 1', 4, 1),
    ],
    edges: [
      TemplateEdge('c', 'lb'),
      TemplateEdge('lb', 's1'),
      TemplateEdge('lb', 's2'),
      TemplateEdge('lb', 's3'),
      TemplateEdge('s1', 'cache'),
      TemplateEdge('s2', 'cache'),
      TemplateEdge('s3', 'cache'),
      TemplateEdge('cache', 'db'),
    ],
  ),
  Template(
    id: 'web-a-escala',
    name: 'Web a gran escala',
    category: TemplateCategory.patrones,
    summary: 'CDN, API Gateway, granja de servidores, caché y réplicas de la base de datos.',
    tryThis: 'Pon el tráfico a 200 pet/s. Baja los aciertos de la CDN a 0 % y mira dónde aparece el cuello de botella. Luego baja el límite del gateway para protegerlo.',
    traffic: 180,
    nodes: [
      _n('c', ComponentKind.client, 'Cliente', 0, 1),
      _n('cdn', ComponentKind.cdn, 'CDN', 1, 1),
      _n('gw', ComponentKind.gateway, 'API Gateway', 2, 1, {ParamKey.rateLimit: 200}),
      _n('lb', ComponentKind.balancer, 'Balanceador web', 3, 1),
      _n('s1', ComponentKind.server, 'Servidor 1', 4, 0),
      _n('s2', ComponentKind.server, 'Servidor 2', 4, 1),
      _n('s3', ComponentKind.server, 'Servidor 3', 4, 2),
      _n('cache', ComponentKind.cache, 'Caché 1', 5, 1),
      _n('lbdb', ComponentKind.balancer, 'Balanceador BD', 6, 1),
      _n('db1', ComponentKind.database, 'Réplica 1', 7, 0.5),
      _n('db2', ComponentKind.database, 'Réplica 2', 7, 1.5),
    ],
    edges: [
      TemplateEdge('c', 'cdn'),
      TemplateEdge('cdn', 'gw'),
      TemplateEdge('gw', 'lb'),
      TemplateEdge('lb', 's1'),
      TemplateEdge('lb', 's2'),
      TemplateEdge('lb', 's3'),
      TemplateEdge('s1', 'cache'),
      TemplateEdge('s2', 'cache'),
      TemplateEdge('s3', 'cache'),
      TemplateEdge('cache', 'lbdb'),
      TemplateEdge('lbdb', 'db1'),
      TemplateEdge('lbdb', 'db2'),
    ],
  ),
  Template(
    id: 'asincrono',
    name: 'Trabajo en segundo plano',
    category: TemplateCategory.patrones,
    summary: 'La API deja el trabajo en una cola y responde; tres workers lo procesan a su ritmo.',
    tryThis: 'Tumba los tres workers: la cola crece, pero los clientes siguen recibiendo respuesta. Revívelos y mira cómo se vacía la cola.',
    traffic: 60,
    nodes: [
      _n('c', ComponentKind.client, 'Cliente', 0, 1),
      _n('gw', ComponentKind.gateway, 'API Gateway', 1, 1),
      _n('api', ComponentKind.server, 'Servidor API', 2, 1, {ParamKey.capacity: 100}),
      _n('q', ComponentKind.queue, 'Cola de mensajes 1', 3, 1),
      _n('w1', ComponentKind.worker, 'Worker 1', 4, 0),
      _n('w2', ComponentKind.worker, 'Worker 2', 4, 1),
      _n('w3', ComponentKind.worker, 'Worker 3', 4, 2),
      _n('db', ComponentKind.database, 'Base de datos 1', 5, 1),
    ],
    edges: [
      TemplateEdge('c', 'gw'),
      TemplateEdge('gw', 'api'),
      TemplateEdge('api', 'q'),
      TemplateEdge('q', 'w1'),
      TemplateEdge('q', 'w2'),
      TemplateEdge('q', 'w3'),
      TemplateEdge('w1', 'db'),
      TemplateEdge('w2', 'db'),
      TemplateEdge('w3', 'db'),
    ],
  ),
  Template(
    id: 'microservicios',
    name: 'Microservicios',
    category: TemplateCategory.patrones,
    summary: 'Un BFF consulta en paralelo a usuarios, catálogo y pedidos; cada servicio tiene sus datos.',
    tryThis: 'La latencia es la del servicio más lento. Degrada el Servicio Catálogo y mira la p95. Tumba Usuarios: todo falla, porque el BFF necesita a los tres.',
    traffic: 60,
    nodes: [
      _n('c', ComponentKind.client, 'Cliente', 0, 1.5),
      _n('gw', ComponentKind.gateway, 'API Gateway', 1, 1.5),
      _n('lb', ComponentKind.balancer, 'Balanceador', 2, 1.5),
      _n('bff1', ComponentKind.server, 'BFF 1', 3, 1, {ParamKey.fanout: 1, ParamKey.capacity: 80}),
      _n('bff2', ComponentKind.server, 'BFF 2', 3, 2, {ParamKey.fanout: 1, ParamKey.capacity: 80}),
      _n('users', ComponentKind.server, 'Servicio Usuarios', 4, 0, {ParamKey.capacity: 150, ParamKey.processingMs: 30}),
      _n('catalog', ComponentKind.server, 'Servicio Catálogo', 4, 1.5, {ParamKey.capacity: 150, ParamKey.processingMs: 40}),
      _n('orders', ComponentKind.server, 'Servicio Pedidos', 4, 3, {ParamKey.capacity: 150, ParamKey.processingMs: 50}),
      _n('dbu', ComponentKind.database, 'BD Usuarios', 5, 0),
      _n('cachec', ComponentKind.cache, 'Caché Catálogo', 5, 1.5, {ParamKey.hitRate: 85}),
      _n('dbc', ComponentKind.database, 'BD Catálogo', 6, 1.5),
      _n('qo', ComponentKind.queue, 'Cola Pedidos', 5, 3),
      _n('wpay', ComponentKind.worker, 'Worker Pagos', 6, 3, {ParamKey.capacity: 80, ParamKey.processingMs: 100}),
      _n('dbo', ComponentKind.database, 'BD Pedidos', 7, 3),
    ],
    edges: [
      TemplateEdge('c', 'gw'),
      TemplateEdge('gw', 'lb'),
      TemplateEdge('lb', 'bff1'),
      TemplateEdge('lb', 'bff2'),
      TemplateEdge('bff1', 'users'),
      TemplateEdge('bff1', 'catalog'),
      TemplateEdge('bff1', 'orders'),
      TemplateEdge('bff2', 'users'),
      TemplateEdge('bff2', 'catalog'),
      TemplateEdge('bff2', 'orders'),
      TemplateEdge('users', 'dbu'),
      TemplateEdge('catalog', 'cachec'),
      TemplateEdge('cachec', 'dbc'),
      TemplateEdge('orders', 'qo'),
      TemplateEdge('qo', 'wpay'),
      TemplateEdge('wpay', 'dbo'),
    ],
  ),
  Template(
    id: 'tormenta-de-reintentos',
    name: 'Tormenta de reintentos',
    category: TemplateCategory.patrones,
    summary: 'Clientes impacientes que reintentan 3 veces contra un servidor al límite.',
    tryThis: 'Sube el tráfico a 55 pet/s: los reintentos multiplican la carga y el sistema colapsa. Prueba con 0 reintentos, o pon un API Gateway con límite delante.',
    traffic: 45,
    nodes: [
      _n('c', ComponentKind.client, 'Cliente', 0, 0, {ParamKey.timeoutMs: 400, ParamKey.retries: 3}),
      _n('s', ComponentKind.server, 'Servidor 1', 1, 0, {ParamKey.capacity: 50, ParamKey.queueMax: 100}),
      _n('db', ComponentKind.database, 'Base de datos 1', 2, 0),
    ],
    edges: [
      TemplateEdge('c', 's'),
      TemplateEdge('s', 'db'),
    ],
  ),
  Template(
    id: 'tienda-online',
    name: 'Tienda online',
    category: TemplateCategory.reales,
    summary: 'Catálogo con CDN y caché; cada compra deja el pedido en una cola que procesan los workers de pagos.',
    tryThis: 'Black Friday: sube a 200 pet/s. ¿Quién se satura primero? Luego tumba un worker de pagos: los clientes no lo notan, la cola sí.',
    traffic: 120,
    nodes: [
      _n('c', ComponentKind.client, 'Compradores', 0, 1.5),
      _n('cdn', ComponentKind.cdn, 'CDN imágenes', 1, 1.5, {ParamKey.hitRate: 60}),
      _n('gw', ComponentKind.gateway, 'API Gateway', 2, 1.5, {ParamKey.rateLimit: 250}),
      _n('lb', ComponentKind.balancer, 'Balanceador', 3, 1.5),
      _n('w1', ComponentKind.server, 'Web 1', 4, 0.5, {ParamKey.fanout: 1}),
      _n('w2', ComponentKind.server, 'Web 2', 4, 1.5, {ParamKey.fanout: 1}),
      _n('w3', ComponentKind.server, 'Web 3', 4, 2.5, {ParamKey.fanout: 1}),
      _n('cache', ComponentKind.cache, 'Caché productos', 5, 0.5),
      _n('dbp', ComponentKind.database, 'BD productos', 6, 0.5),
      _n('q', ComponentKind.queue, 'Cola pedidos', 5, 2.5),
      _n('pay1', ComponentKind.worker, 'Pagos 1', 6, 2),
      _n('pay2', ComponentKind.worker, 'Pagos 2', 6, 3),
      _n('dbo', ComponentKind.database, 'BD pedidos', 7, 2.5),
    ],
    edges: [
      TemplateEdge('c', 'cdn'),
      TemplateEdge('cdn', 'gw'),
      TemplateEdge('gw', 'lb'),
      TemplateEdge('lb', 'w1'),
      TemplateEdge('lb', 'w2'),
      TemplateEdge('lb', 'w3'),
      TemplateEdge('w1', 'cache'),
      TemplateEdge('w2', 'cache'),
      TemplateEdge('w3', 'cache'),
      TemplateEdge('w1', 'q'),
      TemplateEdge('w2', 'q'),
      TemplateEdge('w3', 'q'),
      TemplateEdge('cache', 'dbp'),
      TemplateEdge('q', 'pay1'),
      TemplateEdge('q', 'pay2'),
      TemplateEdge('pay1', 'dbo'),
      TemplateEdge('pay2', 'dbo'),
    ],
  ),
  Template(
    id: 'streaming-video',
    name: 'Streaming de vídeo',
    category: TemplateCategory.reales,
    summary: 'Casi todo el vídeo sale de la CDN; el origen solo atiende lo que falta y registra lo que se ve.',
    tryThis: 'Baja los aciertos de la CDN al 50 %: el origen, pensado para una pequeña parte del tráfico, se hunde. Así se nota cuánto trabajo hace una CDN.',
    traffic: 200,
    nodes: [
      _n('c', ComponentKind.client, 'Espectadores', 0, 1),
      _n('cdn', ComponentKind.cdn, 'CDN de vídeo', 1, 1, {ParamKey.hitRate: 95}),
      _n('gw', ComponentKind.gateway, 'API Gateway', 2, 1),
      _n('lb', ComponentKind.balancer, 'Balanceador', 3, 1),
      _n('p1', ComponentKind.server, 'Reproducción 1', 4, 0.5, {ParamKey.fanout: 1}),
      _n('p2', ComponentKind.server, 'Reproducción 2', 4, 1.5, {ParamKey.fanout: 1}),
      _n('meta', ComponentKind.cache, 'Caché metadatos', 5, 0.5, {ParamKey.hitRate: 90}),
      _n('dbc', ComponentKind.database, 'BD catálogo', 6, 0.5),
      _n('ev', ComponentKind.queue, 'Eventos de visionado', 5, 1.5),
      _n('rec', ComponentKind.worker, 'Recomendaciones', 6, 1.5),
      _n('dba', ComponentKind.database, 'BD analítica', 7, 1.5),
    ],
    edges: [
      TemplateEdge('c', 'cdn'),
      TemplateEdge('cdn', 'gw'),
      TemplateEdge('gw', 'lb'),
      TemplateEdge('lb', 'p1'),
      TemplateEdge('lb', 'p2'),
      TemplateEdge('p1', 'meta'),
      TemplateEdge('p2', 'meta'),
      TemplateEdge('p1', 'ev'),
      TemplateEdge('p2', 'ev'),
      TemplateEdge('meta', 'dbc'),
      TemplateEdge('ev', 'rec'),
      TemplateEdge('rec', 'dba'),
    ],
  ),
  Template(
    id: 'mensajeria',
    name: 'Mensajería instantánea',
    category: TemplateCategory.reales,
    summary: 'Servidores de chat que guardan cada mensaje en una cola y consultan la presencia en una caché.',
    tryThis: 'Tumba la base de datos de mensajes 15 s: no se pierde ninguno, la cola los guarda y los reentrega al volver. Compara con quitar la cola.',
    traffic: 150,
    nodes: [
      _n('c', ComponentKind.client, 'Usuarios', 0, 1),
      _n('lb', ComponentKind.balancer, 'Balanceador', 1, 1, {ParamKey.lbAlgorithm: 1}),
      _n('s1', ComponentKind.server, 'Chat 1', 2, 0, {ParamKey.fanout: 1, ParamKey.capacity: 80}),
      _n('s2', ComponentKind.server, 'Chat 2', 2, 1, {ParamKey.fanout: 1, ParamKey.capacity: 80}),
      _n('s3', ComponentKind.server, 'Chat 3', 2, 2, {ParamKey.fanout: 1, ParamKey.capacity: 80}),
      _n('pres', ComponentKind.cache, 'Presencia', 3, 0, {ParamKey.hitRate: 100}),
      _n('q', ComponentKind.queue, 'Cola mensajes', 3, 1.5, {ParamKey.queueMax: 3000}),
      _n('d1', ComponentKind.worker, 'Entrega 1', 4, 1, {ParamKey.capacity: 100}),
      _n('d2', ComponentKind.worker, 'Entrega 2', 4, 2, {ParamKey.capacity: 100}),
      _n('db', ComponentKind.database, 'BD mensajes', 5, 1.5, {ParamKey.capacity: 250}),
    ],
    edges: [
      TemplateEdge('c', 'lb'),
      TemplateEdge('lb', 's1'),
      TemplateEdge('lb', 's2'),
      TemplateEdge('lb', 's3'),
      TemplateEdge('s1', 'pres'),
      TemplateEdge('s2', 'pres'),
      TemplateEdge('s3', 'pres'),
      TemplateEdge('s1', 'q'),
      TemplateEdge('s2', 'q'),
      TemplateEdge('s3', 'q'),
      TemplateEdge('q', 'd1'),
      TemplateEdge('q', 'd2'),
      TemplateEdge('d1', 'db'),
      TemplateEdge('d2', 'db'),
    ],
  ),
  Template(
    id: 'pagos',
    name: 'Pasarela de pagos',
    category: TemplateCategory.reales,
    summary: 'Cada pago consulta a la vez al antifraude y a la base de transacciones; el cliente reintenta una vez.',
    tryThis: 'Degrada el servicio antifraude: todos los pagos esperan por él. Baja el tiempo de espera del cliente a 300 ms y mira cómo los pagos lentos se convierten en errores.',
    traffic: 60,
    nodes: [
      _n('c', ComponentKind.client, 'Tiendas', 0, 1, {ParamKey.timeoutMs: 3000, ParamKey.retries: 1}),
      _n('gw', ComponentKind.gateway, 'API Gateway', 1, 1, {ParamKey.rateLimit: 100}),
      _n('lb', ComponentKind.balancer, 'Balanceador', 2, 1),
      _n('p1', ComponentKind.server, 'Pagos 1', 3, 0.5, {ParamKey.fanout: 1}),
      _n('p2', ComponentKind.server, 'Pagos 2', 3, 1.5, {ParamKey.fanout: 1}),
      _n('af', ComponentKind.server, 'Antifraude', 4, 0.5, {ParamKey.capacity: 100, ParamKey.processingMs: 120}),
      _n('dbf', ComponentKind.database, 'BD fraude', 5, 0.5),
      _n('dbt', ComponentKind.database, 'BD transacciones', 4, 1.5, {ParamKey.capacity: 80}),
    ],
    edges: [
      TemplateEdge('c', 'gw'),
      TemplateEdge('gw', 'lb'),
      TemplateEdge('lb', 'p1'),
      TemplateEdge('lb', 'p2'),
      TemplateEdge('p1', 'af'),
      TemplateEdge('p2', 'af'),
      TemplateEdge('p1', 'dbt'),
      TemplateEdge('p2', 'dbt'),
      TemplateEdge('af', 'dbf'),
    ],
  ),
  Template(
    id: 'red-social',
    name: 'Red social',
    category: TemplateCategory.reales,
    summary: 'El feed junta en paralelo las publicaciones (con caché y réplicas) y los anuncios.',
    tryThis: 'Tumba una réplica de la base de datos: el balanceador la esquiva. Ahora baja los aciertos de la caché del timeline al 20 %: la réplica que queda no da abasto.',
    traffic: 150,
    nodes: [
      _n('c', ComponentKind.client, 'Usuarios', 0, 1),
      _n('cdn', ComponentKind.cdn, 'CDN fotos', 1, 1, {ParamKey.hitRate: 50}),
      _n('lb', ComponentKind.balancer, 'Balanceador', 2, 1),
      _n('f1', ComponentKind.server, 'Feed 1', 3, 0.5, {ParamKey.fanout: 1, ParamKey.capacity: 60}),
      _n('f2', ComponentKind.server, 'Feed 2', 3, 1.5, {ParamKey.fanout: 1, ParamKey.capacity: 60}),
      _n('tl', ComponentKind.cache, 'Caché timeline', 4, 0.5, {ParamKey.hitRate: 80}),
      _n('lbdb', ComponentKind.balancer, 'Balanceador BD', 5, 0.5),
      _n('r1', ComponentKind.database, 'Réplica 1', 6, 0),
      _n('r2', ComponentKind.database, 'Réplica 2', 6, 1),
      _n('ads', ComponentKind.server, 'Anuncios', 4, 1.5, {ParamKey.capacity: 100}),
      _n('dbads', ComponentKind.database, 'BD anuncios', 5, 1.5),
    ],
    edges: [
      TemplateEdge('c', 'cdn'),
      TemplateEdge('cdn', 'lb'),
      TemplateEdge('lb', 'f1'),
      TemplateEdge('lb', 'f2'),
      TemplateEdge('f1', 'tl'),
      TemplateEdge('f2', 'tl'),
      TemplateEdge('f1', 'ads'),
      TemplateEdge('f2', 'ads'),
      TemplateEdge('tl', 'lbdb'),
      TemplateEdge('lbdb', 'r1'),
      TemplateEdge('lbdb', 'r2'),
      TemplateEdge('ads', 'dbads'),
    ],
  ),
  Template(
    id: 'iot',
    name: 'Sensores IoT',
    category: TemplateCategory.reales,
    summary: 'Miles de sensores envían lecturas a una cola de ingesta; los workers las guardan en una base de series temporales.',
    tryThis: 'Tumba la base de datos: los sensores siguen enviando y la cola lo guarda todo. Al revivirla, mira cuánto tarda en ponerse al día.',
    traffic: 200,
    nodes: [
      _n('a', ComponentKind.client, 'Sensores A', 0, 0),
      _n('b', ComponentKind.client, 'Sensores B', 0, 1),
      _n('c', ComponentKind.client, 'Sensores C', 0, 2),
      _n('gw', ComponentKind.gateway, 'Gateway IoT', 1, 1, {ParamKey.rateLimit: 300}),
      _n('q', ComponentKind.queue, 'Cola ingesta', 2, 1, {ParamKey.queueMax: 5000}),
      _n('w1', ComponentKind.worker, 'Ingesta 1', 3, 0, {ParamKey.capacity: 80}),
      _n('w2', ComponentKind.worker, 'Ingesta 2', 3, 1, {ParamKey.capacity: 80}),
      _n('w3', ComponentKind.worker, 'Ingesta 3', 3, 2, {ParamKey.capacity: 80}),
      _n('db', ComponentKind.database, 'BD series temporales', 4, 1, {ParamKey.capacity: 300}),
    ],
    edges: [
      TemplateEdge('a', 'gw'),
      TemplateEdge('b', 'gw'),
      TemplateEdge('c', 'gw'),
      TemplateEdge('gw', 'q'),
      TemplateEdge('q', 'w1'),
      TemplateEdge('q', 'w2'),
      TemplateEdge('q', 'w3'),
      TemplateEdge('w1', 'db'),
      TemplateEdge('w2', 'db'),
      TemplateEdge('w3', 'db'),
    ],
  ),
  Template(
    id: 'viajes',
    name: 'App de viajes',
    category: TemplateCategory.reales,
    summary: 'Pasajeros y conductores; cada viaje consulta ubicación y precio y avisa por notificación.',
    tryThis: 'Añade 150 ms de latencia a la línea hacia Precios (está en otra región): toda petición de viaje la paga. ¿Cómo lo arreglarías?',
    traffic: 100,
    nodes: [
      _n('pas', ComponentKind.client, 'Pasajeros', 0, 0.5),
      _n('con', ComponentKind.client, 'Conductores', 0, 1.5),
      _n('gw', ComponentKind.gateway, 'API Gateway', 1, 1),
      _n('lb', ComponentKind.balancer, 'Balanceador', 2, 1),
      _n('t1', ComponentKind.server, 'Viajes 1', 3, 0.5, {ParamKey.fanout: 1, ParamKey.capacity: 80}),
      _n('t2', ComponentKind.server, 'Viajes 2', 3, 1.5, {ParamKey.fanout: 1, ParamKey.capacity: 80}),
      _n('loc', ComponentKind.server, 'Ubicación', 4, 0, {ParamKey.capacity: 150, ParamKey.processingMs: 20}),
      _n('geo', ComponentKind.cache, 'Caché geo', 5, 0, {ParamKey.hitRate: 95}),
      _n('dbg', ComponentKind.database, 'BD ubicaciones', 6, 0),
      _n('price', ComponentKind.server, 'Precios', 4, 1, {ParamKey.capacity: 150, ParamKey.processingMs: 40}),
      _n('dbp', ComponentKind.database, 'BD tarifas', 5, 1),
      _n('nq', ComponentKind.queue, 'Notificaciones', 4, 2),
      _n('nw', ComponentKind.worker, 'Envío push', 5, 2, {ParamKey.capacity: 120}),
    ],
    edges: [
      TemplateEdge('pas', 'gw'),
      TemplateEdge('con', 'gw'),
      TemplateEdge('gw', 'lb'),
      TemplateEdge('lb', 't1'),
      TemplateEdge('lb', 't2'),
      TemplateEdge('t1', 'loc'),
      TemplateEdge('t2', 'loc'),
      TemplateEdge('t1', 'price'),
      TemplateEdge('t2', 'price'),
      TemplateEdge('t1', 'nq'),
      TemplateEdge('t2', 'nq'),
      TemplateEdge('loc', 'geo'),
      TemplateEdge('geo', 'dbg'),
      TemplateEdge('price', 'dbp'),
      TemplateEdge('nq', 'nw'),
    ],
  ),
  Template(
    id: 'multi-region',
    name: 'Dos regiones',
    category: TemplateCategory.reales,
    summary: 'Un balanceador global reparte entre Europa y América; América está a 80 ms.',
    tryThis: 'Corta la línea hacia Europa: tras el chequeo, todo va a América y sube la latencia. Si América no tiene capacidad para todo, ¿qué pasa?',
    traffic: 120,
    nodes: [
      _n('c', ComponentKind.client, 'Usuarios', 0, 1.5),
      _n('glb', ComponentKind.balancer, 'Balanceador global', 1, 1.5, {ParamKey.healthCheckMs: 500, ParamKey.lbAlgorithm: 1}),
      _n('eu', ComponentKind.balancer, 'Balanceador Europa', 2, 0.5),
      _n('am', ComponentKind.balancer, 'Balanceador América', 2, 2.5),
      _n('eu1', ComponentKind.server, 'Europa 1', 3, 0),
      _n('eu2', ComponentKind.server, 'Europa 2', 3, 1),
      _n('am1', ComponentKind.server, 'América 1', 3, 2),
      _n('am2', ComponentKind.server, 'América 2', 3, 3),
      _n('dbeu', ComponentKind.database, 'BD Europa', 4, 0.5),
      _n('dbam', ComponentKind.database, 'BD América', 4, 2.5),
    ],
    edges: [
      TemplateEdge('c', 'glb'),
      TemplateEdge('glb', 'eu'),
      TemplateEdge('glb', 'am', latencyMs: 80),
      TemplateEdge('eu', 'eu1'),
      TemplateEdge('eu', 'eu2'),
      TemplateEdge('am', 'am1'),
      TemplateEdge('am', 'am2'),
      TemplateEdge('eu1', 'dbeu'),
      TemplateEdge('eu2', 'dbeu'),
      TemplateEdge('am1', 'dbam'),
      TemplateEdge('am2', 'dbam'),
    ],
  ),
];

const List<TemplateCategory> templateCategories = TemplateCategory.values;

Template? templateById(String id) {
  for (final t in templates) {
    if (t.id == id) return t;
  }
  return null;
}
