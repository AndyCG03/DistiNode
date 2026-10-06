import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../sim/components.dart';

/// Iconos de los componentes (viewBox 24×24, trazo 2), los mismos de `icons.tsx`.
/// Se dibujan con Canvas para poder usarlos en el lienzo y en la imagen exportada.
abstract class _Op {
  const _Op();
  void addTo(Path p);
}

class _P extends _Op {
  final String d;
  const _P(this.d);
  @override
  void addTo(Path p) => p.addPath(parseSvgPathData(d), Offset.zero);
}

class _R extends _Op {
  final double x, y, w, h, r;
  const _R(this.x, this.y, this.w, this.h, this.r);
  @override
  void addTo(Path p) => p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)));
}

class _C extends _Op {
  final double cx, cy, r;
  const _C(this.cx, this.cy, this.r);
  @override
  void addTo(Path p) => p.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
}

class _E extends _Op {
  final double cx, cy, rx, ry;
  const _E(this.cx, this.cy, this.rx, this.ry);
  @override
  void addTo(Path p) => p.addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));
}

const Map<ComponentKind, List<_Op>> _ops = {
  ComponentKind.client: [_R(4, 5, 16, 11, 2), _P('M2.5 19h19')],
  ComponentKind.balancer: [_P('M3 12h6'), _P('M9 12c3 0 4-6 7-6h4'), _P('M9 12h11'), _P('M9 12c3 0 4 6 7 6h4')],
  ComponentKind.server: [_R(4, 4, 16, 7, 2), _R(4, 13, 16, 7, 2)],
  ComponentKind.cache: [_P('M13 3 5 13.5h6L10 21l8-10.5h-6L13 3Z')],
  ComponentKind.cdn: [
    _C(12, 12, 8.5),
    _P('M3.5 12h17'),
    _P('M12 3.5c2.5 2.6 3.6 5.5 3.6 8.5s-1.1 5.9-3.6 8.5c-2.5-2.6-3.6-5.5-3.6-8.5s1.1-5.9 3.6-8.5Z'),
  ],
  ComponentKind.gateway: [_P('M12 3 4.5 6v5.5c0 4.6 3.1 8 7.5 9.5 4.4-1.5 7.5-4.9 7.5-9.5V6L12 3Z'), _P('M9 12h6M12 9v6')],
  ComponentKind.worker: [
    _C(12, 12, 3),
    _P(
      'M12 3v2.5M12 18.5V21M3 12h2.5M18.5 12H21M5.6 5.6l1.8 1.8M16.6 16.6l1.8 1.8M5.6 18.4l1.8-1.8M16.6 7.4l1.8-1.8',
    ),
  ],
  ComponentKind.queue: [_R(3.5, 5, 4, 14, 1.2), _R(10, 5, 4, 14, 1.2), _P('M17 12h4M19 10l2 2-2 2')],
  ComponentKind.database: [
    _E(12, 5.5, 7, 2.5),
    _P('M5 5.5v13c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5v-13'),
    _P('M5 12c0 1.4 3.1 2.5 7 2.5s7-1.1 7-2.5'),
  ],
};

final Map<ComponentKind, Path> _paths = {
  for (final e in _ops.entries)
    e.key: () {
      final p = Path();
      for (final op in e.value) {
        op.addTo(p);
      }
      return p;
    }(),
};

/// Dibuja el icono en `box` (cuadrado) con el color dado.
void paintComponentIcon(Canvas canvas, ComponentKind kind, Rect box, Color color) {
  final s = box.width / 24;
  canvas.save();
  canvas.translate(box.left, box.top);
  canvas.scale(s);
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  canvas.drawPath(_paths[kind]!, paint);
  if (kind == ComponentKind.server) {
    final dot = Paint()..color = color;
    canvas.drawCircle(const Offset(8, 7.5), 1.5, dot);
    canvas.drawCircle(const Offset(8, 16.5), 1.5, dot);
  }
  canvas.restore();
}

Path hexPath(Rect box) {
  final s = box.width / 100;
  const pts = [(50, 3), (91, 26.5), (91, 73.5), (50, 97), (9, 73.5), (9, 26.5)];
  final p = Path();
  for (var i = 0; i < pts.length; i++) {
    final o = Offset(box.left + pts[i].$1 * s, box.top + pts[i].$2 * s);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// Icono dentro de un hexágono (la firma visual).
void paintHexIcon(Canvas canvas, ComponentKind kind, Rect box, Color hex, Color fg) {
  canvas.drawPath(hexPath(box), Paint()..color = hex);
  final inner = box.width * 0.5;
  paintComponentIcon(canvas, kind, Rect.fromCenter(center: box.center, width: inner, height: inner), fg);
}

class HexIcon extends StatelessWidget {
  final ComponentKind kind;
  final double size;
  final Color color;
  final Color fg;
  const HexIcon({super.key, required this.kind, required this.color, required this.fg, this.size = 36});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _HexPainter(kind, color, fg));
}

class _HexPainter extends CustomPainter {
  final ComponentKind kind;
  final Color color;
  final Color fg;
  _HexPainter(this.kind, this.color, this.fg);
  @override
  void paint(Canvas canvas, Size size) => paintHexIcon(canvas, kind, Offset.zero & size, color, fg);
  @override
  bool shouldRepaint(_HexPainter old) => old.kind != kind || old.color != color || old.fg != fg;
}

class ComponentIcon extends StatelessWidget {
  final ComponentKind kind;
  final double size;
  final Color color;
  const ComponentIcon({super.key, required this.kind, required this.color, this.size = 18});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _IconPainter(kind, color));
}

class _IconPainter extends CustomPainter {
  final ComponentKind kind;
  final Color color;
  _IconPainter(this.kind, this.color);
  @override
  void paint(Canvas canvas, Size size) => paintComponentIcon(canvas, kind, Offset.zero & size, color);
  @override
  bool shouldRepaint(_IconPainter old) => old.kind != kind || old.color != color;
}
