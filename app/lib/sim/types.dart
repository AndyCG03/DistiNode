import 'components.dart';

class SimNode {
  final String id;
  final ComponentKind kind;
  final Params params;
  final bool down;

  /// Degradado: procesa 4 veces más lento (o añade 150 ms si no tiene capacidad).
  final bool slow;

  const SimNode({required this.id, required this.kind, required this.params, this.down = false, this.slow = false});

  SimNode copyWith({bool? down, bool? slow, Params? params}) =>
      SimNode(id: id, kind: kind, params: params ?? this.params, down: down ?? this.down, slow: slow ?? this.slow);
}

class SimEdge {
  final String id;
  final String source;
  final String target;

  /// Segundos que tarda un tren en recorrer la línea (visual). Por defecto [defaultTravel].
  final double? travelTime;

  /// Latencia de red añadida, en ms simulados. Cuenta en la latencia y en los tiempos de espera.
  final double latencyMs;

  /// Conexión cortada: lo que se envía por ella falla.
  final bool down;

  const SimEdge({
    required this.id,
    required this.source,
    required this.target,
    this.travelTime,
    this.latencyMs = 0,
    this.down = false,
  });

  SimEdge copyWith({bool? down, double? latencyMs}) => SimEdge(
    id: id,
    source: source,
    target: target,
    travelTime: travelTime,
    latencyMs: latencyMs ?? this.latencyMs,
    down: down ?? this.down,
  );
}

class SimGraph {
  final List<SimNode> nodes;
  final List<SimEdge> edges;
  SimGraph({required this.nodes, required this.edges});
}

/// request/response/error: tráfico de clientes · async: mensajes de una cola a sus workers.
enum TrainKind { request, response, error, async }

/// Un mensaje en tránsito. `progress` va de 0 (origen de la arista) a 1 (destino).
class Train {
  final int id;
  final String edgeId;
  final TrainKind kind;
  final double progress;
  const Train(this.id, this.edgeId, this.kind, this.progress);
}

/// idle: sin tráfico · ok: verde · warn: ámbar · hot: rojo · down: caído
enum Health { idle, ok, warn, hot, down }

class NodeStats {
  /// Peticiones que llegan por segundo (ventana de 1 s).
  final double arrivalRate;

  /// Peticiones rechazadas por segundo (cola llena, nodo caído, límite, sin destino).
  final double dropRate;
  final int queue;
  final double queueMax;
  final int busy;
  final int workers;

  /// Carga: llegadas / capacidad (o / límite en un API Gateway).
  final double rho;
  final Health status;

  /// Segundos seguidos con la cola casi llena. Lo usa el supervisor para las caídas por sobrecarga.
  final double overloadFor;

  const NodeStats({
    required this.arrivalRate,
    required this.dropRate,
    required this.queue,
    required this.queueMax,
    required this.busy,
    required this.workers,
    required this.rho,
    required this.status,
    required this.overloadFor,
  });

  @override
  bool operator ==(Object other) =>
      other is NodeStats &&
      other.arrivalRate == arrivalRate &&
      other.dropRate == dropRate &&
      other.queue == queue &&
      other.queueMax == queueMax &&
      other.busy == busy &&
      other.workers == workers &&
      other.rho == rho &&
      other.status == status &&
      other.overloadFor == overloadFor;

  @override
  int get hashCode => Object.hash(arrivalRate, dropRate, queue, queueMax, busy, workers, rho, status, overloadFor);
}

class Metrics {
  /// Respuestas correctas que llegan a los clientes por segundo.
  final double throughput;

  /// Media de la latencia simulada (espera + proceso + red) de las respuestas correctas, en ms.
  final double avgLatencyMs;

  /// Percentil 95 de esa latencia, en ms.
  final double p95LatencyMs;

  /// Fracción 0..1 de peticiones que terminaron en error (incluye tiempos de espera agotados).
  final double errorRate;

  /// Reintentos por segundo de los clientes.
  final double retryRate;

  /// Mensajes procesados por segundo en segundo plano (colas → workers).
  final double asyncThroughput;

  /// Mensajes esperando en todas las colas.
  final int backlog;
  final int inFlight;

  const Metrics({
    this.throughput = 0,
    this.avgLatencyMs = 0,
    this.p95LatencyMs = 0,
    this.errorRate = 0,
    this.retryRate = 0,
    this.asyncThroughput = 0,
    this.backlog = 0,
    this.inFlight = 0,
  });

  static const zero = Metrics();

  @override
  bool operator ==(Object other) =>
      other is Metrics &&
      other.throughput == throughput &&
      other.avgLatencyMs == avgLatencyMs &&
      other.p95LatencyMs == p95LatencyMs &&
      other.errorRate == errorRate &&
      other.retryRate == retryRate &&
      other.asyncThroughput == asyncThroughput &&
      other.backlog == backlog &&
      other.inFlight == inFlight;

  @override
  int get hashCode =>
      Object.hash(throughput, avgLatencyMs, p95LatencyMs, errorRate, retryRate, asyncThroughput, backlog, inFlight);
}
