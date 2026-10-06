import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import '../model/diagram.dart';
import '../sim/components.dart';
import '../sim/types.dart';
import '../store/diagram_store.dart';
import '../theme/tokens.dart';
import '../widgets/icons.dart';
import 'editor_controller.dart';
import 'geometry.dart';

/// Pintura del diagrama en coordenadas del lienzo. La usan la pantalla y la exportación a PNG.

class TextCache {
  final _map = <String, TextPainter>{};

  TextPainter get(String text, TextStyle style, double maxWidth) {
    final key = '${style.fontSize}|${style.fontWeight?.value}|${style.color?.toARGB32()}|$maxWidth|$text';
    final hit = _map[key];
    if (hit != null) return hit;
    if (_map.length > 3000) _map.clear();
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    return _map[key] = tp;
  }

  void clear() => _map.clear();
}

String _summary(ComponentKind kind, Params params) {
  String v(ParamKey k) => fmt(paramValue(kind, params, k));
  switch (kind) {
    case ComponentKind.server:
    case ComponentKind.worker:
    case ComponentKind.database:
      return '${v(ParamKey.capacity)} pet/s · cola ${v(ParamKey.queueMax)}';
    case ComponentKind.cache:
    case ComponentKind.cdn:
      return '${v(ParamKey.hitRate)} % aciertos';
    case ComponentKind.balancer:
      return paramValue(kind, params, ParamKey.lbAlgorithm) == 1 ? 'menos conexiones' : 'por turnos';
    case ComponentKind.gateway:
      return 'límite ${v(ParamKey.rateLimit)} pet/s';
    case ComponentKind.queue:
      return 'capacidad ${v(ParamKey.queueMax)} msj';
    case ComponentKind.client:
      final r = paramValue(kind, params, ParamKey.retries);
      return r > 0 ? '${fmt(r)} reintentos' : 'genera tráfico';
  }
}

String _liveSummary(ComponentKind kind, NodeStats s) {
  final rate = '${fmt(s.arrivalRate)} pet/s';
  if (hasCapacity(kind)) return '$rate · cola ${s.queue}/${fmt(s.queueMax)}';
  if (kind == ComponentKind.queue) return '${s.queue} en espera · ${s.busy} entregados';
  if (kind == ComponentKind.client) return 'enviando';
  if (s.dropRate > 0) return '$rate · ${fmt(s.dropRate)} rechazadas';
  return rate;
}

const _reason = {
  DownReason.manual: 'Caído',
  DownReason.caos: 'Caído (caos)',
  DownReason.sobrecarga: 'Caído por sobrecarga',
};

int? secondsLeft(int? until, int nowMs) => until == null ? null : math.max(0, ((until - nowMs) / 1000).ceil());

class DiagramScene {
  final DiagramStore store;
  final Map<String, Polyline> lines;
  final NodeStats? Function(String id) stats;
  final DistiColors c;
  final TextCache text;
  final Selection selection;
  final String? hoverNode;
  final (String, HandleSide)? hoverHandle;
  final PendingConnection? connection;
  final bool largeHandles;
  final int nowMs;

  DiagramScene({
    required this.store,
    required this.lines,
    required this.stats,
    required this.c,
    required this.text,
    this.selection = const Selection(),
    this.hoverNode,
    this.hoverHandle,
    this.connection,
    this.largeHandles = false,
    required this.nowMs,
  });

  Polyline? lineFor(EdgeData e) {
    final hit = lines[e.id];
    if (hit != null) return hit;
    final a = store.nodes[e.source];
    final b = store.nodes[e.target];
    if (a == null || b == null) return null;
    return edgeLine(Offset(a.x, a.y), Offset(b.x, b.y));
  }

  void paint(Canvas canvas) {
    for (final e in store.edges.values) {
      _paintEdge(canvas, e);
    }
    _paintConnection(canvas);
    final sel = selection.nodes;
    for (final n in store.nodes.values) {
      if (!sel.contains(n.id)) _paintNode(canvas, n);
    }
    for (final n in store.nodes.values) {
      if (sel.contains(n.id)) _paintNode(canvas, n);
    }
  }

