/// Registro de componentes. Única fuente de verdad sobre qué piezas existen:
/// la paleta, el panel de propiedades, la guía y el motor leen de aquí.
/// Port fiel de `src/sim/components.ts`.
library;

enum ComponentKind { client, cdn, gateway, balancer, server, worker, cache, queue, database }

enum ParamKey { capacity, processingMs, queueMax, hitRate, healthCheckMs, lbAlgorithm, fanout, rateLimit, timeoutMs, retries }

typedef Params = Map<ParamKey, double>;

class ParamOption {
  final double value;
  final String label;
  const ParamOption(this.value, this.label);
}

class ParamSpec {
  final ParamKey key;
  final String label;
  final String unit;
  final double min;
  final double max;
  final double step;
  final String help;

  /// Valores con nombre: se muestran como selector en lugar de deslizador.
  final List<ParamOption>? options;

  /// Tope del deslizador; el campo numérico permite llegar a `max`.
  final double? sliderMax;

  const ParamSpec({
    required this.key,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.help,
    this.options,
    this.sliderMax,
  });
}

enum ComponentGroup {
  trafico('Tráfico'),
  computo('Cómputo'),
  datos('Datos');

  final String label;
  const ComponentGroup(this.label);
}

class ComponentDocs {
  /// Qué es, en dos o tres frases.
  final String what;

  /// Cuándo ponerlo en un diseño.
  final String when;

  /// Cómo se comporta en la simulación.
  final String model;

  /// Tecnologías reales que cumplen ese papel.
  final List<String> realWorld;

  const ComponentDocs({required this.what, required this.when, required this.model, required this.realWorld});
}

class ComponentSpec {
  final ComponentKind kind;
  final String name;
  final ComponentGroup group;

  /// Una frase: qué hace. Se muestra como tooltip en la paleta.
  final String tooltip;
  final Params defaults;
  final List<ParamSpec> params;
  final ComponentDocs docs;

  const ComponentSpec({
    required this.kind,
    required this.name,
    required this.group,
    required this.tooltip,
    required this.defaults,
    required this.params,
    required this.docs,
  });
}

ParamSpec _capacity(int def) => ParamSpec(
  key: ParamKey.capacity,
  label: 'Capacidad',
  unit: 'pet/s',
  min: 1,
  max: 2000,
  step: 1,
  sliderMax: 300,
  help: 'Peticiones por segundo que puede atender sin formar cola (por defecto $def).',
);

ParamSpec _processing(int def) => ParamSpec(
  key: ParamKey.processingMs,
  label: 'Tiempo de proceso',
  unit: 'ms',
  min: 1,
  max: 5000,
  step: 1,
  sliderMax: 500,
  help: 'Lo que tarda en atender una petición sin esperar (por defecto $def ms).',
);

ParamSpec _queue(int def) => ParamSpec(
  key: ParamKey.queueMax,
  label: 'Tamaño de la cola',
  unit: 'pet',
  min: 0,
  max: 5000,
  step: 1,
  sliderMax: 200,
  help: 'Peticiones que pueden esperar; con la cola llena, las nuevas fallan (por defecto $def).',
);

ParamSpec _hitRate(int def, String who) => ParamSpec(
  key: ParamKey.hitRate,
  label: 'Aciertos',
  unit: '%',
  min: 0,
  max: 100,
  step: 1,
  help: 'Porcentaje de peticiones que $who responde sin preguntar a nadie (por defecto $def %).',
);

