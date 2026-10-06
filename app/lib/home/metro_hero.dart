import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../theme/tokens.dart';

const _routeA = 'M40 150 H220 L290 80 H390 L460 150 H520';
const _routeB = 'M40 150 H220 L290 220 H390 L460 150 H520';

const _trains = [(0, 0.0, false), (1, -0.8, false), (0, -1.6, false), (1, -2.4, false), (0, -0.4, true), (1, -2.0, true)];

const _stations = [
  (40.0, 150.0, 'Cliente', 34.0),
  (180.0, 150.0, 'Balanceador', 34.0),
  (340.0, 80.0, 'Servidor 1', -22.0),
  (340.0, 220.0, 'Servidor 2', 34.0),
  (520.0, 150.0, 'Base de datos', 34.0),
];

/// Ilustración de portada: un mini mapa de metro con tráfico (port de `MetroHero.tsx`).
class MetroHero extends StatefulWidget {
  const MetroHero({super.key});
  @override
  State<MetroHero> createState() => _MetroHeroState();
}

class _MetroHeroState extends State<MetroHero> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
    ..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.of(context).disableAnimations;
    return AspectRatio(
      aspectRatio: 600 / 290,
      child: CustomPaint(painter: _HeroPainter(context.c, reduced ? null : _anim)),
    );
  }
}

class _HeroPainter extends CustomPainter {
  final DistiColors c;
  final Animation<double>? anim;
  static final _paths = [parseSvgPathData(_routeA), parseSvgPathData(_routeB)];
  static final _metrics = [for (final p in _paths) p.computeMetrics().first];

  _HeroPainter(this.c, this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 600;
    canvas.scale(s);
    canvas.translate(10, 0);
    final line = Paint()
      ..color = c.verde
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final p in _paths) {
      canvas.drawPath(p, line);
    }
    final t = anim?.value ?? 0.5;
    for (final (route, delay, back) in _trains) {
      final m = _metrics[route];
      var f = (t - delay / 3.2) % 1;
      if (anim == null) f = 0.5;
      if (back) f = 1 - f;
      final tan = m.getTangentForOffset(f * m.length);
      if (tan == null) continue;
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(-tan.angle);
      final r = RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -4, 20, 8), const Radius.circular(4));
      canvas.drawRRect(r, Paint()..color = back ? c.grisTren : c.papel);
      if (!back) {
        canvas.drawRRect(
          r,
          Paint()
            ..color = c.verdeFuerte
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      canvas.restore();
    }
    for (final (x, y, label, dy) in _stations) {
      canvas.drawCircle(Offset(x, y), 13, Paint()..color = c.papel);
      canvas.drawCircle(
        Offset(x, y),
        13,
        Paint()
          ..color = c.tinta
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontFamily: fontFamily, fontSize: 15, fontWeight: FontWeight.w600, color: c.tinta),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y + dy - tp.height * 0.8));
    }
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.c != c;
}
