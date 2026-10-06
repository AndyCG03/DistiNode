import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../model/diagram.dart';
import '../sim/engine.dart';
import '../sim/types.dart';
import 'geometry.dart';

/// Velocidad visual de los trenes (px del lienzo por segundo).
const double _speed = 260;
const int _publishMs = 200;

/// Muestras para las gráficas: una cada medio segundo, último minuto.
const int _historyEveryMs = 500;
const int _historyLen = 120;

class Sample {
  final double throughput;
  final double p95;
  final double errors;
  const Sample(this.throughput, this.p95, this.errors);
}

/// Puente entre el diagrama y el motor. La interfaz lee instantáneas a 5 Hz (este ChangeNotifier)
/// y la capa de trenes a 60 fps (directamente del motor).
class SimRuntime extends ChangeNotifier {
  final engine = Engine(seed: 2024);
  final Map<String, Polyline> polylines = {};
  bool running = false;
  final Map<String, NodeStats?> _stats = {};
  Metrics metrics = Metrics.zero;
  List<Sample> history = const [];
  final List<Sample> _history = [];
  int _lastPublish = 0;
  int _lastSample = 0;
  bool _dirty = true;

  void sync(Map<String, NodeData> nodes, Map<String, EdgeData> edges) {
    polylines.clear();
    final simNodes = <SimNode>[
      for (final n in nodes.values) SimNode(id: n.id, kind: n.kind, params: n.params, down: n.down, slow: n.slow),
    ];
    final simEdges = <SimEdge>[];
    for (final e in edges.values) {
      final a = nodes[e.source];
      final b = nodes[e.target];
      if (a == null || b == null) continue;
      final pl = edgeLine(Offset(a.x, a.y), Offset(b.x, b.y));
      polylines[e.id] = pl;
      simEdges.add(
        SimEdge(
          id: e.id,
          source: e.source,
          target: e.target,
          travelTime: (pl.length / _speed).clamp(0.15, 1.4),
          latencyMs: e.latencyMs,
          down: e.down,
        ),
      );
    }
    engine.setGraph(SimGraph(nodes: simNodes, edges: simEdges));
    _dirty = true;
  }

  void setTraffic(double rps) => engine.setTraffic(rps);

  /// Llamado en cada fotograma.
  void tick(double dtSeconds, int nowMs) {
    if (running) {
      engine.advance(dtSeconds);
      _dirty = true;
      if (nowMs - _lastSample >= _historyEveryMs) {
        _lastSample = nowMs;
        final m = engine.metrics();
        _history.add(Sample(m.throughput, m.p95LatencyMs, m.errorRate));
        if (_history.length > _historyLen) _history.removeAt(0);
      }
    }
    if (_dirty && nowMs - _lastPublish >= _publishMs) {
      _lastPublish = nowMs;
      _dirty = false;
      _stats.clear();
      metrics = engine.metrics();
      history = List.unmodifiable(_history);
      notifyListeners();
    }
  }

  /// Instantánea estable entre publicaciones.
  NodeStats? stats(String id) => _stats.putIfAbsent(id, () => engine.nodeStats(id));
}
