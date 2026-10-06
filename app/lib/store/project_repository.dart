import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../model/diagram.dart';
import '../model/project_file.dart';
import 'diagram_store.dart';

class ProjectMeta {
  final String id;
  final String name;
  final DateTime updatedAt;
  final int nodeCount;
  final int edgeCount;
  final File file;
  const ProjectMeta(this.id, this.name, this.updatedAt, this.nodeCount, this.edgeCount, this.file);
}

const projectExt = '.distinode.json';

/// Proyectos guardados en este equipo: un archivo `.distinode.json` por proyecto (el mismo formato que
/// exporta la web). En escritorio, en Documentos/DistiNode/Proyectos; en el móvil, en la carpeta de la app.
class ProjectRepository {
  final Directory dir;
  ProjectRepository._(this.dir);

  /// Repositorio en una carpeta concreta (pruebas).
  factory ProjectRepository.at(Directory dir) => ProjectRepository._(dir);

  static Future<ProjectRepository> open() async {
    final Directory base;
    if (Platform.isAndroid || Platform.isIOS) {
      base = await getApplicationDocumentsDirectory();
    } else {
      base = Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}DistiNode');
    }
    final dir = Directory('${base.path}${Platform.pathSeparator}Proyectos');
    await dir.create(recursive: true);
    return ProjectRepository._(dir);
  }

  File _file(String id) => File('${dir.path}${Platform.pathSeparator}$id$projectExt');

  Future<List<ProjectMeta>> list() async {
    final out = <ProjectMeta>[];
    await for (final f in dir.list()) {
      if (f is! File || !f.path.endsWith(projectExt)) continue;
      try {
        final raw = jsonDecode(await f.readAsString());
        final p = parseProject(raw);
        final name = f.uri.pathSegments.last;
        final id = name.substring(0, name.length - projectExt.length);
        out.add(ProjectMeta(id, p.name, p.updatedAt ?? await f.lastModified(), p.nodes.length, p.edges.length, f));
      } catch (_) {
        // Archivo dañado o ajeno: no se lista (sigue en la carpeta).
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<DiagramStore> load(String id) async {
    final p = parseProject(jsonDecode(await _file(id).readAsString()));
    return DiagramStore(
      name: p.name,
      createdAt: p.createdAt ?? DateTime.now(),
      nodes: p.nodes,
      edges: p.edges,
      sim: p.sim,
    );
  }

  Future<void> save(String id, DiagramStore s) => _write(
    id,
    toProject(name: s.name, nodes: s.nodes, edges: s.edges, sim: s.sim, createdAt: s.createdAt),
  );

  Future<void> _write(String id, Map<String, Object?> json) async {
    final f = _file(id);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(json), flush: true);
    await tmp.rename(f.path);
  }

  /// Nuevo proyecto (vacío o con contenido) → id.
  Future<String> create(
    String name, {
    List<NodeData> nodes = const [],
    List<EdgeData> edges = const [],
    SimShared sim = const SimShared(),
  }) async {
    final id = newId();
    await _write(
      id,
      toProject(
        name: name,
        nodes: {for (final n in nodes) n.id: n},
        edges: {for (final e in edges) e.id: e},
        sim: sim,
      ),
    );
    return id;
  }

  /// Importa un archivo externo como proyecto nuevo. Lanza [ProjectParseError].
  Future<String> importBytes(List<int> bytes) async {
    if (bytes.length > maxProjectBytes) throw const ProjectParseError('El archivo es demasiado grande.');
    Object? raw;
    try {
      raw = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const ProjectParseError('El archivo no es un JSON válido.');
    }
    final p = parseProject(raw);
    return create(p.name, nodes: p.nodes, edges: p.edges, sim: p.sim);
  }

  Future<String> duplicate(String id) async {
    final s = await load(id);
    return create('${s.name} (copia)', nodes: s.nodes.values.toList(), edges: s.edges.values.toList(), sim: s.sim);
  }

  Future<void> rename(String id, String name) async {
    final s = await load(id);
    s.rename(name);
    await save(id, s);
  }

  Future<void> delete(String id) async {
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }

  Future<String> exportJson(String id) async => _file(id).readAsString();
}

/// Preferencias (tema). Un JSON pequeño junto a los proyectos.
class Settings {
  final File _file;
  Map<String, Object?> _data = {};
  Settings._(this._file);

  /// Ajustes en un archivo concreto (pruebas).
  factory Settings.at(File file) => Settings._(file);

  static Future<Settings> open() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    final s = Settings._(File('${dir.path}${Platform.pathSeparator}ajustes.json'));
    try {
      final raw = jsonDecode(await s._file.readAsString());
      if (raw is Map<String, Object?>) s._data = raw;
    } catch (_) {}
    return s;
  }

  Object? operator [](String key) => _data[key];

  Future<void> set(String key, Object? value) async {
    _data[key] = value;
    try {
      await _file.writeAsString(jsonEncode(_data));
    } catch (_) {}
  }
}
