/// Archivo de proyecto (.distinode.json): el mismo formato que la versión web, así que los proyectos
/// se pueden pasar de una a otra. `parseProject` valida todo lo que entra: un archivo importado es
/// entrada no confiable.
library;

import '../sim/components.dart';
import 'diagram.dart';

const projectVersion = 1;
const maxNodes = 300;
const maxEdges = 1200;
const maxProjectBytes = 2000000;

Map<String, Object?> toProject({
  required String name,
  required Map<String, NodeData> nodes,
  required Map<String, EdgeData> edges,
  required SimShared sim,
  DateTime? createdAt,
}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return {
    'app': 'distinode',
    'version': projectVersion,
    'name': name,
    'exportedAt': now,
    // Extras de la versión de escritorio; la web los ignora.
    'createdAt': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
    'updatedAt': now,
    'sim': {'traffic': sim.traffic, 'chaos': sim.chaos, 'autoCrash': sim.autoCrash, 'restartSec': sim.restartSec},
    'nodes': [
      for (final n in nodes.values)
        {
          'id': n.id,
          'kind': n.kind.name,
          'label': n.label,
          'x': n.x,
          'y': n.y,
          'params': {for (final e in n.params.entries) e.key.name: e.value},
          // Las caídas temporales (caos, sobrecarga) no se guardan; las manuales sí.
          if (n.down && n.downUntil == null) 'down': true,
          if (n.slow && n.slowUntil == null) 'slow': true,
        },
    ],
    'edges': [
      for (final e in edges.values)
        {
          'id': e.id,
          'source': e.source,
          'target': e.target,
          if (e.latencyMs > 0) 'latencyMs': e.latencyMs,
          if (e.down && e.downUntil == null) 'down': true,
        },
    ],
  };
}

class ParsedProject {
  final String name;
  final List<NodeData> nodes;
  final List<EdgeData> edges;
  final SimShared sim;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  const ParsedProject(this.name, this.nodes, this.edges, this.sim, this.createdAt, this.updatedAt);
}

class ProjectParseError implements Exception {
  final String message;
  const ProjectParseError(this.message);
  @override
  String toString() => message;
}

double _num(Object? v, double lo, double hi, double def) {
  if (v is num && v.isFinite) return v.toDouble().clamp(lo, hi).toDouble();
  return def;
}

String _text(Object? v, int max, String def) {
  if (v is String && v.trim().isNotEmpty) {
    final t = v.trim();
    return t.length > max ? t.substring(0, max) : t;
  }
  return def;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// Valida y normaliza un proyecto. Los ids se regeneran para no chocar con los existentes.
/// Lanza [ProjectParseError] con un mensaje para mostrar.
ParsedProject parseProject(Object? raw) {
  if (raw is! Map || raw['app'] != 'distinode') throw const ProjectParseError('No es un proyecto de DistiNode.');
  final version = raw['version'];
  if (version is! num || version > projectVersion) {
    throw const ProjectParseError('El proyecto es de una versión más nueva de DistiNode.');
  }
  final rawNodes = raw['nodes'];
  final rawEdges = raw['edges'];
  if (rawNodes is! List || rawEdges is! List) throw const ProjectParseError('Faltan nodos o conexiones.');
  if (rawNodes.length > maxNodes || rawEdges.length > maxEdges) {
    throw const ProjectParseError('El proyecto es demasiado grande (máximo $maxNodes componentes).');
  }

  final ids = <String, String>{};
  final nodes = <NodeData>[];
  for (final n in rawNodes) {
    final kind = n is Map ? kindFromName(n['kind']) : null;
    if (n is! Map || kind == null || n['id'] is! String) {
      throw const ProjectParseError('Hay un componente que no se reconoce.');
    }
    final oldId = n['id'] as String;
    if (ids.containsKey(oldId)) throw const ProjectParseError('Hay componentes repetidos.');
    final spec = specOf(kind);
    final params = <ParamKey, double>{...spec.defaults};
    final rawParams = n['params'] is Map ? n['params'] as Map : const {};
    for (final p in spec.params) {
      params[p.key] = _num(rawParams[p.key.name], p.min, p.max, spec.defaults[p.key] ?? p.min);
    }
    final id = newId();
    ids[oldId] = id;
    nodes.add(
      NodeData(
        id: id,
        kind: kind,
        label: _text(n['label'], 40, spec.name),
        x: _num(n['x'], -1e6, 1e6, 0).roundToDouble(),
        y: _num(n['y'], -1e6, 1e6, 0).roundToDouble(),
        params: params,
        down: n['down'] == true,
        downReason: n['down'] == true ? DownReason.manual : null,
        slow: n['slow'] == true,
      ),
    );
  }

  final edges = <EdgeData>[];
  final seen = <String>{};
  for (final e in rawEdges) {
    if (e is! Map) throw const ProjectParseError('Hay una conexión mal formada.');
    final source = e['source'] is String ? ids[e['source']] : null;
    final target = e['target'] is String ? ids[e['target']] : null;
    if (source == null || target == null) {
      throw const ProjectParseError('Hay una conexión a un componente que no existe.');
    }
    final key = '$source>$target';
    if (source == target || seen.contains(key)) continue;
    seen.add(key);
    edges.add(
      EdgeData(
        id: newId(),
        source: source,
        target: target,
        latencyMs: e['latencyMs'] is num ? _num(e['latencyMs'], 0, 2000, 0) : 0,
        down: e['down'] == true,
      ),
    );
  }

  final sim = raw['sim'] is Map ? raw['sim'] as Map : const {};
  return ParsedProject(
    _text(raw['name'], 60, 'Proyecto'),
    nodes,
    edges,
    SimShared(
      traffic: clampTraffic(_num(sim['traffic'], 1, 200, 20)),
      chaos: sim['chaos'] == true,
      autoCrash: sim['autoCrash'] == true,
      restartSec: _num(sim['restartSec'], 1, 120, 8),
    ),
    _date(raw['createdAt']),
    _date(raw['updatedAt'] ?? raw['exportedAt']),
  );
}

/// Nombre de archivo seguro a partir del nombre del proyecto.
String fileSlug(String name) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final buf = StringBuffer();
  for (final ch in name.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    buf.write(i >= 0 ? to[i] : ch);
  }
  var slug = buf.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.length > 40) slug = slug.substring(0, 40);
  return slug.isEmpty ? 'diagrama' : slug;
}
