import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../sim/components.dart';
import '../store/diagram_store.dart';
import '../theme/tokens.dart';
import 'diagram_paint.dart';
import 'editor_controller.dart';
import 'geometry.dart';
import 'sim_runtime.dart';

/// Arrastrar un componente desde la paleta.
class PaletteDrag {
  final ComponentKind kind;
  const PaletteDrag(this.kind);
}

enum _Mode { none, pan, moveNodes, connect, marquee, pinch }

/// Lienzo: pinta el diagrama y los trenes y gestiona ratón, teclado táctil y trackpad.
class DiagramCanvas extends StatefulWidget {
  final DiagramStore store;
  final SimRuntime runtime;
  final EditorController controller;
  final bool narrow;
  final VoidCallback onInteract;
  final ValueNotifier<int> clock;

  const DiagramCanvas({
    super.key,
    required this.store,
    required this.runtime,
    required this.controller,
    required this.narrow,
    required this.onInteract,
    required this.clock,
  });

  @override
  State<DiagramCanvas> createState() => _DiagramCanvasState();
}

class _DiagramCanvasState extends State<DiagramCanvas> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  final _text = TextCache();
  Duration _last = Duration.zero;
  bool? _wasDark;

  final Map<int, Offset> _pointers = {};
  _Mode _mode = _Mode.none;
  Offset _downPos = Offset.zero;
  Offset _lastPos = Offset.zero;
  bool _moved = false;
  bool _shiftAtDown = false;
  String? _downNode;
  String? _downEdge;
  bool _wasSelectedAtDown = false;
  Map<String, Offset> _startPositions = {};
  Offset _dragStartWorld = Offset.zero;
  // pellizco
  double _pinchStartDist = 1;
  double _pinchStartZoom = 1;
  Offset _pinchWorld = Offset.zero;
  // trackpad
  double _panZoomStartZoom = 1;

  EditorController get ctl => widget.controller;
  DiagramStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      widget.runtime.tick(dt, DateTime.now().millisecondsSinceEpoch);
      _frame.value++;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ── Pruebas de impacto ───────────────────────────────────
  double get _handleRadius => widget.narrow ? 18 : 11;

  (String, HandleSide)? _hitHandle(Offset world) {
    final r = _handleRadius / ctl.zoom.clamp(0.6, 2);
    final nodes = store.nodes.values.toList().reversed;
    for (final n in nodes) {
      if ((world - Offset(n.x + nodeW, n.y + nodeH / 2)).distance <= r) return (n.id, HandleSide.output);
      if ((world - Offset(n.x, n.y + nodeH / 2)).distance <= r) return (n.id, HandleSide.input);
    }
    return null;
  }

  String? _hitNode(Offset world) {
    // Primero los seleccionados (se pintan encima).
    final sel = ctl.selection.nodes;
    for (final n in store.nodes.values.toList().reversed) {
      if (sel.contains(n.id) && Rect.fromLTWH(n.x, n.y, nodeW, nodeH).contains(world)) return n.id;
    }
    for (final n in store.nodes.values.toList().reversed) {
      if (Rect.fromLTWH(n.x, n.y, nodeW, nodeH).contains(world)) return n.id;
    }
    return null;
  }

  String? _hitEdge(Offset world) {
    final tol = 9 / ctl.zoom.clamp(0.5, 2) + (widget.narrow ? 6 : 0);
    String? best;
    var bestD = double.infinity;
    for (final e in store.edges.values) {
      final pl = widget.runtime.polylines[e.id];
      if (pl == null) continue;
      final d = pl.distanceTo(world);
      if (d <= tol && d < bestD) {
        best = e.id;
        bestD = d;
      }
    }
    return best;
  }

  /// Destino de una conexión: el nodo bajo el cursor, o el asa más cercana a menos de 36 px.
  String? _connectTarget(Offset world, PendingConnection conn) {
    final over = _hitNode(world);
    if (over != null && over != conn.nodeId) return over;
    String? best;
    var bestD = 36.0 / ctl.zoom.clamp(0.5, 2);
    for (final n in store.nodes.values) {
      if (n.id == conn.nodeId) continue;
      final h = conn.side == HandleSide.output ? Offset(n.x, n.y + nodeH / 2) : Offset(n.x + nodeW, n.y + nodeH / 2);
      final d = (world - h).distance;
      if (d < bestD) {
        bestD = d;
        best = n.id;
      }
    }
    return best;
  }

  // ── Puntero ──────────────────────────────────────────────
  void _onDown(PointerDownEvent e) {
    widget.onInteract();
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      _startPinch();
      return;
    }
    if (_pointers.length > 2) return;
    if (e.kind == PointerDeviceKind.mouse && e.buttons & kSecondaryMouseButton != 0) return;

    _downPos = _lastPos = e.localPosition;
    _moved = false;
    _shiftAtDown = HardwareKeyboard.instance.isShiftPressed;
    _downNode = null;
    _downEdge = null;
    final world = ctl.toWorld(e.localPosition);

    final handle = _hitHandle(world);
    if (handle != null) {
      _mode = _Mode.connect;
      ctl.connection = PendingConnection(handle.$1, handle.$2, world);
      ctl.touch();
      return;
    }
    final node = _hitNode(world);
    if (node != null) {
      _downNode = node;
      final sel = ctl.selection;
      _wasSelectedAtDown = sel.nodes.contains(node);
      if (!sel.nodes.contains(node)) {
        ctl.select(_shiftAtDown ? Selection({...sel.nodes, node}, sel.edges) : Selection({node}));
      }
      _mode = _Mode.moveNodes;
      _dragStartWorld = world;
      _startPositions = {
        for (final id in ctl.selection.nodes)
          if (store.nodes[id] != null) id: Offset(store.nodes[id]!.x, store.nodes[id]!.y),
      };
      return;
    }
    final edge = _hitEdge(world);
    if (edge != null) {
      _downEdge = edge;
      _mode = _Mode.pan;
      return;
    }
    _mode = _shiftAtDown ? _Mode.marquee : _Mode.pan;
  }

  void _onMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_mode == _Mode.pinch) return _updatePinch();
    final delta = e.localPosition - _lastPos;
    _lastPos = e.localPosition;
    if (!_moved && (e.localPosition - _downPos).distance > (e.kind == PointerDeviceKind.touch ? 8 : 3)) _moved = true;
    if (!_moved) return;
    final world = ctl.toWorld(e.localPosition);
    switch (_mode) {
      case _Mode.pan:
        ctl.panning = true;
        ctl.panBy(delta);
      case _Mode.moveNodes:
        ctl.draggingNode = true;
        final d = world - _dragStartWorld;
        store.moveNodes({
          for (final entry in _startPositions.entries) entry.key: Offset2(entry.value.dx + d.dx, entry.value.dy + d.dy),
        });
      case _Mode.connect:
        final conn = ctl.connection!;
        conn.cursor = world;
        conn.hoverTarget = _connectTarget(world, conn);
        ctl.touch();
      case _Mode.marquee:
        ctl.marquee = Rect.fromPoints(_downPos, e.localPosition);
        ctl.touch();
      case _Mode.none:
      case _Mode.pinch:
        break;
    }
  }

  void _onUp(PointerEvent e) {
    final wasPinch = _mode == _Mode.pinch;
    _pointers.remove(e.pointer);
    if (wasPinch) {
      if (_pointers.isEmpty) _mode = _Mode.none;
      return;
    }
    if (_pointers.isNotEmpty) return;
    final cancelled = e is PointerCancelEvent;
    switch (_mode) {
      case _Mode.connect:
        final conn = ctl.connection!;
        final target = cancelled ? null : (conn.hoverTarget ?? _connectTarget(ctl.toWorld(e.localPosition), conn));
        if (target != null) {
          if (conn.side == HandleSide.output) {
            store.connect(conn.nodeId, target);
          } else {
            store.connect(target, conn.nodeId);
          }
        }
        ctl.connection = null;
        ctl.touch();
      case _Mode.moveNodes:
        if (!_moved && _shiftAtDown && _downNode != null && _wasSelectedAtDown) {
          // Mayús + clic sobre un seleccionado: lo quita de la selección.
          final s = ctl.selection;
          ctl.select(Selection({...s.nodes}..remove(_downNode), s.edges));
        } else if (!_moved && !_shiftAtDown && _downNode != null) {
          ctl.select(Selection({_downNode!}));
        }
      case _Mode.pan:
        if (!_moved && !cancelled) {
          if (_downEdge != null) {
            final s = ctl.selection;
            ctl.select(_shiftAtDown ? Selection(s.nodes, {...s.edges, _downEdge!}) : Selection(const {}, {_downEdge!}));
          } else if (!_shiftAtDown) {
            ctl.clearSelection();
          }
        }
      case _Mode.marquee:
        final m = ctl.marquee;
        if (m != null) {
          final a = ctl.toWorld(m.topLeft);
          final b = ctl.toWorld(m.bottomRight);
          final r = Rect.fromPoints(a, b);
          final inside = store.nodes.values
              .where((n) => r.contains(Offset(n.x, n.y)) && r.contains(Offset(n.x + nodeW, n.y + nodeH)))
              .map((n) => n.id);
          ctl.select(Selection({...ctl.selection.nodes, ...inside}, ctl.selection.edges));
        }
        ctl.marquee = null;
        ctl.touch();
      case _Mode.none:
      case _Mode.pinch:
        break;
    }
    _mode = _Mode.none;
    ctl.panning = false;
    ctl.draggingNode = false;
    ctl.touch();
  }

  void _startPinch() {
    if (_mode == _Mode.connect) ctl.connection = null;
    ctl.marquee = null;
    _mode = _Mode.pinch;
    final pts = _pointers.values.toList();
    _pinchStartDist = math.max(1, (pts[0] - pts[1]).distance);
    _pinchStartZoom = ctl.zoom;
    _pinchWorld = ctl.toWorld((pts[0] + pts[1]) / 2);
  }

  void _updatePinch() {
    final pts = _pointers.values.take(2).toList();
    if (pts.length < 2) return;
    final focal = (pts[0] + pts[1]) / 2;
    final z = (_pinchStartZoom * (pts[0] - pts[1]).distance / _pinchStartDist).clamp(
      EditorController.minZoom,
      EditorController.maxZoom,
    );
    ctl.zoom = z;
    ctl.tx = focal.dx - _pinchWorld.dx * z;
    ctl.ty = focal.dy - _pinchWorld.dy * z;
    ctl.touch();
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final factor = math.exp(-e.scrollDelta.dy * 0.0022);
      ctl.zoomAt(e.localPosition, ctl.zoom * factor);
    } else if (e is PointerScaleEvent) {
      ctl.zoomAt(e.localPosition, ctl.zoom * e.scale);
    }
  }

  void _onHover(PointerHoverEvent e) {
    final world = ctl.toWorld(e.localPosition);
    final handle = _hitHandle(world);
    final node = handle == null ? _hitNode(world) : null;
    final edge = handle == null && node == null ? _hitEdge(world) : null;
    if (handle != ctl.hoverHandle || node != ctl.hoverNode || edge != ctl.hoverEdge) {
      ctl.hoverHandle = handle;
      ctl.hoverNode = node;
      ctl.hoverEdge = edge;
      ctl.touch();
    }
  }

  MouseCursor get _cursor {
    if (ctl.panning || ctl.draggingNode) return SystemMouseCursors.grabbing;
    if (ctl.connection != null || ctl.hoverHandle != null) return SystemMouseCursors.precise;
    if (ctl.hoverNode != null) return SystemMouseCursors.grab;
    if (ctl.hoverEdge != null) return SystemMouseCursors.click;
    return SystemMouseCursors.basic;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_wasDark != c.dark) {
      _text.clear();
      _wasDark = c.dark;
    }
    final reduced = MediaQuery.of(context).disableAnimations;
    return LayoutBuilder(
      builder: (context, box) {
        ctl.setSize(box.biggest, narrow: widget.narrow);
        return DragTarget<PaletteDrag>(
          onAcceptWithDetails: (d) {
            final rb = context.findRenderObject() as RenderBox;
            final local = rb.globalToLocal(d.offset);
            final world = ctl.toWorld(local);
            final node = store.addNode(d.data.kind, world.dx - nodeW / 2, world.dy - nodeH / 2);
            ctl.select(Selection({node.id}));
          },
          builder: (context, candidate, rejected) => ListenableBuilder(
            listenable: ctl,
            builder: (context, _) => MouseRegion(
              cursor: _cursor,
              onExit: (_) {
                if (ctl.hoverNode != null || ctl.hoverHandle != null || ctl.hoverEdge != null) {
                  ctl.hoverNode = null;
                  ctl.hoverHandle = null;
                  ctl.hoverEdge = null;
                  ctl.touch();
                }
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onDown,
                onPointerMove: _onMove,
                onPointerUp: _onUp,
                onPointerCancel: _onUp,
                onPointerHover: _onHover,
                onPointerSignal: _onSignal,
                onPointerPanZoomStart: (_) => _panZoomStartZoom = ctl.zoom,
                onPointerPanZoomUpdate: (e) {
                  ctl.panBy(e.panDelta);
                  if (e.scale != 1) ctl.zoomAt(e.localPosition, _panZoomStartZoom * e.scale);
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _ScenePainter(
                          this,
                          c,
                          Listenable.merge([store, widget.runtime, ctl, widget.clock]),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _TrainsPainter(this, c, reduced, _frame)),
                      ),
                    ),
                    if (candidate.isNotEmpty)
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: c.verde.withValues(alpha: 0.5), width: 2),
                            color: c.verde.withValues(alpha: 0.04),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScenePainter extends CustomPainter {
  final _DiagramCanvasState s;
  final DistiColors c;
  _ScenePainter(this.s, this.c, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final ctl = s.ctl;
    canvas.clipRect(Offset.zero & size);
    paintDots(canvas, size, ctl.tx, ctl.ty, ctl.zoom, c.punto);
    canvas.save();
    canvas.translate(ctl.tx, ctl.ty);
    canvas.scale(ctl.zoom);
    DiagramScene(
      store: s.store,
      lines: s.widget.runtime.polylines,
      stats: s.widget.runtime.stats,
      c: c,
      text: s._text,
      selection: ctl.selection,
      hoverNode: ctl.hoverNode,
      hoverHandle: ctl.hoverHandle,
      connection: ctl.connection,
      largeHandles: s.widget.narrow,
      nowMs: DateTime.now().millisecondsSinceEpoch,
    ).paint(canvas);
    canvas.restore();
    final m = ctl.marquee;
    if (m != null) {
      canvas.drawRect(m, Paint()..color = c.verde.withValues(alpha: 0.1));
      canvas.drawRect(
        m,
        Paint()
          ..color = c.verde
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}

class _TrainsPainter extends CustomPainter {
  final _DiagramCanvasState s;
  final DistiColors c;
  final bool reduced;
  _TrainsPainter(this.s, this.c, this.reduced, Listenable frame) : super(repaint: frame);

  @override
  void paint(Canvas canvas, Size size) {
    final ctl = s.ctl;
    canvas.clipRect(Offset.zero & size);
    paintTrains(
      canvas,
      s.widget.runtime.engine.trains(),
      s.widget.runtime.polylines,
      c,
      ctl.tx,
      ctl.ty,
      ctl.zoom,
      reduced: reduced,
    );
  }

  @override
  bool shouldRepaint(_TrainsPainter old) => true;
}