final Map<ComponentKind, ComponentSpec> components = {
  ComponentKind.client: const ComponentSpec(
    kind: ComponentKind.client,
    name: 'Cliente',
    group: ComponentGroup.trafico,
    tooltip: 'Genera las peticiones de los usuarios: el tráfico sale de aquí.',
    defaults: {ParamKey.timeoutMs: 2000, ParamKey.retries: 0},
    params: [
      ParamSpec(
        key: ParamKey.timeoutMs,
        label: 'Tiempo de espera',
        unit: 'ms',
        min: 0,
        max: 30000,
        step: 50,
        sliderMax: 5000,
        help: 'Si la respuesta tarda más, el cliente se rinde y la cuenta como error. 0 = espera siempre.',
      ),
      ParamSpec(
        key: ParamKey.retries,
        label: 'Reintentos',
        unit: '',
        min: 0,
        max: 5,
        step: 1,
        help: 'Cuántas veces repite una petición fallida. Ayuda con fallos sueltos… y empeora una saturación.',
      ),
    ],
    docs: ComponentDocs(
      what: 'Representa a los usuarios (navegadores, apps móviles) que hacen peticiones al sistema.',
      when: 'Siempre: es el origen del tráfico. Si hay varios clientes, el tráfico total se reparte entre ellos.',
      model:
          'Emite peticiones a ritmo regular. Espera la respuesta hasta su tiempo de espera; si falla o se agota, puede reintentar con espera exponencial (100 ms, 200 ms, 400 ms…).',
      realWorld: ['Navegador web', 'App móvil', 'Otro servicio que nos llama'],
    ),
  ),
  ComponentKind.cdn: ComponentSpec(
    kind: ComponentKind.cdn,
    name: 'CDN',
    group: ComponentGroup.trafico,
    tooltip: 'Copias del contenido cerca del usuario: responde al instante lo que ya conoce.',
    defaults: const {ParamKey.hitRate: 60},
    params: [_hitRate(60, 'la CDN')],
    docs: const ComponentDocs(
      what: 'Red de servidores repartidos por el mundo que guardan copias de imágenes, scripts y páginas.',
      when: 'Delante de todo, cuando gran parte de las peticiones piden lo mismo (contenido estático o poco cambiante).',
      model: 'Con probabilidad «Aciertos» responde ella misma en 2 ms; si no, pasa la petición hacia dentro.',
      realWorld: ['Cloudflare', 'Akamai', 'Amazon CloudFront', 'Fastly'],
    ),
  ),
  ComponentKind.gateway: const ComponentSpec(
    kind: ComponentKind.gateway,
    name: 'API Gateway',
    group: ComponentGroup.trafico,
    tooltip: 'Puerta de entrada única: limita cuántas peticiones por segundo deja pasar.',
    defaults: {ParamKey.rateLimit: 150},
    params: [
      ParamSpec(
        key: ParamKey.rateLimit,
        label: 'Límite',
        unit: 'pet/s',
        min: 1,
        max: 5000,
        step: 1,
        sliderMax: 300,
        help: 'Por encima de este ritmo rechaza peticiones (HTTP 429) para proteger lo que hay detrás.',
      ),
    ],
    docs: ComponentDocs(
      what: 'Punto de entrada único de una API: autentica, enruta y limita el ritmo de las peticiones.',
      when: 'Para proteger los servicios internos de picos de tráfico o de clientes abusivos.',
      model:
          'Cubo de fichas: se rellena a «Límite» fichas por segundo (máximo un segundo acumulado). Sin ficha, la petición se rechaza al momento.',
      realWorld: ['Kong', 'NGINX', 'AWS API Gateway', 'Traefik'],
    ),
  ),
  ComponentKind.balancer: const ComponentSpec(
    kind: ComponentKind.balancer,
    name: 'Balanceador',
    group: ComponentGroup.trafico,
    tooltip: 'Reparte las peticiones entre los servidores que siguen sanos.',
    defaults: {ParamKey.healthCheckMs: 1000, ParamKey.lbAlgorithm: 0},
    params: [
      ParamSpec(
        key: ParamKey.lbAlgorithm,
        label: 'Algoritmo',
        unit: '',
        min: 0,
        max: 1,
        step: 1,
        help: 'Por turnos reparte a partes iguales; «menos conexiones» manda al que tiene menos trabajo pendiente.',
        options: [ParamOption(0, 'Por turnos (round-robin)'), ParamOption(1, 'Menos conexiones')],
      ),
      ParamSpec(
        key: ParamKey.healthCheckMs,
        label: 'Chequeo de salud cada',
        unit: 'ms',
        min: 100,
        max: 10000,
        step: 100,
        sliderMax: 5000,
        help: 'Cada cuánto comprueba si sus destinos responden. Más corto = esquiva antes los caídos.',
      ),
    ],
    docs: ComponentDocs(
      what: 'Reparte el tráfico entre varias copias de un servicio para sumar capacidad y tolerar caídas.',
      when: 'En cuanto un servidor no basta, o cuando no puedes permitirte que la caída de uno tumbe el sistema.',
      model:
          'Cada «Chequeo de salud» marca como sanos los destinos encendidos y alcanzables. Entre chequeos no se entera de una caída: esas peticiones fallan. «Menos conexiones» cuenta las peticiones enviadas sin respuesta.',
      realWorld: ['HAProxy', 'NGINX', 'AWS ELB', 'Envoy'],
    ),
  ),
  ComponentKind.server: ComponentSpec(
    kind: ComponentKind.server,
    name: 'Servidor',
    group: ComponentGroup.computo,
    tooltip: 'Procesa peticiones; si llegan más de las que aguanta, se forma una cola.',
    defaults: const {ParamKey.capacity: 50, ParamKey.processingMs: 80, ParamKey.queueMax: 40, ParamKey.fanout: 0},
    params: [
      _capacity(50),
      _processing(80),
      _queue(40),
      const ParamSpec(
        key: ParamKey.fanout,
        label: 'Llama a lo que tiene detrás',
        unit: '',
        min: 0,
        max: 1,
        step: 1,
        help: '«Uno por turno» pregunta a un solo destino; «a todos en paralelo» espera a todos (microservicios).',
        options: [ParamOption(0, 'A uno, por turnos'), ParamOption(1, 'A todos, en paralelo')],
      ),
    ],
    docs: const ComponentDocs(
      what: 'Una instancia de tu aplicación: ejecuta la lógica de cada petición.',
      when: 'Siempre que haya trabajo que hacer. Para escalar, pon varios detrás de un balanceador.',
      model:
          'Atiende varias peticiones a la vez (capacidad × tiempo de proceso). Si están todos ocupados, la petición espera en cola; con la cola llena, falla. Si tiene destinos detrás, los llama tras procesar. En modo «a todos», espera la respuesta más lenta y falla si falla cualquiera.',
      realWorld: ['Node.js', 'Spring Boot', 'Django', 'Un contenedor en Kubernetes'],
    ),
  ),
  ComponentKind.worker: ComponentSpec(
    kind: ComponentKind.worker,
    name: 'Worker',
    group: ComponentGroup.computo,
    tooltip: 'Procesa en segundo plano los mensajes que le entrega una cola.',
    defaults: const {ParamKey.capacity: 30, ParamKey.processingMs: 150, ParamKey.queueMax: 10},
    params: [_capacity(30), _processing(150), _queue(10)],
    docs: const ComponentDocs(
      what: 'Proceso que consume tareas de una cola: enviar correos, generar facturas, redimensionar imágenes…',
      when: 'Detrás de una cola, para trabajo que no hace falta terminar antes de responder al usuario.',
      model:
          'Igual que un servidor. La cola solo le entrega tantos mensajes como puede procesar a la vez; si cae, los mensajes vuelven a la cola.',
      realWorld: ['Celery', 'Sidekiq', 'Consumidores de Kafka', 'AWS Lambda'],
    ),
  ),
  ComponentKind.cache: ComponentSpec(
    kind: ComponentKind.cache,
    name: 'Caché',
    group: ComponentGroup.datos,
    tooltip: 'Guarda respuestas recientes para no tener que preguntar a la base de datos.',
    defaults: const {ParamKey.hitRate: 70},
    params: [_hitRate(70, 'la caché')],
    docs: const ComponentDocs(
      what: 'Memoria muy rápida con resultados ya calculados o leídos.',
      when: 'Delante de una base de datos o un servicio lento, si muchas lecturas se repiten.',
      model: 'Con probabilidad «Aciertos» responde en 1 ms; si no, pregunta a lo que tiene detrás.',
      realWorld: ['Redis', 'Memcached', 'Varnish'],
    ),
  ),
  ComponentKind.queue: const ComponentSpec(
    kind: ComponentKind.queue,
    name: 'Cola de mensajes',
    group: ComponentGroup.datos,
    tooltip: 'Acepta el trabajo al momento y lo reparte a los workers a su ritmo.',
    defaults: {ParamKey.queueMax: 500},
    params: [
      ParamSpec(
        key: ParamKey.queueMax,
        label: 'Capacidad',
        unit: 'msj',
        min: 1,
        max: 100000,
        step: 1,
        sliderMax: 2000,
        help: 'Mensajes que puede guardar. Llena, rechaza los nuevos.',
      ),
    ],
    docs: ComponentDocs(
      what: 'Intermediario asíncrono: quien envía no espera a que el trabajo se haga.',
      when: 'Para absorber picos, desacoplar servicios y hacer en segundo plano lo que no urge.',
      model:
          'Confirma cada mensaje en cuanto lo guarda (el cliente recibe respuesta rápida) y lo entrega a sus consumidores según su capacidad libre. Si un consumidor falla, el mensaje vuelve a la cola (al menos una vez).',
      realWorld: ['RabbitMQ', 'Apache Kafka', 'Amazon SQS', 'Redis Streams'],
    ),
  ),
  ComponentKind.database: ComponentSpec(
    kind: ComponentKind.database,
    name: 'Base de datos',
    group: ComponentGroup.datos,
    tooltip: 'Guarda los datos; es la pieza más difícil de multiplicar.',
    defaults: const {ParamKey.capacity: 120, ParamKey.processingMs: 25, ParamKey.queueMax: 100},
    params: [_capacity(120), _processing(25), _queue(100)],
    docs: const ComponentDocs(
      what: 'Donde viven los datos de forma duradera.',
      when:
          'Casi siempre. Es difícil de escalar: protégela con cachés, colas y réplicas de lectura (otra BD detrás de un balanceador).',
      model: 'Igual que un servidor: capacidad, tiempo de proceso y cola. Suele ser el cuello de botella final.',
      realWorld: ['PostgreSQL', 'MySQL', 'MongoDB', 'Cassandra'],
    ),
  ),
};

