import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../sim/templates.dart';
import '../theme/tokens.dart';
import 'ui.dart';

/// Miniatura de la plantilla como mapa de metro: líneas a 45° y estaciones.
class TemplatePreview extends StatelessWidget {
  final Template template;
  final double width;
  final double height;
  const TemplatePreview({super.key, required this.template, this.width = 132, this.height = 64});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, height), painter: _PreviewPainter(template, context.c));
}

class _PreviewPainter extends CustomPainter {
  final Template t;
  final DistiColors c;
  _PreviewPainter(this.t, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    var cols = t.nodes.map((n) => n.col).reduce(math.max);
    if (cols == 0) cols = 1;
    final rows = t.nodes.map((n) => n.row).reduce(math.max);
    const pad = 8.0;
    double x(double col) => pad + (col / cols) * (size.width - pad * 2);
    double y(double row) => rows > 0 ? pad + (row / rows) * (size.height - pad * 2) : size.height / 2;
    final pos = {for (final n in t.nodes) n.key: Offset(x(n.col), y(n.row))};
    final line = Paint()
      ..color = c.verde
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    for (final e in t.edges) {
      final p = pos[e.from]!;
      final q = pos[e.to]!;
      final dx = q.dx - p.dx;
      final dy = q.dy - p.dy;
      final h = math.max(0.0, dx.abs() - dy.abs()) / 2;
      final path = Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx + dx.sign * h, p.dy)
        ..lineTo(q.dx - dx.sign * h, q.dy)
        ..lineTo(q.dx, q.dy);
      canvas.drawPath(path, line);
    }
    for (final n in t.nodes) {
      final o = pos[n.key]!;
      canvas.drawCircle(o, 3.6, Paint()..color = c.papel);
      canvas.drawCircle(
        o,
        3.6,
        Paint()
          ..color = c.tinta
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.t != t || old.c != c;
}

class TemplateButton extends StatelessWidget {
  final Template template;
  final void Function(Template) onPick;
  const TemplateButton({super.key, required this.template, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return HoverTile(
      onTap: () => onPick(template),
      border: c.linea,
      radius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: c.fondo, borderRadius: BorderRadius.circular(8)),
            child: TemplatePreview(template: template),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  template.summary,
                  style: TextStyle(fontSize: 14, height: 1.3, color: c.grisTexto),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo con todas las plantillas. Devuelve la elegida.
Future<Template?> showTemplateDialog(BuildContext context, {required bool replacing}) {
  return showDialog<Template>(
    context: context,
    builder: (ctx) {
      final c = ctx.c;
      final wide = MediaQuery.of(ctx).size.width > 640;
      return Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Plantillas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(
                            replacing ? 'Sustituyen el diagrama actual.' : 'Sistemas listos para darle al ▶.',
                            style: TextStyle(fontSize: 14, color: c.grisTexto),
                          ),
                        ],
                      ),
                    ),
                    RoundIconButton(
                      icon: Icon(Icons.close, size: 20, color: c.grisTexto),
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.linea),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final cat in templateCategories) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          cat == TemplateCategory.patrones
                              ? 'Patrones: una idea cada una'
                              : 'Sistemas reales: cómo están hechas apps que conoces',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.grisTexto),
                        ),
                      ),
                      _Grid(
                        columns: wide ? 2 : 1,
                        children: [
                          for (final t in templates.where((t) => t.category == cat))
                            TemplateButton(template: t, onPick: (picked) => Navigator.pop(ctx, picked)),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Rejilla simple de N columnas con filas de alto natural.
class _Grid extends StatelessWidget {
  final int columns;
  final List<Widget> children;
  const _Grid({required this.columns, required this.children});
  @override
  Widget build(BuildContext context) => Grid(columns: columns, children: children);
}

class Grid extends StatelessWidget {
  final int columns;
  final List<Widget> children;
  final double gap;
  const Grid({super.key, required this.columns, required this.children, this.gap = 8});
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final cells = <Widget>[];
      for (var j = 0; j < columns; j++) {
        if (j > 0) cells.add(SizedBox(width: gap));
        cells.add(Expanded(child: i + j < children.length ? children[i + j] : const SizedBox()));
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
