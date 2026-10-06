import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart' hide XFile;
import 'package:share_plus/share_plus.dart' as share show XFile;

import '../model/project_file.dart';
import '../sim/types.dart';
import '../store/diagram_store.dart';
import '../theme/tokens.dart';
import 'diagram_paint.dart';
import 'geometry.dart';

bool get isMobile => Platform.isAndroid || Platform.isIOS;

const _jsonGroup = XTypeGroup(
  label: 'Proyecto de DistiNode',
  extensions: ['json'],
  mimeTypes: ['application/json', 'text/plain', 'application/octet-stream'],
  uniformTypeIdentifiers: ['public.json'],
);

/// Guarda bytes en un archivo elegido por el usuario. En el móvil, abre el menú de compartir
/// (Guardar en Archivos, Drive, correo…). Devuelve false si se canceló.
Future<bool> saveFile(
  BuildContext context, {
  required String name,
  required Uint8List bytes,
  required String mime,
  required String extensionLabel,
  required List<String> extensions,
}) async {
  if (isMobile) {
    final box = context.findRenderObject() as RenderBox?;
    final r = await SharePlus.instance.share(
      ShareParams(
        files: [share.XFile.fromData(bytes, mimeType: mime, name: name)],
        fileNameOverrides: [name],
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      ),
    );
    return r.status != ShareResultStatus.dismissed;
  }
  final loc = await getSaveLocation(
    suggestedName: name,
    acceptedTypeGroups: [XTypeGroup(label: extensionLabel, extensions: extensions)],
  );
  if (loc == null) return false;
  var path = loc.path;
  if (!extensions.any((e) => path.toLowerCase().endsWith('.$e'))) path = '$path.${extensions.first}';
  await File(path).writeAsBytes(bytes, flush: true);
  return true;
}

/// Pide un archivo de proyecto. Devuelve sus bytes, o null si se canceló.
Future<Uint8List?> pickProjectFile() async {
  final f = await openFile(acceptedTypeGroups: [_jsonGroup]);
  if (f == null) return null;
  final len = await f.length();
  if (len > maxProjectBytes) throw const ProjectParseError('El archivo es demasiado grande.');
  return f.readAsBytes();
}

Future<bool> saveProjectFile(BuildContext context, DiagramStore store) {
  final json = const JsonEncoder.withIndent('  ').convert(
    toProject(name: store.name, nodes: store.nodes, edges: store.edges, sim: store.sim, createdAt: store.createdAt),
  );
  return saveFile(
    context,
    name: '${fileSlug(store.name)}.distinode.json',
    bytes: Uint8List.fromList(utf8.encode(json)),
    mime: 'application/json',
    extensionLabel: 'Proyecto de DistiNode',
    extensions: const ['json'],
  );
}

/// Diagrama encuadrado a PNG, con una franja inferior con la marca, el nombre y la fecha
/// (como `diagramToPng` de la web).
Future<Uint8List?> diagramToPng(
  DiagramStore store,
  Map<String, Polyline> lines,
  NodeStats? Function(String) stats,
  DistiColors c,
) async {
  if (store.nodes.isEmpty) return null;
  var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
  for (final n in store.nodes.values) {
    l = math.min(l, n.x - 12);
    t = math.min(t, n.y - 30);
    r = math.max(r, n.x + nodeW + 12);
    b = math.max(b, n.y + nodeH + 12);
  }
  final bw = r - l;
  final bh = b - t;
  final width = (bw + 160).clamp(900, 4000).roundToDouble();
  final height = (bh + 200).clamp(500, 3000).roundToDouble();
  final zoom = math.min(width / (bw * 1.1), height / (bh * 1.1)).clamp(0.2, 1.5);
  final tx = width / 2 - (l + bw / 2) * zoom;
  final ty = height / 2 - (t + bh / 2) * zoom;
  const ratio = 2.0;
  const band = 64 * ratio;
  final pw = width * ratio;
  final ph = height * ratio;

  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Rect.fromLTWH(0, 0, pw, ph + band), Paint()..color = c.fondo);
  canvas.save();
  canvas.scale(ratio);
  canvas.translate(tx, ty);
  canvas.scale(zoom);
  DiagramScene(
    store: store,
    lines: lines,
    stats: stats,
    c: c,
    text: TextCache(),
    nowMs: DateTime.now().millisecondsSinceEpoch,
  ).paint(canvas);
  canvas.restore();

  // Franja inferior: marca, nombre y fecha.
  canvas.drawRect(Rect.fromLTWH(0, ph, pw, 2), Paint()..color = c.linea);
  final y = ph + band / 2;
  final brand = TextPainter(
    text: TextSpan(
      style: const TextStyle(fontFamily: fontFamily, fontSize: 40, fontWeight: FontWeight.w700),
      children: [
        TextSpan(text: 'Disti', style: TextStyle(color: c.verde)),
        TextSpan(text: 'Node', style: TextStyle(color: c.tinta)),
      ],
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  brand.paint(canvas, Offset(48, y - brand.height / 2));
  final right = TextPainter(
    text: TextSpan(
      text: '${store.name} · ${longDate(DateTime.now())}',
      style: TextStyle(fontFamily: fontFamily, fontSize: 32, color: c.grisTexto),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: pw - 96 - brand.width - 48);
  right.paint(canvas, Offset(pw - 48 - right.width, y - right.height / 2));

  final img = await rec.endRecording().toImage(pw.round(), (ph + band).round());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return data?.buffer.asUint8List();
}

/// Decodifica un JSON en UTF-8. Lanza [FormatException] si no lo es.
Object? jsonDecodeSafe(List<int> bytes) => jsonDecode(utf8.decode(bytes));
