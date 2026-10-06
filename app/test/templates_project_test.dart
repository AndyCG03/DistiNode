// Port de src/sim/templates.test.ts y src/features/collab/project.test.ts.
import 'dart:convert';

import 'package:distinode/model/diagram.dart';
import 'package:distinode/model/project_file.dart';
import 'package:distinode/sim/components.dart';
import 'package:distinode/sim/engine.dart';
import 'package:distinode/sim/templates.dart';
import 'package:distinode/sim/types.dart';
import 'package:flutter_test/flutter_test.dart';

SimGraph graphOf(String id, {Map<String, bool> down = const {}, Map<String, Params> params = const {}, Set<String> cut = const {}}) {
  final t = templateById(id)!;
  return SimGraph(
    nodes: [
      for (final n in t.nodes)
        SimNode(
          id: n.key,
          kind: n.kind,
          params: {...specOf(n.kind).defaults, ...n.params, ...?params[n.key]},
          down: down[n.key] ?? false,
        ),
    ],
    edges: [
      for (final e in t.edges)
        SimEdge(
          id: '${e.from}>${e.to}',
          source: e.from,
          target: e.to,
          travelTime: 0.3,
          latencyMs: e.latencyMs ?? 0,
          down: cut.contains('${e.from}>${e.to}'),
        ),
    ],
  );
}

void steps(Engine e, int n) {
  for (var i = 0; i < n; i++) {
    e.step();
  }
}

