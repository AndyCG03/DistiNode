import 'dart:math' as math;

import '../sim/components.dart';
import '../sim/templates.dart';

enum DownReason { manual, caos, sobrecarga }

/// Un nodo del diagrama tal y como lo ve la interfaz.
class NodeData {
  final String id;
  final ComponentKind kind;
  final String label;
  final double x;
  final double y;
  final Params params;
  final bool down;

  /// Si se cayó solo (caos o sobrecarga): cuándo vuelve a arrancar (ms desde epoch).
  final int? downUntil;
  final DownReason? downReason;

  /// Degradado: procesa más lento.
  final bool slow;
  final int? slowUntil;

  const NodeData({
    required this.id,
    required this.kind,
    required this.label,
    required this.x,
    required this.y,
    required this.params,
    this.down = false,
    this.downUntil,
    this.downReason,
    this.slow = false,
    this.slowUntil,
  });

  static const _keep = Object();

  NodeData copyWith({
    String? label,
    double? x,
    double? y,
    Params? params,
    bool? down,
    Object? downUntil = _keep,
    Object? downReason = _keep,
    bool? slow,
    Object? slowUntil = _keep,
  }) => NodeData(
    id: id,
    kind: kind,
    label: label ?? this.label,
    x: x ?? this.x,
    y: y ?? this.y,
    params: params ?? this.params,
    down: down ?? this.down,
    downUntil: identical(downUntil, _keep) ? this.downUntil : downUntil as int?,
    downReason: identical(downReason, _keep) ? this.downReason : downReason as DownReason?,
    slow: slow ?? this.slow,
    slowUntil: identical(slowUntil, _keep) ? this.slowUntil : slowUntil as int?,
  );
}

class EdgeData {
  final String id;
  final String source;
  final String target;

  /// Latencia de red añadida (ms).
  final double latencyMs;

  /// Conexión cortada.
  final bool down;
  final int? downUntil;

  const EdgeData({
    required this.id,
    required this.source,
    required this.target,
    this.latencyMs = 0,
    this.down = false,
    this.downUntil,
  });

  static const _keep = Object();

  EdgeData copyWith({double? latencyMs, bool? down, Object? downUntil = _keep}) => EdgeData(
    id: id,
    source: source,
    target: target,
    latencyMs: latencyMs ?? this.latencyMs,
    down: down ?? this.down,
    downUntil: identical(downUntil, _keep) ? this.downUntil : downUntil as int?,
  );
}

class SimShared {
  final bool running;

  /// Peticiones por segundo totales, 1–200.
  final double traffic;

  /// Modo caos: caídas, cortes y degradaciones al azar.
  final bool chaos;

  /// Un nodo saturado demasiado tiempo se cae y se reinicia solo.
  final bool autoCrash;

  /// Segundos que tarda en volver un nodo caído solo.
  final double restartSec;

  const SimShared({
    this.running = false,
    this.traffic = 20,
    this.chaos = false,
    this.autoCrash = false,
    this.restartSec = 8,
  });

  SimShared copyWith({bool? running, double? traffic, bool? chaos, bool? autoCrash, double? restartSec}) => SimShared(
    running: running ?? this.running,
    traffic: traffic ?? this.traffic,
    chaos: chaos ?? this.chaos,
    autoCrash: autoCrash ?? this.autoCrash,
    restartSec: restartSec ?? this.restartSec,
  );
}

final _rand = math.Random.secure();
const _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

String newId() => List.generate(12, (_) => _alphabet[_rand.nextInt(_alphabet.length)]).join();

double clampTraffic(double t) => t.roundToDouble().clamp(1, 200).toDouble();

NodeData makeNode(ComponentKind kind, double x, double y, Iterable<String> existingLabels, [String? label]) => NodeData(
  id: newId(),
  kind: kind,
  label: label ?? nextLabel(kind, existingLabels),
  x: x.roundToDouble(),
  y: y.roundToDouble(),
  params: {...specOf(kind).defaults},
);

/// Nodos y aristas de una plantilla, con ids nuevos y posiciones en píxeles.
({List<NodeData> nodes, List<EdgeData> edges}) buildTemplate(Template t) {
  final ids = <String, String>{};
  final nodes = [
    for (final n in t.nodes)
      () {
        final node = makeNode(
          n.kind,
          n.col * gridX,
          n.row * gridY,
          const [],
          n.label,
        ).copyWith(params: {...specOf(n.kind).defaults, ...n.params});
        ids[n.key] = node.id;
        return node;
      }(),
  ];
  final edges = [
    for (final e in t.edges)
      EdgeData(id: newId(), source: ids[e.from]!, target: ids[e.to]!, latencyMs: e.latencyMs ?? 0),
  ];
  return (nodes: nodes, edges: edges);
}
