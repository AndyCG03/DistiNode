// Port de src/sim/engine.test.ts: mismas situaciones y mismos umbrales.
import 'package:distinode/sim/components.dart';
import 'package:distinode/sim/engine.dart';
import 'package:distinode/sim/rng.dart';
import 'package:distinode/sim/types.dart';
import 'package:flutter_test/flutter_test.dart';

SimNode node(String id, ComponentKind kind, [Params params = const {}, bool down = false]) =>
    SimNode(id: id, kind: kind, params: {...specOf(kind).defaults, ...params}, down: down);

SimEdge edge(String source, String target, [double travelTime = 0.1]) =>
    SimEdge(id: '$source>$target', source: source, target: target, travelTime: travelTime);

/// Cliente → Balanceador → Servidor(es) → Base de datos
SimGraph example(int servers, {List<String> serverDown = const []}) {
  final nodes = [node('c', ComponentKind.client), node('lb', ComponentKind.balancer), node('db', ComponentKind.database)];
  final edges = [edge('c', 'lb')];
  for (var i = 1; i <= servers; i++) {
    final id = 's$i';
    nodes.add(node(id, ComponentKind.server, const {}, serverDown.contains(id)));
    edges.addAll([edge('lb', id), edge(id, 'db')]);
  }
  return SimGraph(nodes: nodes, edges: edges);
}

void run(Engine engine, double seconds) {
  final steps = (seconds / engine.dt).round();
  for (var i = 0; i < steps; i++) {
    engine.step();
  }
}

/// toBeCloseTo(x, -1) de Vitest: |a − b| < 5.
Matcher closeTo10(num v) => closeTo(v, 5);