void main() {
  group('plantillas', () {
    test('tienen claves únicas y aristas válidas', () {
      expect(templates.length, 14);
      for (final t in templates) {
        final keys = t.nodes.map((n) => n.key).toSet();
        expect(keys.length, t.nodes.length, reason: t.id);
        for (final e in t.edges) {
          expect(keys.contains(e.from), isTrue, reason: '${t.id}: ${e.from}');
          expect(keys.contains(e.to), isTrue, reason: '${t.id}: ${e.to}');
        }
      }
    });

    for (final t in templates) {
      test('«${t.name}» arranca sana con su tráfico por defecto', () {
        final e = Engine(seed: 11);
        e.setGraph(graphOf(t.id));
        e.setTraffic(t.traffic);
        steps(e, 1200);
        final m = e.metrics();
        expect(m.errorRate, lessThan(0.02), reason: t.id);
        expect(m.throughput, greaterThan(t.traffic * 0.85), reason: t.id);
        expect(m.backlog, lessThan(150), reason: t.id);
      });
    }

    test('la tormenta de reintentos colapsa con un poco más de tráfico', () {
      final e = Engine(seed: 3);
      e.setGraph(graphOf('tormenta-de-reintentos'));
      e.setTraffic(58);
      steps(e, 1500);
      expect(e.metrics().retryRate, greaterThan(15));
      expect(e.metrics().errorRate, greaterThan(0.2));
    });

    test('streaming: sin la CDN el origen se hunde', () {
      final e = Engine(seed: 4);
      e.setGraph(graphOf('streaming-video', params: {'cdn': {ParamKey.hitRate: 50}}));
      e.setTraffic(200);
      steps(e, 1000);
      expect(e.nodeStats('p1')!.status, Health.hot);
      expect(e.metrics().errorRate, greaterThan(0.1));
    });

    test('mensajería: con la base de datos caída no se pierde ningún mensaje', () {
      final e = Engine(seed: 4);
      e.setGraph(graphOf('mensajeria'));
      e.setTraffic(150);
      steps(e, 300);
      e.setGraph(graphOf('mensajeria', down: {'db': true}));
      steps(e, 1000);
      expect(e.metrics().errorRate, 0);
      final stuck = e.metrics().backlog;
      expect(stuck, greaterThan(500));
      e.setGraph(graphOf('mensajeria'));
      steps(e, 2500);
      expect(e.metrics().backlog, lessThan(stuck / 4));
    });

    test('dos regiones: si se corta Europa, todo va a América con más latencia', () {
      final e = Engine(seed: 4);
      e.setGraph(graphOf('multi-region'));
      e.setTraffic(80);
      steps(e, 600);
      final before = e.metrics().avgLatencyMs;
      e.setGraph(graphOf('multi-region', cut: {'glb>eu'}));
      steps(e, 600);
      expect(e.nodeStats('eu')!.arrivalRate, 0);
      expect(e.metrics().errorRate, 0);
      expect(e.metrics().avgLatencyMs, greaterThan(before + 60));
    });
  });

  group('proyectos', () {
    ({Map<String, NodeData> nodes, Map<String, EdgeData> edges}) diagramOf(String id) {
      final b = buildTemplate(templateById(id)!);
      return (nodes: {for (final n in b.nodes) n.id: n}, edges: {for (final e in b.edges) e.id: e});
    }

    test('guardar y volver a abrir conserva el diagrama (con ids nuevos)', () {
      final d = diagramOf('multi-region');
      final file = jsonDecode(
        jsonEncode(
          toProject(
            name: 'Mi proyecto',
            nodes: d.nodes,
            edges: d.edges,
            sim: const SimShared(running: true, traffic: 120, chaos: true),
          ),
        ),
      );
      final r = parseProject(file);
      expect(r.name, 'Mi proyecto');
      expect(r.nodes.length, d.nodes.length);
      expect(r.edges.length, d.edges.length);
      expect(r.sim.traffic, 120);
      expect(r.sim.chaos, isTrue);
      expect(r.edges.any((e) => e.latencyMs == 80), isTrue);
      final a = r.nodes.map((n) => n.label).toList()..sort();
      final b = d.nodes.values.map((n) => n.label).toList()..sort();
      expect(a, b);
      expect(r.nodes.every((n) => !d.nodes.containsKey(n.id)), isTrue);
      final ids = r.nodes.map((n) => n.id).toSet();
      expect(r.edges.every((e) => ids.contains(e.source) && ids.contains(e.target)), isTrue);
    });

    test('no guarda las caídas temporales del caos', () {
      final d = diagramOf('basico');
      final list = d.nodes.values.toList();
      final a = list[0].copyWith(down: true, downUntil: DateTime.now().millisecondsSinceEpoch + 5000);
      final b = list[1].copyWith(down: true);
      final nodes = {...d.nodes, a.id: a, b.id: b};
      final file = toProject(name: 'x', nodes: nodes, edges: d.edges, sim: const SimShared());
      final fileNodes = (file['nodes'] as List).cast<Map<String, Object?>>();
      expect(fileNodes.firstWhere((n) => n['id'] == a.id)['down'], isNull);
      expect(fileNodes.firstWhere((n) => n['id'] == b.id)['down'], isTrue);
    });

    test('rechaza archivos que no son proyectos', () {
      expect(() => parseProject(null), throwsA(isA<ProjectParseError>()));
      expect(() => parseProject({'app': 'otra'}), throwsA(isA<ProjectParseError>()));
      expect(
        () => parseProject({'app': 'distinode', 'version': 99, 'nodes': [], 'edges': []}),
        throwsA(isA<ProjectParseError>()),
      );
      expect(
        () => parseProject({
          'app': 'distinode',
          'version': 1,
          'nodes': [
            {'id': 'a', 'kind': 'nave-espacial'},
          ],
          'edges': [],
        }),
        throwsA(isA<ProjectParseError>()),
      );
      expect(
        () => parseProject({
          'app': 'distinode',
          'version': 1,
          'nodes': [
            {'id': 'a', 'kind': 'server', 'label': 'S', 'x': 0, 'y': 0},
          ],
          'edges': [
            {'id': 'e', 'source': 'a', 'target': 'fantasma'},
          ],
        }),
        throwsA(isA<ProjectParseError>()),
      );
    });

    test('acota los valores fuera de rango', () {
      final r = parseProject({
        'app': 'distinode',
        'version': 1,
        'name': '  ',
        'sim': {'traffic': 99999},
        'nodes': [
          {
            'id': 'a',
            'kind': 'server',
            'label': '<b>x</b>' * 20,
            'x': 1e12,
            'y': 'no',
            'params': {'capacity': -5, 'queueMax': 1e9},
          },
        ],
        'edges': [],
      });
      final n = r.nodes.first;
      expect(n.params[ParamKey.capacity], 1);
      expect(n.params[ParamKey.queueMax], 5000);
      expect(n.label.length, lessThanOrEqualTo(40));
      expect(n.x, 1e6);
      expect(n.y, 0);
      expect(r.sim.traffic, 200);
      expect(r.name, 'Proyecto');
    });

    test('crea nombres de archivo seguros', () {
      expect(fileSlug('Práctica 3 — Caché/BD'), 'practica-3-cache-bd');
      expect(fileSlug('***'), 'diagrama');
    });
  });
}