  void _paintEdge(Canvas canvas, EdgeData e) {
    final pl = lineFor(e);
    if (pl == null) return;
    final path = roundedPath(pl.pts);
    final selected = selection.edges.contains(e.id);
    if (selected) {
      canvas.drawPath(
        path,
        Paint()
          ..color = c.tinta.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final color = e.down ? c.rojo : (selected ? c.verdeFuerte : c.verde);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(e.down ? dashPath(path, dashArray: CircularIntervalList([2.0, 10.0])) : path, line);
    final b = pl.pts.last;
    final arrow = Path()
      ..moveTo(b.dx - 13, b.dy - 7)
      ..lineTo(b.dx - 2, b.dy)
      ..lineTo(b.dx - 13, b.dy + 7)
      ..close();
    canvas.drawPath(arrow, Paint()..color = e.down ? c.rojo : c.verde);

    final tag = e.down ? 'cortada' : (e.latencyMs > 0 ? '+${fmt(e.latencyMs)} ms' : null);
    if (tag != null) {
      final (mid, _) = pl.pointAt(0.5);
      final w = tag.length * 6.6 + 14;
      final center = Offset(mid.dx, mid.dy - 16);
      final tagColor = e.down ? c.rojo : c.ambar;
      final rr = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: w, height: 20), const Radius.circular(10));
      canvas.drawRRect(rr, Paint()..color = c.papel);
      canvas.drawRRect(
        rr,
        Paint()
          ..color = tagColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final tp = text.get(
        tag,
        TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: tagColor,
          fontFeatures: tabular,
        ),
        200,
      );
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintConnection(Canvas canvas) {
    final conn = connection;
    if (conn == null) return;
    final n = store.nodes[conn.nodeId];
    if (n == null) return;
    final List<Offset> pts;
    if (conn.side == HandleSide.output) {
      pts = metroPoints(Offset(n.x + nodeW, n.y + nodeH / 2), conn.cursor);
    } else {
      pts = metroPoints(conn.cursor, Offset(n.x, n.y + nodeH / 2));
    }
    canvas.drawPath(
      roundedPath(pts),
      Paint()
        ..color = c.verde
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintNode(Canvas canvas, NodeData n) {
    final rect = Rect.fromLTWH(n.x, n.y, nodeW, nodeH);
    final st = stats(n.id);
    final live = st != null && st.status != Health.idle && !n.down;
    final status = live ? st.status : null;
    final selected = selection.nodes.contains(n.id);

    Color border = c.tinta;
    Color hex = c.verde;
    if (status == Health.ok) border = c.verde;
    if (status == Health.warn) border = hex = c.ambar;
    if (status == Health.hot) border = hex = c.rojo;
    if (n.down) {
      border = c.gris;
      hex = c.gris;
    }

    final pill = RRect.fromRectAndRadius(rect, const Radius.circular(nodeH / 2));
    canvas.drawRRect(pill, Paint()..color = n.down ? c.fondo : c.papel);
    final inner = pill.deflate(1.75);
    final stroke = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    if (n.down) {
      canvas.drawPath(dashPath(Path()..addRRect(inner), dashArray: CircularIntervalList([10.0, 6.0])), stroke);
    } else if (n.slow) {
      canvas.drawPath(
        dashPath(Path()..addRRect(inner), dashArray: CircularIntervalList([0.1, 7.0])),
        stroke..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawRRect(inner, stroke);
    }
    if (selected) {
      canvas.drawRRect(
        pill.inflate(5.25),
        Paint()
          ..color = c.verde
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Hexágono con el icono.
    final hexBox = Rect.fromLTWH(n.x + 11.5, n.y + (nodeH - 38) / 2, 38, 38);
    paintHexIcon(canvas, n.kind, hexBox, hex, c.sobreVerde);

    // Textos.
    final left = n.x + 11.5 + 38 + 10;
    final maxW = nodeW - (left - n.x) - 19.5;
    String line;
    final secs = n.down ? secondsLeft(n.downUntil, nowMs) : null;
    if (n.down) {
      line = secs != null ? 'Reiniciando… $secs s' : _reason[n.downReason ?? DownReason.manual]!;
    } else if (live) {
      line = _liveSummary(n.kind, st);
    } else {
      line = _summary(n.kind, n.params);
    }
    final title = text.get(
      n.label,
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: n.down ? c.grisTexto : c.tinta,
        height: 1.25,
      ),
      maxW,
    );
    final sub = text.get(
      line,
      TextStyle(
        fontFamily: fontFamily,
        fontSize: 12.8,
        color: n.down ? c.rojo : c.grisTexto,
        fontFeatures: tabular,
        height: 1.25,
      ),
      maxW,
    );
    final top = n.y + (nodeH - title.height - sub.height) / 2;
    title.paint(canvas, Offset(left, top));
    sub.paint(canvas, Offset(left, top + title.height));

    // Asas.
    _paintHandle(canvas, n, HandleSide.input, Offset(n.x, n.y + nodeH / 2));
    _paintHandle(canvas, n, HandleSide.output, Offset(n.x + nodeW, n.y + nodeH / 2));

    if (n.slow && !n.down) {
      final tp = text.get(
        'lento',
        const TextStyle(fontFamily: fontFamily, fontSize: 10.4, fontWeight: FontWeight.w700, color: Colors.white),
        80,
      );
      final w = tp.width + 12 + 4;
      final h = tp.height + 4;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.right + 4 - w, rect.bottom + 8 - h, w, h),
        Radius.circular(h / 2),
      );
      canvas.drawRRect(r, Paint()..color = c.papel);
      canvas.drawRRect(r.deflate(2), Paint()..color = c.ambar);
      tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintHandle(Canvas canvas, NodeData n, HandleSide side, Offset at) {
    final active =
        (hoverHandle?.$1 == n.id && hoverHandle?.$2 == side) ||
        (connection?.hoverTarget == n.id && side != connection?.side);
    final r = largeHandles ? 11.0 : 7.0;
    final bw = largeHandles ? 4.0 : 3.0;
    canvas.drawCircle(at, r, Paint()..color = active ? c.verde : c.papel);
    canvas.drawCircle(
      at,
      r - bw / 2,
      Paint()
        ..color = active ? c.verde : c.tinta
        ..style = PaintingStyle.stroke
        ..strokeWidth = bw,
    );
  }
}

/// Fondo de puntos en coordenadas de pantalla.
void paintDots(Canvas canvas, Size size, double tx, double ty, double zoom, Color color) {
  var gap = 24 * zoom;
  while (gap < 10) {
    gap *= 2;
  }
  final r = math.max(0.6, 0.8 * zoom);
  final paint = Paint()..color = color;
  final ox = tx % gap;
  final oy = ty % gap;
  final points = <Offset>[];
  for (var x = ox; x < size.width; x += gap) {
    for (var y = oy; y < size.height; y += gap) {
      points.add(Offset(x, y));
    }
  }
  canvas.drawPoints(
    ui.PointMode.points,
    points,
    paint
      ..strokeWidth = r * 2
      ..strokeCap = StrokeCap.round,
  );
}

/// Trenes sobre las líneas (port de `TrafficLayer.tsx`). Coordenadas de pantalla.
const maxDrawn = 260;

void paintTrains(
  Canvas canvas,
  List<Train> trains,
  Map<String, Polyline> lines,
  DistiColors p,
  double tx,
  double ty,
  double zoom, {
  bool reduced = false,
}) {
  if (trains.isEmpty) return;
  if (reduced) return _paintStatic(canvas, trains, lines, p, tx, ty, zoom);
  final every = (trains.length / maxDrawn).ceil();
  final s = zoom.clamp(0.55, 1.5);
  final w = 15 * s;
  final h = 8 * s;
  final fill = Paint();
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5 * s;

  for (final t in trains) {
    if (every > 1 && t.id % every != 0) continue;
    final pl = lines[t.edgeId];
    if (pl == null) continue;
    final (pt, angle) = pl.pointAt(t.progress);
    // Se desvanecen al entrar y salir de las estaciones.
    final edgeFade = math.min(t.progress, 1 - t.progress) * pl.length;
    final alpha = ((edgeFade - 6) / 14).clamp(0.0, 1.0);
    if (alpha <= 0) continue;

    canvas.save();
    canvas.translate(pt.dx * zoom + tx, pt.dy * zoom + ty);
    canvas.rotate(angle);
    switch (t.kind) {
      case TrainKind.async:
        // Mensaje de cola: rombo oscuro, para distinguirlo de las peticiones de los clientes.
        final d = Path()
          ..moveTo(-h * 0.9, 0)
          ..lineTo(0, -h * 0.9)
          ..lineTo(h * 0.9, 0)
          ..lineTo(0, h * 0.9)
          ..close();
        canvas.drawPath(d, fill..color = p.tinta.withValues(alpha: alpha));
        canvas.drawPath(d, stroke..color = p.papel.withValues(alpha: alpha));
      case TrainKind.request:
        final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), Radius.circular(h / 2));
        canvas.drawRRect(r, fill..color = p.papel.withValues(alpha: alpha));
        canvas.drawRRect(r, stroke..color = p.tinta.withValues(alpha: alpha));
      case TrainKind.response:
      case TrainKind.error:
        final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), Radius.circular(h / 2));
        canvas.drawRRect(r, fill..color = (t.kind == TrainKind.error ? p.rojo : p.grisTren).withValues(alpha: alpha));
    }
    canvas.restore();
  }
}

/// Movimiento reducido: sin trenes que se desplacen; las líneas con tráfico se resaltan quietas.
void _paintStatic(Canvas canvas, List<Train> trains, Map<String, Polyline> lines, DistiColors p, double tx, double ty, double zoom) {
  final load = <String, (int, int)>{};
  for (final t in trains) {
    final l = load[t.edgeId] ?? (0, 0);
    load[t.edgeId] = (l.$1 + 1, l.$2 + (t.kind == TrainKind.error ? 1 : 0));
  }
  for (final entry in load.entries) {
    final pl = lines[entry.key];
    if (pl == null) continue;
    final (n, errors) = entry.value;
    final path = Path();
    for (var i = 0; i < pl.pts.length; i++) {
      final q = pl.pts[i] * zoom + Offset(tx, ty);
      i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    final k = math.min(1.0, n / 25);
    canvas.drawPath(
      path,
      Paint()
        ..color = (errors > n / 3 ? p.rojo : p.verde).withValues(alpha: 0.18 + 0.32 * k)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = (10 + 8 * k) * math.max(zoom, 0.5),
    );
  }
}