void main() {
  group('rng', () {
    test('la misma semilla da la misma secuencia', () {
      final a = createRng(42);
      final b = createRng(42);
      final c = createRng(43);
      final sa = List.generate(5, (_) => a());
      expect(List.generate(5, (_) => b()), sa);
      expect(List.generate(5, (_) => c()), isNot(sa));
      for (final x in sa) {
        expect(x, greaterThanOrEqualTo(0));
        expect(x, lessThan(1));
      }
    });
  });

  group('paso fijo', () {
    test('advance acumula el tiempo real en pasos de dt', () {
      final e = Engine(dt: 0.01);
      expect(e.advance(0.025), 2);
      expect(e.advance(0.005), 1);
      expect(e.time, closeTo(0.03, 1e-10));
    });

    test('no intenta recuperar más de maxFrame tras una pausa larga', () {
      final e = Engine(dt: 0.01);
      expect(e.advance(10), (maxFrame / 0.01).round());
    });

    test('es determinista con la misma semilla', () {
      SimGraph g() => SimGraph(
        nodes: [
          node('c', ComponentKind.client),
          node('k', ComponentKind.cache, {ParamKey.hitRate: 50}),
          node('db', ComponentKind.database),
        ],
        edges: [edge('c', 'k'), edge('k', 'db')],
      );
      final a = Engine(seed: 7);
      final b = Engine(seed: 7);
      for (final e in [a, b]) {
        e.setGraph(g());
        e.setTraffic(80);
        run(e, 5);
      }
      expect(a.metrics(), b.metrics());
      expect(a.nodeStats('db'), b.nodeStats('db'));
    });
  });

  group('flujo básico', () {
    test('con poco tráfico todo responde, sin errores y en verde', () {
      final e = Engine();
      e.setGraph(example(1));
      e.setTraffic(20);
      run(e, 10);
      final m = e.metrics();
      expect(m.throughput, inExclusiveRange(17, 23));
      expect(m.errorRate, 0);
      // 80 ms en el servidor + 25 ms en la base de datos
      expect(m.avgLatencyMs, inExclusiveRange(95, 130));
      expect(e.nodeStats('s1')!.status, Health.ok);
      expect(e.nodeStats('db')!.status, Health.ok);
    });

    test('hay trenes de petición y de respuesta en tránsito', () {
      final e = Engine();
      e.setGraph(example(1));
      e.setTraffic(50);
      run(e, 3);
      final kinds = e.trains().map((t) => t.kind).toSet();
      expect(kinds.contains(TrainKind.request), isTrue);
      expect(kinds.contains(TrainKind.response), isTrue);
      for (final t in e.trains()) {
        expect(t.progress, inInclusiveRange(0, 1));
      }
    });

    test('sin tráfico los nodos quedan en reposo', () {
      final e = Engine();
      e.setGraph(example(1));
      e.setTraffic(0);
      run(e, 2);
      expect(e.trains(), isEmpty);
      expect(e.nodeStats('s1')!.status, Health.idle);
    });
  });

  group('saturación', () {
    test('con más tráfico que capacidad el servidor se pone rojo, sube la latencia y aparecen errores', () {
      final e = Engine();
      e.setGraph(example(1));
      e.setTraffic(120);
      run(e, 12);
      final s = e.nodeStats('s1')!;
      expect(s.status, Health.hot);
      expect(s.rho, greaterThan(1));
      expect(s.queue, greaterThan(s.queueMax * 0.5));
      final m = e.metrics();
      expect(m.errorRate, greaterThan(0.3));
      expect(m.avgLatencyMs, greaterThan(400));
      expect(m.throughput, lessThan(55));
    });

    test('cerca del límite se pone ámbar', () {
      final e = Engine();
      e.setGraph(example(1));
      e.setTraffic(44);
      run(e, 8);
      expect(e.nodeStats('s1')!.status, Health.warn);
    });

    test('un segundo servidor detrás del balanceador lo devuelve a verde', () {
      final e = Engine();
      e.setGraph(example(1));
      e.setTraffic(70);
      run(e, 8);
      expect(e.nodeStats('s1')!.status, Health.hot);
      e.setGraph(example(2));
      run(e, 10);
      expect(e.nodeStats('s1')!.status, Health.ok);
      expect(e.nodeStats('s2')!.status, Health.ok);
      expect(e.nodeStats('s1')!.arrivalRate, closeTo10(35));
      final m = e.metrics();
      expect(m.errorRate, 0);
      expect(m.throughput, greaterThan(64));
    });
  });

  group('caídas y chequeo de salud', () {
    test('al tumbar un servidor hay errores y, tras el chequeo, el balanceador lo esquiva', () {
      final e = Engine();
      e.setGraph(example(2));
      e.setTraffic(40);
      run(e, 5);
      expect(e.metrics().errorRate, 0);
      e.setGraph(example(2, serverDown: ['s1']));
      run(e, 0.5);
      expect(e.metrics().errorRate, greaterThan(0));
      run(e, 1);
      expect(e.nodeStats('s1')!.status, Health.down);
      run(e, 3);
      final m = e.metrics();
      expect(m.errorRate, 0);
      expect(m.throughput, greaterThan(35));
      expect(e.nodeStats('s1')!.arrivalRate, 0);
      expect(e.nodeStats('s2')!.arrivalRate, greaterThan(35));
    });

    test('al revivirlo vuelve a recibir tráfico', () {
      final e = Engine();
      e.setGraph(example(2, serverDown: ['s1']));
      e.setTraffic(40);
      run(e, 3);
      e.setGraph(example(2));
      run(e, 3);
      expect(e.nodeStats('s1')!.arrivalRate, greaterThan(15));
    });

    test('sin destinos sanos el balanceador falla las peticiones', () {
      final e = Engine();
      e.setGraph(example(1, serverDown: ['s1']));
      e.setTraffic(20);
      run(e, 4);
      expect(e.metrics().errorRate, 1);
      expect(e.nodeStats('lb')!.status, Health.hot);
      expect(e.trains().any((t) => t.kind == TrainKind.error), isTrue);
    });

    test('lo que había en la cola de un nodo que cae, falla', () {
      final e = Engine();
      e.setGraph(example(1));
      e.setTraffic(150);
      run(e, 4);
      expect(e.nodeStats('s1')!.queue, greaterThan(0));
      e.setGraph(example(1, serverDown: ['s1']));
      expect(e.nodeStats('s1')!.queue, 0);
      expect(e.trains().where((t) => t.kind == TrainKind.error).length, greaterThan(10));
    });
  });

  test('caché: con 70 % de aciertos solo ~30 % llega a la base de datos', () {
    final e = Engine(seed: 3);
    e.setGraph(
      SimGraph(
        nodes: [
          node('c', ComponentKind.client),
          node('k', ComponentKind.cache, {ParamKey.hitRate: 70}),
          node('db', ComponentKind.database),
        ],
        edges: [edge('c', 'k'), edge('k', 'db')],
      ),
    );
    e.setTraffic(100);
    run(e, 10);
    final ratio = e.nodeStats('db')!.arrivalRate / e.nodeStats('k')!.arrivalRate;
    expect(ratio, inExclusiveRange(0.2, 0.4));
  });

  group('cambios del grafo', () {
    test('borrar un nodo con tráfico en vuelo no rompe nada', () {
      final e = Engine();
      e.setGraph(example(2));
      e.setTraffic(60);
      run(e, 3);
      final g = example(2);
      e.setGraph(
        SimGraph(
          nodes: g.nodes.where((n) => n.id != 's2').toList(),
          edges: g.edges.where((ed) => ed.source != 's2' && ed.target != 's2').toList(),
        ),
      );
      expect(() => run(e, 3), returnsNormally);
      expect(e.nodeStats('s2'), isNull);
      expect(e.trains().every((t) => !t.edgeId.contains('s2')), isTrue);
    });

    test('un ciclo no se queda dando vueltas para siempre', () {
      final e = Engine();
      e.setGraph(
        SimGraph(
          nodes: [node('c', ComponentKind.client), node('a', ComponentKind.balancer), node('b', ComponentKind.balancer)],
          edges: [edge('c', 'a', 0.01), edge('a', 'b', 0.01), edge('b', 'a', 0.01)],
        ),
      );
      e.setTraffic(10);
      run(e, 5);
      expect(e.metrics().errorRate, 1);
    });

    test('reset vuelve a t = 0 y conserva el grafo', () {
      final e = Engine();
      e.setGraph(example(1));
      e.setTraffic(30);
      run(e, 2);
      e.reset();
      expect(e.time, 0);
      expect(e.trains(), isEmpty);
      expect(e.nodeStats('s1'), isNotNull);
    });
  });

  group('componentes', () {
    test('el API Gateway rechaza lo que pasa de su límite', () {
      final e = Engine();
      e.setGraph(
        SimGraph(
          nodes: [
            node('c', ComponentKind.client),
            node('g', ComponentKind.gateway, {ParamKey.rateLimit: 50}),
            node('s', ComponentKind.server, {ParamKey.capacity: 200}),
          ],
          edges: [edge('c', 'g'), edge('g', 's')],
        ),
      );
      e.setTraffic(100);
      run(e, 6);
      final m = e.metrics();
      expect(m.errorRate, inExclusiveRange(0.4, 0.6));
      expect(m.throughput, closeTo10(50));
      expect(e.nodeStats('g')!.status, Health.hot);
      expect(e.nodeStats('s')!.arrivalRate, lessThan(55));
    });

    test('una CDN con 80 % de aciertos solo deja pasar ~20 %', () {
      final e = Engine(seed: 5);
      e.setGraph(
        SimGraph(
          nodes: [
            node('c', ComponentKind.client),
            node('cdn', ComponentKind.cdn, {ParamKey.hitRate: 80}),
            node('s', ComponentKind.server),
          ],
          edges: [edge('c', 'cdn'), edge('cdn', 's')],
        ),
      );
      e.setTraffic(100);
      run(e, 8);
      final ratio = e.nodeStats('s')!.arrivalRate / e.nodeStats('cdn')!.arrivalRate;
      expect(ratio, inExclusiveRange(0.12, 0.28));
    });

    test('una cola responde al momento y los workers procesan a su ritmo', () {
      final e = Engine();
      e.setGraph(
        SimGraph(
          nodes: [
            node('c', ComponentKind.client),
            node('q', ComponentKind.queue, {ParamKey.queueMax: 1000}),
            node('w', ComponentKind.worker, {ParamKey.capacity: 10, ParamKey.processingMs: 100}),
          ],
          edges: [edge('c', 'q'), edge('q', 'w')],
        ),
      );
      e.setTraffic(40);
      run(e, 10);
      final m = e.metrics();
      expect(m.errorRate, 0);
      expect(m.throughput, greaterThan(35));
      expect(m.avgLatencyMs, lessThan(20));
      expect(m.asyncThroughput, closeTo10(10));
      expect(m.backlog, greaterThan(200));
    });

    test('si un worker cae, sus mensajes vuelven a la cola y se procesan al revivir', () {
      SimGraph g(bool down) => SimGraph(
        nodes: [
          node('c', ComponentKind.client),
          node('q', ComponentKind.queue),
          node('w', ComponentKind.worker, const {}, down),
        ],
        edges: [edge('c', 'q'), edge('q', 'w')],
      );
      final e = Engine();
      e.setGraph(g(false));
      e.setTraffic(20);
      run(e, 3);
      e.setGraph(g(true));
      run(e, 3);
      expect(e.metrics().asyncThroughput, 0);
      final waiting = e.metrics().backlog;
      expect(waiting, greaterThan(50));
      expect(e.metrics().errorRate, 0);
      e.setGraph(g(false));
      run(e, 6);
      expect(e.metrics().asyncThroughput, greaterThan(15));
      expect(e.metrics().backlog, lessThan(waiting));
    });

    test('en modo «a todos» el servidor espera al más lento y falla si falla uno', () {
      SimGraph g(bool dbDown) => SimGraph(
        nodes: [
          node('c', ComponentKind.client),
          node('s', ComponentKind.server, {ParamKey.fanout: 1, ParamKey.capacity: 100}),
          node('a', ComponentKind.database, {ParamKey.processingMs: 20}),
          node('b', ComponentKind.database, {ParamKey.processingMs: 200, ParamKey.capacity: 200}, dbDown),
        ],
        edges: [edge('c', 's'), edge('s', 'a'), edge('s', 'b')],
      );
      final e = Engine();
      e.setGraph(g(false));
      e.setTraffic(20);
      run(e, 6);
      final lat = e.metrics().avgLatencyMs;
      expect(lat, inExclusiveRange(280, 330));
      expect(e.metrics().errorRate, 0);
      e.setGraph(g(true));
      run(e, 4);
      expect(e.metrics().errorRate, 1);
    });

    test('menos conexiones manda más tráfico al servidor rápido', () {
      SimGraph g(double algo) => SimGraph(
        nodes: [
          node('c', ComponentKind.client),
          node('lb', ComponentKind.balancer, {ParamKey.lbAlgorithm: algo}),
          node('fast', ComponentKind.server, {ParamKey.capacity: 100, ParamKey.processingMs: 20}),
          node('slow', ComponentKind.server, {ParamKey.capacity: 100, ParamKey.processingMs: 300}),
        ],
        edges: [edge('c', 'lb'), edge('lb', 'fast'), edge('lb', 'slow')],
      );
      double share(double algo) {
        final e = Engine();
        e.setGraph(g(algo));
        e.setTraffic(80);
        run(e, 8);
        final f = e.nodeStats('fast')!.arrivalRate;
        return f / (f + e.nodeStats('slow')!.arrivalRate);
      }

      expect(share(0), closeTo(0.5, 0.05));
      expect(share(1), greaterThan(0.6));
    });
  });

  group('tiempos de espera, reintentos y degradación', () {
    SimGraph saturated(Params client) => SimGraph(
      nodes: [
        node('c', ComponentKind.client, client),
        node('s', ComponentKind.server, {ParamKey.capacity: 50, ParamKey.queueMax: 200}),
      ],
      edges: [edge('c', 's')],
    );

    test('con poco tiempo de espera, la cola de un servidor saturado se convierte en errores', () {
      final strict = Engine();
      strict.setGraph(saturated({ParamKey.timeoutMs: 300}));
      strict.setTraffic(70);
      run(strict, 10);
      final patient = Engine();
      patient.setGraph(saturated({ParamKey.timeoutMs: 0}));
      patient.setTraffic(70);
      run(patient, 10);
      expect(strict.metrics().errorRate, greaterThan(patient.metrics().errorRate + 0.1));
      expect(strict.metrics().p95LatencyMs, lessThanOrEqualTo(300));
    });

    test('los reintentos multiplican la carga sobre un servidor saturado (tormenta de reintentos)', () {
      final calm = Engine();
      calm.setGraph(saturated({ParamKey.timeoutMs: 500, ParamKey.retries: 0}));
      calm.setTraffic(60);
      run(calm, 10);
      final storm = Engine();
      storm.setGraph(saturated({ParamKey.timeoutMs: 500, ParamKey.retries: 3}));
      storm.setTraffic(60);
      run(storm, 10);
      expect(storm.metrics().retryRate, greaterThan(10));
      expect(storm.nodeStats('s')!.arrivalRate, greaterThan(calm.nodeStats('s')!.arrivalRate * 1.3));
    });

    test('un reintento salva los fallos sueltos', () {
      SimGraph g(double retries, bool bDown) => SimGraph(
        nodes: [
          node('c', ComponentKind.client, {ParamKey.retries: retries}),
          node('lb', ComponentKind.balancer, {ParamKey.healthCheckMs: 10000}),
          node('a', ComponentKind.server),
          node('b', ComponentKind.server, const {}, bDown),
        ],
        edges: [edge('c', 'lb'), edge('lb', 'a'), edge('lb', 'b')],
      );
      Engine withRetries(double retries) {
        final e = Engine();
        e.setGraph(g(retries, false));
        e.setTraffic(20);
        run(e, 1);
        e.setGraph(g(retries, true));
        run(e, 4);
        return e;
      }

      expect(withRetries(0).metrics().errorRate, greaterThan(0.3));
      expect(withRetries(3).metrics().errorRate, lessThan(0.12));
    });

    test('un servidor degradado procesa cuatro veces más lento', () {
      final e = Engine();
      e.setGraph(
        SimGraph(
          nodes: [
            node('c', ComponentKind.client),
            node('s', ComponentKind.server, {ParamKey.capacity: 100}).copyWith(slow: true),
          ],
          edges: [edge('c', 's')],
        ),
      );
      e.setTraffic(10);
      run(e, 5);
      expect(e.metrics().avgLatencyMs, greaterThan(300));
      expect(e.nodeStats('s')!.status, Health.warn);
    });

    test('una línea cortada falla y el balanceador la esquiva tras el chequeo', () {
      SimGraph g(bool cut) {
        final base = example(2);
        return SimGraph(
          nodes: base.nodes,
          edges: base.edges.map((ed) => ed.id == 'lb>s1' ? ed.copyWith(down: cut) : ed).toList(),
        );
      }

      final e = Engine();
      e.setGraph(g(false));
      e.setTraffic(40);
      run(e, 3);
      e.setGraph(g(true));
      run(e, 0.5);
      expect(e.metrics().errorRate, greaterThan(0));
      run(e, 3);
      expect(e.metrics().errorRate, 0);
      expect(e.nodeStats('s1')!.arrivalRate, 0);
    });

    test('la latencia de red de una línea cuenta en ida y vuelta', () {
      double lat(double ms) {
        final e = Engine();
        e.setGraph(
          SimGraph(
            nodes: [node('c', ComponentKind.client), node('s', ComponentKind.server)],
            edges: [edge('c', 's').copyWith(latencyMs: ms)],
          ),
        );
        e.setTraffic(10);
        run(e, 6);
        return e.metrics().avgLatencyMs;
      }

      expect(lat(50) - lat(0), closeTo10(100));
    });

    test('la sobrecarga sostenida se mide para que el supervisor pueda tumbar el nodo', () {
      final e = Engine();
      e.setGraph(example(1));
      e.setTraffic(150);
      run(e, 8);
      expect(e.nodeStats('s1')!.overloadFor, greaterThan(3));
      e.setTraffic(5);
      run(e, 8);
      expect(e.nodeStats('s1')!.overloadFor, 0);
    });
  });

  test('registro: numera las etiquetas con el primer hueco libre', () {
    expect(nextLabel(ComponentKind.server, []), 'Servidor 1');
    expect(nextLabel(ComponentKind.server, ['Servidor 1', 'Servidor 3']), 'Servidor 2');
    expect(nextLabel(ComponentKind.client, []), 'Cliente');
    expect(nextLabel(ComponentKind.client, ['Cliente']), 'Cliente 1');
    expect(nextLabel(ComponentKind.gateway, []), 'API Gateway');
  });
}
