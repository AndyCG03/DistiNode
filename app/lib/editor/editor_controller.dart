import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../store/diagram_store.dart';
import 'geometry.dart';

class Selection {
  final Set<String> nodes;
  final Set<String> edges;
  const Selection([this.nodes = const {}, this.edges = const {}]);
  bool get isEmpty => nodes.isEmpty && edges.isEmpty;
  String? get singleNode => nodes.length == 1 && edges.isEmpty ? nodes.first : null;
  String? get singleEdge => edges.length == 1 && nodes.isEmpty ? edges.first : null;
}

enum HandleSide { input, output }

/// Arrastre de una conexión nueva desde un asa.
class PendingConnection {
  final String nodeId;
  final HandleSide side;
  Offset cursor; // mundo
  String? hoverTarget;
  PendingConnection(this.nodeId, this.side, this.cursor);
}

/// Estado de la vista del lienzo: encuadre, selección, hover y arrastres en curso.
class EditorController extends ChangeNotifier {
  final DiagramStore store;
  EditorController(this.store);

  double tx = 0;
  double ty = 0;
  double zoom = 1;
  Size size = Size.zero;
  static const minZoom = 0.25;
  static const maxZoom = 2.0;

  Selection selection = const Selection();
  String? hoverNode;
  (String, HandleSide)? hoverHandle;
  String? hoverEdge;
  PendingConnection? connection;
  Rect? marquee; // pantalla
  bool panning = false;
  bool draggingNode = false;
  bool _fitted = false;

  Offset toWorld(Offset screen) => Offset((screen.dx - tx) / zoom, (screen.dy - ty) / zoom);
  Offset toScreen(Offset world) => Offset(world.dx * zoom + tx, world.dy * zoom + ty);

  void touch() => notifyListeners();

  void setSize(Size s, {required bool narrow}) {
    if (s == size) return;
    final first = size == Size.zero;
    size = s;
    if (first || !_fitted) {
      if (store.nodes.isNotEmpty) {
        fitView(narrow: narrow, notify: false);
        _fitted = true;
      } else {
        tx = s.width / 2 - 300;
        ty = s.height / 2 - 120;
      }
    }
  }

  void select(Selection s) {
    selection = Selection({...s.nodes}, {...s.edges});
    notifyListeners();
  }

  void clearSelection() => select(const Selection());

  /// Quita de la selección lo que ya no existe.
  void prune() {
    final n = selection.nodes.where(store.nodes.containsKey).toSet();
    final e = selection.edges.where(store.edges.containsKey).toSet();
    if (n.length != selection.nodes.length || e.length != selection.edges.length) {
      selection = Selection(n, e);
    }
  }

  void panBy(Offset d) {
    tx += d.dx;
    ty += d.dy;
    notifyListeners();
  }

  /// Zoom manteniendo fijo el punto `focal` (pantalla).
  void zoomAt(Offset focal, double newZoom) {
    final z = newZoom.clamp(minZoom, maxZoom);
    final w = toWorld(focal);
    zoom = z;
    tx = focal.dx - w.dx * z;
    ty = focal.dy - w.dy * z;
    notifyListeners();
  }

  void zoomBy(double factor) => zoomAt(size.center(Offset.zero), zoom * factor);

  /// Encuadra todo el diagrama (como `fitView` de React Flow con `fitOptions`).
  void fitView({required bool narrow, bool notify = true}) {
    if (store.nodes.isEmpty || size.isEmpty) return;
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (final n in store.nodes.values) {
      l = math.min(l, n.x);
      t = math.min(t, n.y);
      r = math.max(r, n.x + nodeW);
      b = math.max(b, n.y + nodeH);
    }
    final padding = narrow ? 0.15 : 0.25;
    final lo = narrow ? 0.6 : minZoom;
    final hi = narrow ? 1.0 : 1.1;
    final w = r - l;
    final h = b - t;
    final zx = size.width / (w * (1 + padding));
    final zy = size.height / (h * (1 + padding));
    zoom = math.min(zx, zy).clamp(lo, hi);
    tx = size.width / 2 - (l + w / 2) * zoom;
    ty = size.height / 2 - (t + h / 2) * zoom;
    _fitted = true;
    if (notify) notifyListeners();
  }

  /// Centro de la vista en coordenadas del lienzo.
  Offset get viewCenter => toWorld(size.center(Offset.zero));
}

/// El hueco libre más cercano a (x, y): en espiral por filas y columnas de estación.
Offset freeSpot(double x, double y, Iterable<Offset> taken) {
  const gapX = nodeW + 40;
  const gapY = nodeH + 30;
  bool free(double px, double py) => taken.every((n) => (n.dx - px).abs() >= gapX || (n.dy - py).abs() >= gapY);
  for (var r = 0; r < 12; r++) {
    for (var dy = -r; dy <= r; dy++) {
      for (var dx = -r; dx <= r; dx++) {
        if (math.max(dx.abs(), dy.abs()) != r) continue;
        final px = x + dx * (gapX / 2);
        final py = y + dy * gapY;
        if (free(px, py)) return Offset(px, py);
      }
    }
  }
  return Offset(x, y);
}
