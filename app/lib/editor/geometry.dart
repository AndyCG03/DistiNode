import 'dart:math' as math;
import 'dart:ui';

/// Trazado "mapa de metro": tramos horizontales y diagonales a 45°. Port de `geometry.ts`.
/// Lo comparten las líneas y la capa de trenes para que los trenes vayan exactamente sobre la línea.

const double nodeW = 184;
const double nodeH = 60;
const double stub = 22;
const double _corner = 14;

List<Offset> metroPoints(Offset s, Offset t) {
  final a = Offset(s.dx + stub, s.dy);
  final b = Offset(t.dx - stub, t.dy);
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  final sx = dx.sign;
  final sy = dy.sign;
  final adx = dx.abs();
  final ady = dy.abs();

  List<Offset> mid;
  if (adx >= ady) {
    final h = (adx - ady) / 2;
    final p1 = Offset(a.dx + sx * h, a.dy);
    mid = [p1, Offset(p1.dx + sx * ady, b.dy)];
  } else {
    final d = adx / 2;
    final p1 = Offset(a.dx + sx * d, a.dy + sy * d);
    mid = [p1, Offset(p1.dx, b.dy - sy * d)];
  }
  final pts = [s, a, ...mid, b, t];
  final out = <Offset>[pts.first];
  for (var i = 1; i < pts.length; i++) {
    if ((pts[i] - pts[i - 1]).distance > 0.5) out.add(pts[i]);
  }
  return out;
}

/// Path con esquinas redondeadas.
Path roundedPath(List<Offset> pts) {
  final p = Path();
  if (pts.length < 2) return p;
  p.moveTo(pts[0].dx, pts[0].dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final p0 = pts[i - 1];
    final c = pts[i];
    final p1 = pts[i + 1];
    final l0 = (c - p0).distance;
    final l1 = (p1 - c).distance;
    final r = math.min(_corner, math.min(l0 / 2, l1 / 2));
    final a = c + (p0 - c) / l0 * r;
    final b = c + (p1 - c) / l1 * r;
    p.lineTo(a.dx, a.dy);
    p.quadraticBezierTo(c.dx, c.dy, b.dx, b.dy);
  }
  p.lineTo(pts.last.dx, pts.last.dy);
  return p;
}

class Polyline {
  final List<Offset> pts;

  /// Longitud acumulada hasta cada punto.
  final List<double> acc;
  final double length;
  Polyline._(this.pts, this.acc, this.length);

  factory Polyline(List<Offset> pts) {
    final acc = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      acc.add(acc[i - 1] + (pts[i] - pts[i - 1]).distance);
    }
    return Polyline._(pts, acc, acc.last);
  }

  /// Punto y dirección (radianes) a una fracción 0..1 del recorrido.
  (Offset, double) pointAt(double f) {
    if (pts.length == 1 || length == 0) return (pts.first, 0);
    final d = f.clamp(0.0, 1.0) * length;
    var i = 1;
    while (i < acc.length - 1 && acc[i] < d) {
      i++;
    }
    final p0 = pts[i - 1];
    final p1 = pts[i];
    final seg = acc[i] - acc[i - 1];
    final k = (d - acc[i - 1]) / (seg == 0 ? 1 : seg);
    return (Offset.lerp(p0, p1, k)!, math.atan2(p1.dy - p0.dy, p1.dx - p0.dx));
  }

  /// Distancia mínima de `q` a la polilínea.
  double distanceTo(Offset q) {
    var best = double.infinity;
    for (var i = 1; i < pts.length; i++) {
      best = math.min(best, _segDist(q, pts[i - 1], pts[i]));
    }
    return best;
  }
}

double _segDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

/// Salida por la derecha del origen, entrada por la izquierda del destino.
(Offset, Offset) endpoints(Offset source, Offset target) => (
  Offset(source.dx + nodeW, source.dy + nodeH / 2),
  Offset(target.dx, target.dy + nodeH / 2),
);

Polyline edgeLine(Offset source, Offset target) {
  final (s, t) = endpoints(source, target);
  return Polyline(metroPoints(s, t));
}
