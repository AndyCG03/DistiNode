import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Marca de DistiNode: cuatro cubos isométricos (el cubo de la CUJAE) unidos por un hexágono abierto.
/// Mismos polígonos que `Logo.tsx` (viewBox "20 -10 540 500").
const _verde = Color(0xFF0B6B4F);
const _gris = Color(0xFFA6A6A6);

const _polylines = [
  [97.0, 300.0, 97.0, 165.0, 205.0, 103.0],
  [375.0, 103.0, 483.0, 165.0, 483.0, 300.0],
  [188.0, 410.0, 290.0, 469.0, 392.0, 410.0],
];
const _lines = [
  [290.0, 140.0, 290.0, 190.0],
  [160.0, 350.0, 215.0, 318.0],
];

/// (color, puntos)
const _polys = <(int, List<double>)>[
  (0, [290.0, 184.0, 366.2, 228.0, 290.0, 272.0, 213.8, 228.0]),
  (1, [213.8, 228.0, 290.0, 272.0, 290.0, 360.0, 213.8, 316.0]),
  (2, [224.5, 246.5, 282.4, 276.4, 282.4, 346.8, 224.5, 309.8]),
  (1, [290.0, 272.0, 366.2, 228.0, 366.2, 316.0, 290.0, 360.0]),
  (0, [290.0, 4.0, 347.2, 37.0, 290.0, 70.0, 232.8, 37.0]),
  (1, [232.8, 37.0, 290.0, 70.0, 290.0, 136.0, 232.8, 103.0]),
  (2, [240.8, 50.9, 284.3, 73.3, 284.3, 126.1, 240.8, 98.4]),
  (1, [290.0, 70.0, 347.2, 37.0, 347.2, 103.0, 290.0, 136.0]),
  (0, [110.0, 316.0, 167.2, 349.0, 110.0, 382.0, 52.8, 349.0]),
  (1, [52.8, 349.0, 110.0, 382.0, 110.0, 448.0, 52.8, 415.0]),
  (2, [60.8, 362.9, 104.3, 385.3, 104.3, 438.1, 60.8, 410.4]),
  (1, [110.0, 382.0, 167.2, 349.0, 167.2, 415.0, 110.0, 448.0]),
  (0, [470.0, 316.0, 527.2, 349.0, 470.0, 382.0, 412.8, 349.0]),
  (1, [412.8, 349.0, 470.0, 382.0, 470.0, 448.0, 412.8, 415.0]),
  (2, [420.8, 362.9, 464.3, 385.3, 464.3, 438.1, 420.8, 410.4]),
  (1, [470.0, 382.0, 527.2, 349.0, 527.2, 415.0, 470.0, 448.0]),
];

void paintLogo(Canvas canvas, Rect box) {
  final s = box.width / 540;
  canvas.save();
  canvas.translate(box.left, box.top);
  canvas.scale(s);
  canvas.translate(-20, 10);
  final stroke = Paint()
    ..color = _verde
    ..style = PaintingStyle.stroke
    ..strokeWidth = 24
    ..strokeJoin = StrokeJoin.miter;
  for (final pl in _polylines) {
    final p = Path()..moveTo(pl[0], pl[1]);
    for (var i = 2; i < pl.length; i += 2) {
      p.lineTo(pl[i], pl[i + 1]);
    }
    canvas.drawPath(p, stroke);
  }
  final thin = Paint()
    ..color = _verde
    ..strokeWidth = 4;
  for (final l in _lines) {
    canvas.drawLine(Offset(l[0], l[1]), Offset(l[2], l[3]), thin);
  }
  const colors = [_gris, _verde, Color(0xFFFFFFFF)];
  for (final (ci, pts) in _polys) {
    final p = Path()..moveTo(pts[0], pts[1]);
    for (var i = 2; i < pts.length; i += 2) {
      p.lineTo(pts[i], pts[i + 1]);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = colors[ci]);
  }
  canvas.restore();
}

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 32});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size * 500 / 540), painter: _LogoPainter());
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => paintLogo(canvas, Offset.zero & size);
  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}

/// Marca + "DistiNode".
class Logo extends StatelessWidget {
  final double size;
  const Logo({super.key, this.size = 32});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoMark(size: size),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Disti', style: TextStyle(color: c.verde)),
              TextSpan(text: 'Node', style: TextStyle(color: c.tinta)),
            ],
          ),
          style: const TextStyle(fontSize: 21.6, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1),
        ),
      ],
    );
  }
}
