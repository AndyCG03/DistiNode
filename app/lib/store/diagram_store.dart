import 'package:flutter/foundation.dart';

import '../model/diagram.dart';
import '../sim/components.dart';
import '../sim/templates.dart';

class Notice {
  final String text;

  /// true: aviso del sistema (caos, sobrecarga) → punto rojo.
  final bool alert;
  const Notice(this.text, {this.alert = true});
}

/// Estado de un proyecto abierto y todas las escrituras al diagrama
/// (equivalente a `DiagramActions` + `LocalStore` de la web).
class DiagramStore extends ChangeNotifier {
  String name;
  final DateTime createdAt;
  final Map<String, NodeData> nodes = {};
  final Map<String, EdgeData> edges = {};
  SimShared sim;

  /// Cambia cuando cambian nodos o conexiones (el motor se resincroniza).
  int graphVersion = 0;

  /// Cambia con cualquier modificación que haya que guardar.
  int saveVersion = 0;

  final _noticeListeners = <void Function(Notice)>{};

  DiagramStore({
    required this.name,
    required this.createdAt,
    Iterable<NodeData> nodes = const [],
    Iterable<EdgeData> edges = const [],
    this.sim = const SimShared(),
  }) {
    for (final n in nodes) {
      this.nodes[n.id] = n;
    }
    for (final e in edges) {
      this.edges[e.id] = e;
    }
  }

  bool get isEmpty => nodes.isEmpty;

  void _changed({bool graph = true, bool save = true}) {
    if (graph) graphVersion++;
    if (save) saveVersion++;
    notifyListeners();
  }

  // ── Avisos ──────────────────────────────────────────────
  void Function() onNotice(void Function(Notice) fn) {
    _noticeListeners.add(fn);
    return () => _noticeListeners.remove(fn);
  }

  /// Aviso del sistema (caos, sobrecarga).
  void announce(String text) {
    for (final fn in [..._noticeListeners]) {
      fn(Notice(text));
    }
  }

  /// Confirmación breve de una acción propia (la web se lo mostraba a los demás de la sala).
  void notify(String text) {
    for (final fn in [..._noticeListeners]) {
      fn(Notice(text, alert: false));
    }
  }

  // ── Acciones ────────────────────────────────────────────
  void rename(String value) {
    final v = value.trim();
    if (v.isEmpty || v == name) return;
    name = v.length > 60 ? v.substring(0, 60) : v;
    _changed(graph: false);
  }

  NodeData addNode(ComponentKind kind, double x, double y) {
    final node = makeNode(kind, x, y, nodes.values.map((n) => n.label));
    nodes[node.id] = node;
    _changed();
    return node;
  }

  void moveNodes(Map<String, Offset2> positions) {
    var any = false;
    positions.forEach((id, p) {
      final n = nodes[id];
      if (n == null) return;
      nodes[id] = n.copyWith(x: p.x.roundToDouble(), y: p.y.roundToDouble());
      any = true;
    });
    if (any) _changed();
  }

  void removeElements(Iterable<String> nodeIds, Iterable<String> edgeIds) {
    final gone = nodeIds.toSet();
    final dropEdges = edgeIds.toSet();
    if (gone.isEmpty && dropEdges.isEmpty) return;
    nodes.removeWhere((id, _) => gone.contains(id));
    edges.removeWhere((id, e) => dropEdges.contains(id) || gone.contains(e.source) || gone.contains(e.target));
    _changed();
  }

  bool connect(String source, String target) {
    if (source == target || !nodes.containsKey(source) || !nodes.containsKey(target)) return false;
    if (edges.values.any((e) => e.source == source && e.target == target)) return false;
    final id = newId();
    edges[id] = EdgeData(id: id, source: source, target: target);
    _changed();
    return true;
  }

  void setParam(String id, ParamKey key, double value) {
    final n = nodes[id];
    if (n == null || n.params[key] == value) return;
    nodes[id] = n.copyWith(params: {...n.params, key: value});
    _changed();
  }

  void setLabel(String id, String label) {
    final n = nodes[id];
    if (n == null) return;
    nodes[id] = n.copyWith(label: label.length > 40 ? label.substring(0, 40) : label);
    _changed();
  }

  void setNodeState(
    String id, {
    bool? down,
    Object? downUntil = _keep,
    Object? downReason = _keep,
    bool? slow,
    Object? slowUntil = _keep,
  }) {
    final n = nodes[id];
    if (n == null) return;
    nodes[id] = n.copyWith(
      down: down,
      downUntil: identical(downUntil, _keep) ? n.downUntil : downUntil,
      downReason: identical(downReason, _keep) ? n.downReason : downReason,
      slow: slow,
      slowUntil: identical(slowUntil, _keep) ? n.slowUntil : slowUntil,
    );
    _changed();
  }

  void setEdge(String id, {double? latencyMs, bool? down, Object? downUntil = _keep}) {
    final e = edges[id];
    if (e == null) return;
    edges[id] = e.copyWith(
      latencyMs: latencyMs,
      down: down,
      downUntil: identical(downUntil, _keep) ? e.downUntil : downUntil,
    );
    _changed();
  }

  void setRunning(bool running) {
    if (sim.running == running) return;
    sim = sim.copyWith(running: running);
    _changed(graph: false, save: false);
  }

  void setTraffic(double traffic) {
    final t = clampTraffic(traffic);
    if (t == sim.traffic) return;
    sim = sim.copyWith(traffic: t);
    _changed(graph: false);
  }

  void setSimOptions({bool? chaos, bool? autoCrash, double? restartSec}) {
    sim = sim.copyWith(chaos: chaos, autoCrash: autoCrash, restartSec: restartSec);
    _changed(graph: false);
  }

  /// Sustituye el diagrama por una plantilla.
  void loadTemplate(Template t) {
    final built = buildTemplate(t);
    replaceDiagram(built.nodes, built.edges, traffic: t.traffic);
  }

  /// Sustituye todo el diagrama (importar un proyecto).
  void replaceDiagram(
    List<NodeData> nodeList,
    List<EdgeData> edgeList, {
    double? traffic,
    bool? chaos,
    bool? autoCrash,
    double? restartSec,
  }) {
    nodes
      ..clear()
      ..addEntries(nodeList.map((n) => MapEntry(n.id, n)));
    edges
      ..clear()
      ..addEntries(edgeList.map((e) => MapEntry(e.id, e)));
    sim = sim.copyWith(traffic: traffic, chaos: chaos, autoCrash: autoCrash, restartSec: restartSec);
    _changed();
  }

  static const _keep = Object();
}

/// Punto del lienzo (sin depender de dart:ui en el modelo).
class Offset2 {
  final double x;
  final double y;
  const Offset2(this.x, this.y);
}