const List<ComponentKind> componentOrder = ComponentKind.values;

const List<ComponentGroup> groups = ComponentGroup.values;

ComponentSpec specOf(ComponentKind k) => components[k]!;

/// Componentes con capacidad, trabajadores y cola propia.
bool hasCapacity(ComponentKind k) => k == ComponentKind.server || k == ComponentKind.worker || k == ComponentKind.database;

ComponentKind? kindFromName(Object? v) {
  if (v is! String) return null;
  for (final k in ComponentKind.values) {
    if (k.name == v) return k;
  }
  return null;
}

ParamKey? paramKeyFromName(String v) {
  for (final k in ParamKey.values) {
    if (k.name == v) return k;
  }
  return null;
}

/// "Servidor 2": el primer número libre para ese tipo.
String nextLabel(ComponentKind kind, Iterable<String> existing) {
  final base = specOf(kind).name;
  final taken = existing.toSet();
  if (kind == ComponentKind.client ||
      kind == ComponentKind.balancer ||
      kind == ComponentKind.cdn ||
      kind == ComponentKind.gateway) {
    if (!taken.contains(base)) return base;
  }
  for (var n = 1; ; n++) {
    final label = '$base $n';
    if (!taken.contains(label)) return label;
  }
}

double paramValue(ComponentKind kind, Params? params, ParamKey key) =>
    params?[key] ?? specOf(kind).defaults[key] ?? 0;
