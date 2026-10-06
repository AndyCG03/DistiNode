/// Motor de simulación de DistiNode. Dart puro: sin Flutter.
/// Port fiel de `src/sim/engine.ts`.
///
/// - Paso fijo (`dt`, 10 ms por defecto) con acumulador: `advance(segundosReales)`.
/// - PRNG con semilla: mismas entradas → mismos resultados (útil para pruebas, lecciones y misiones).
/// - Las peticiones viajan por las aristas; la respuesta vuelve por la misma ruta en sentido contrario.
///
/// Dos relojes:
/// - Tiempo de pared (`now`): lo que tardan los trenes en recorrer las líneas. Es "cámara lenta" para que se vea.
/// - Tiempo simulado (`Request.sim`): espera + proceso + latencia de red. Es lo que miden las métricas
///   y lo que agota los tiempos de espera de los clientes.
library;

import 'dart:math' as math;

import 'components.dart';
import 'rng.dart';
import 'types.dart';

const double defaultDt = 0.01;
const double defaultTravel = 0.35;

/// Si la ventana se congela, no intentamos recuperar más de esto de golpe.
const double maxFrame = 0.25;
const int maxHops = 24;

/// Latencia de red base por salto, en ms simulados.
const double netMs = 1;

/// Un nodo degradado procesa así de lento…
const double slowFactor = 4;

/// …o, si no tiene capacidad propia, añade este retraso (s).
const double slowDelay = 0.15;

/// Prefetch de una cola hacia consumidores sin capacidad propia.
const int _defaultPrefetch = 4;

/// Coste fijo (s simulados) de los componentes que no hacen cola.
const Map<ComponentKind, double> _instant = {
  ComponentKind.cdn: 0.002,
  ComponentKind.gateway: 0.002,
  ComponentKind.cache: 0.001,
  ComponentKind.queue: 0.001,
};
const double _metricsWindow = 2;
const double _bucket = 0.1;
const int _buckets = 10; // ventana de 1 s para las tasas por nodo
const int _timeoutCheckEvery = 5; // pasos

class Thresholds {
  static const double warnRho = 0.8;
  static const double hotRho = 1;
  static const double warnQueue = 0.15;
  static const double hotQueue = 0.5;
  static const double overloadQueue = 0.8;
}

class _Hop {
  final String node;
  final String edge;
  const _Hop(this.node, this.edge);
}

enum _ReqKind { client, child, async }

/// Una petición de cliente con sus intentos.
class _Logical {
  final String client;
  int attempt = 0;
  final int retries;

  /// Tiempo de espera en s simulados (0 = sin límite).
  final double timeout;

  /// Tiempo simulado consumido por intentos anteriores y esperas entre reintentos.
  double base = 0;
  _Request? current;
  bool settled = false;

  _Logical({required this.client, required this.retries, required this.timeout});
}

class _Request {
  final int id;
  final _ReqKind kind;

  /// Nodo donde nació: el cliente, el servidor que hizo fan-out o la cola.
  final String origin;
  List<_Hop> path = [];
  bool error = false;

  /// Segundos simulados acumulados.
  double sim = 0;

  /// Desde cuándo espera en una cola (tiempo de pared), o null.
  double? queuedAt;
  _Logical? logical;

  /// El cliente ya se rindió con este intento: su respuesta se ignora.
  bool abandoned = false;
  _Request? parent;
  List<_Request>? children;
  double? childMax;
  bool childError = false;
  bool done = false;

  /// Mensaje de cola: worker que lo tiene.
  String? consumer;

  /// Mensaje de cola: ocupa un hueco del prefetch de su consumidor hasta que este termina de procesarlo.
  bool credit = false;

  _Request(this.id, this.kind, this.origin);
}

class _Transit {
  final int id;
  final _Request req;
  final String edge;
  final int dir; // 1 ida, -1 vuelta
  final TrainKind kind;
  final double depart;
  final double arrive;
  const _Transit(this.id, this.req, this.edge, this.dir, this.kind, this.depart, this.arrive);
}

class _Job {
  final _Request req;
  final double doneAt;
  const _Job(this.req, this.doneAt);
}

class _Timer {
  final double at;
  final void Function() fn;
  const _Timer(this.at, this.fn);
}

class _NodeState {
  SimNode node;
  int rr = 0;
  List<_Request> queue = [];
  List<_Job> busy = [];
  final List<int> arrivals = List.filled(_buckets, 0);
  final List<int> drops = List.filled(_buckets, 0);
  double overloadFor = 0;
  // cliente
  double nextEmit;
  List<_Logical> pending = [];
  // balanceador
  final Map<String, bool> healthy = {};
  double nextCheck;
  final Map<String, int> outstanding = {};
  // API gateway
  double tokens;
  // cola de mensajes
  List<_Request> backlog = [];
  final Map<String, int> inflight = {};

  _NodeState(this.node, double now, this.tokens) : nextEmit = now, nextCheck = now;
}

class _Done {
  final double t;
  final double latency;
  final bool error;
  const _Done(this.t, this.latency, this.error);
}

class Engine {
  final double dt;
  late Rng _rng;
  final int _seed;
  double _now = 0;
  double _acc = 0;
  int _steps = 0;
  double _traffic = 20;
  int _nextId = 1;
  Map<String, _NodeState> _nodes = {};
  Map<String, SimEdge> _edges = {};
  Map<String, List<SimEdge>> _out = {};
  List<_Transit> _transits = [];
  List<_Timer> _timers = [];
  int _bucketIdx = 0;
  final List<_Done> _done = [];
  final List<double> _retryLog = [];
  final List<double> _asyncLog = [];

  Engine({int seed = 1, this.dt = defaultDt}) : _seed = seed {
    _rng = createRng(_seed);
  }

  double get time => _now;

  /// Vuelve a t = 0 sin tráfico en vuelo, conservando el grafo.
  void reset() {
    _rng = createRng(_seed);
    _now = 0;
    _acc = 0;
    _steps = 0;
    _nextId = 1;
    _transits = [];
    _timers = [];
    _done.clear();
    _retryLog.clear();
    _asyncLog.clear();
    _bucketIdx = 0;
    for (final id in _nodes.keys.toList()) {
      _nodes[id] = _freshState(_nodes[id]!.node);
    }
  }

  void setTraffic(double rps) {
    _traffic = math.max(0, rps);
  }

  /// Sustituye el grafo conservando el estado de los nodos que siguen existiendo.
  void setGraph(SimGraph graph) {
    final next = <String, _NodeState>{};
    for (final n in graph.nodes) {
      final prev = _nodes[n.id];
      if (prev != null) {
        final wentDown = !prev.node.down && n.down;
        prev.node = n;
        if (wentDown) _crash(prev);
        next[n.id] = prev;
      } else {
        next[n.id] = _freshState(n);
      }
    }
    final removed = _nodes.entries.where((e) => !next.containsKey(e.key)).map((e) => e.value).toList();
    _nodes = next;

    _edges = {};
    _out = {};
    for (final e in graph.edges) {
      if (!next.containsKey(e.source) || !next.containsKey(e.target) || e.source == e.target) continue;
      _edges[e.id] = e;
      (_out[e.source] ??= []).add(e);
    }

    // Lo que había dentro de nodos borrados o viajando por aristas borradas se pierde.
    for (final s in removed) {
      for (final r in [...s.queue, ...s.busy.map((j) => j.req)]) {
        _lose(r);
      }
    }
    final lost = <_Request>[];
    _transits = _transits.where((m) {
      if (_edges.containsKey(m.edge)) return true;
      lost.add(m.req);
      return false;
    }).toList();
    for (final r in lost) {
      _lose(r);
    }
  }

  /// Avanza `seconds` de tiempo real en pasos fijos. Devuelve cuántos pasos dio.
  int advance(double seconds) {
    _acc += math.min(math.max(seconds, 0), maxFrame);
    var steps = 0;
    // El épsilon evita perder un paso por errores de coma flotante al acumular.
    while (_acc >= dt - 1e-9) {
      step();
      _acc = math.max(0, _acc - dt);
      steps++;
    }
    return steps;
  }

  void step() {
    _now += dt;
    _steps++;
    final now = _now;
    _rollBuckets();

    // 1. Temporizadores (reintentos, retrasos de nodos lentos).
    if (_timers.isNotEmpty) {
      final due = _timers.where((t) => t.at <= now).toList();
      if (due.isNotEmpty) {
        _timers = _timers.where((t) => t.at > now).toList();
        for (final t in due) {
          t.fn();
        }
      }
    }

    // 2. Llegadas.
    if (_transits.any((m) => m.arrive <= now)) {
      final arrived = <_Transit>[];
      _transits = _transits.where((m) {
        if (m.arrive > now) return true;
        arrived.add(m);
        return false;
      }).toList();
      arrived.sort((a, b) {
        final c = a.arrive.compareTo(b.arrive);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
      for (final m in arrived) {
        if (m.dir == 1) {
          _onRequest(m);
        } else {
          _onResponse(m);
        }
      }
    }

    // 3. Clientes generan tráfico (llegadas regulares con algo de variación).
    final clients = _nodes.values
        .where((s) => s.node.kind == ComponentKind.client && !s.node.down && _out.containsKey(s.node.id))
        .toList();
    final perClient = clients.isNotEmpty ? _traffic / clients.length : 0.0;
    for (final s in clients) {
      if (perClient <= 0) continue;
      if (s.nextEmit < now - 1) s.nextEmit = now; // venía de pausa o de 0 pet/s
      while (s.nextEmit <= now) {
        _newLogical(s);
        s.nextEmit += (0.5 + _rng()) / perClient;
      }
    }

    for (final s in _nodes.values) {
      final kind = s.node.kind;
      // 4. Servidores, workers y bases de datos: terminan trabajos y sacan de la cola.
      if (hasCapacity(kind) && !s.node.down) {
        if (s.busy.isNotEmpty) {
          final finished = <_Job>[];
          final still = <_Job>[];
          for (final j in s.busy) {
            (j.doneAt <= now + 1e-9 ? finished : still).add(j);
          }
          if (finished.isNotEmpty) {
            s.busy = still;
            _stableSortBy(finished, (j) => j.doneAt);
            for (final j in finished) {
              _afterService(s, j.req);
              // El trabajador libre toma el siguiente en el instante exacto en que terminó, no al final del
              // paso: si no, la discretización le robaría hasta un paso por trabajo a la capacidad.
              if (s.queue.isNotEmpty && !s.node.down) _startFromQueue(s, j.doneAt);
            }
          }
        }
        _fillWorkers(s);
      }
      // 5. Colas de mensajes: entregan a sus consumidores según su capacidad libre.
      if (kind == ComponentKind.queue && !s.node.down) _dispatch(s);
      // 6. API gateway: rellena fichas.
      if (kind == ComponentKind.gateway) {
        final rate = paramValue(ComponentKind.gateway, s.node.params, ParamKey.rateLimit);
        s.tokens = math.min(rate, s.tokens + rate * dt);
      }
      // 7. Balanceadores: chequeo de salud.
      if (kind == ComponentKind.balancer && !s.node.down && s.nextCheck <= now) {
        for (final e in _out[s.node.id] ?? const <SimEdge>[]) {
          s.healthy[e.target] = !e.down && !_nodes[e.target]!.node.down;
        }
        s.nextCheck = now + paramValue(ComponentKind.balancer, s.node.params, ParamKey.healthCheckMs) / 1000;
      }
      // 8. Sobrecarga sostenida (la usa el supervisor para tumbar nodos).
      s.overloadFor = _isOverloaded(s) ? s.overloadFor + dt : 0;
    }

    // 9. Tiempos de espera de los clientes.
    if (_steps % _timeoutCheckEvery == 0) _checkTimeouts();

    // 10. Ventanas de métricas.
    final cutoff = now - _metricsWindow;
    _trimFront(_done, (d) => d.t < cutoff);
    _trimFront(_retryLog, (t) => t < cutoff);
    _trimFront(_asyncLog, (t) => t < cutoff);
  }

  // ── Consultas ────────────────────────────────────────────

  /// Mensajes en tránsito, con posición interpolada entre pasos.
  List<Train> trains() {
    final t = _now + _acc;
    return [
      for (final m in _transits)
        () {
          final span = m.arrive - m.depart;
          final f = ((t - m.depart) / (span == 0 ? 1 : span)).clamp(0.0, 1.0);
          return Train(m.id, m.edge, m.kind, m.dir == 1 ? f : 1 - f);
        }(),
    ];
  }

  int get trainCount => _transits.length;

  NodeStats? nodeStats(String id) {
    final s = _nodes[id];
    if (s == null) return null;
    final kind = s.node.kind;
    final params = s.node.params;
    final down = s.node.down;
    final span = math.min(_buckets * _bucket, math.max(_now, _bucket));
    final arrivalRate = _sum(s.arrivals) / span;
    final dropRate = _sum(s.drops) / span;
    final cap = hasCapacity(kind);
    final queueLen = kind == ComponentKind.queue ? s.backlog.length : s.queue.length;
    final queueMax = cap || kind == ComponentKind.queue ? paramValue(kind, params, ParamKey.queueMax) : 0.0;
    final limit = cap
        ? paramValue(kind, params, ParamKey.capacity)
        : kind == ComponentKind.gateway
        ? paramValue(kind, params, ParamKey.rateLimit)
        : 0.0;
    final rho = limit > 0 ? arrivalRate / limit : 0.0;
    final q = queueMax > 0 ? queueLen / queueMax : 0.0;
    final busy = kind == ComponentKind.queue ? _sum(s.inflight.values) : s.busy.length;

    Health status;
    if (down) {
      status = Health.down;
    } else if (arrivalRate == 0 && queueLen == 0 && busy == 0 && dropRate == 0) {
      status = Health.idle;
    } else if (dropRate > 0 || q > Thresholds.hotQueue || (cap && rho >= Thresholds.hotRho)) {
      status = Health.hot;
    } else if (q > Thresholds.warnQueue || rho >= Thresholds.warnRho || s.node.slow) {
      status = Health.warn;
    } else {
      status = Health.ok;
    }

    return NodeStats(
      arrivalRate: arrivalRate,
      dropRate: dropRate,
      queue: queueLen,
      queueMax: queueMax,
      busy: busy,
      workers: cap ? _workers(s) : 0,
      rho: rho,
      status: status,
      overloadFor: s.overloadFor,
    );
  }

  Metrics metrics() {
    final span = math.min(_metricsWindow, math.max(_now, dt));
    final ok = <double>[];
    var err = 0;
    for (final d in _done) {
      if (d.error) {
        err++;
      } else {
        ok.add(d.latency);
      }
    }
    var inFlight = _transits.length;
    var backlog = 0;
    for (final s in _nodes.values) {
      inFlight += s.queue.length + s.busy.length;
      backlog += s.backlog.length;
    }
    ok.sort();
    final avg = ok.isNotEmpty ? _sumD(ok) / ok.length : 0.0;
    final p95 = ok.isNotEmpty ? ok[math.min(ok.length - 1, (ok.length * 0.95).floor())] : 0.0;
    return Metrics(
      throughput: ok.length / span,
      avgLatencyMs: avg * 1000,
      p95LatencyMs: p95 * 1000,
      errorRate: ok.length + err > 0 ? err / (ok.length + err) : 0,
      retryRate: _retryLog.length / span,
      asyncThroughput: _asyncLog.length / span,
      backlog: backlog,
      inFlight: inFlight,
    );
  }

  // ── Clientes: intentos, reintentos y tiempos de espera ───

  void _newLogical(_NodeState s) {
    final logical = _Logical(
      client: s.node.id,
      retries: math.max(0, paramValue(ComponentKind.client, s.node.params, ParamKey.retries).round()),
      timeout: paramValue(ComponentKind.client, s.node.params, ParamKey.timeoutMs) / 1000,
    );
    if (logical.timeout > 0) s.pending.add(logical);
    _attempt(logical);
  }

  void _attempt(_Logical logical) {
    if (logical.settled) return;
    final s = _nodes[logical.client];
    final out = s != null && !s.node.down ? _out[s.node.id] : null;
    if (s == null || out == null || out.isEmpty) return _settle(logical, null);
    logical.attempt++;
    final req = _newRequest(_ReqKind.client, s.node.id);
    req.logical = logical;
    logical.current = req;
    _send(req, _pick(s, out), 1);
  }

  /// El intento actual falló (error o tiempo agotado): reintenta con espera exponencial o se rinde.
  void _attemptFailed(_Logical logical, _Request req) {
    if (req.abandoned) return;
    req.abandoned = true;
    if (logical.settled || !identical(logical.current, req)) return;
    logical.base += _simElapsed(req);
    if (logical.attempt <= logical.retries) {
      final backoff = 0.1 * math.pow(2, logical.attempt - 1) * (0.8 + 0.4 * _rng());
      logical.base += backoff;
      _retryLog.add(_now);
      _timers.add(_Timer(_now + backoff, () => _attempt(logical)));
    } else {
      _settle(logical, null);
    }
  }

  void _settle(_Logical logical, _Request? success) {
    if (logical.settled) return;
    logical.settled = true;
    _done.add(
      success != null ? _Done(_now, logical.base + _simElapsed(success), false) : _Done(_now, 0, true),
    );
  }

  void _checkTimeouts() {
    for (final s in _nodes.values) {
      if (s.node.kind != ComponentKind.client || s.pending.isEmpty) continue;
      s.pending = s.pending.where((l) => !l.settled).toList();
      for (final l in s.pending) {
        final cur = l.current;
        if (cur != null && !cur.abandoned && l.base + _simElapsed(cur) > l.timeout) _attemptFailed(l, cur);
      }
    }
  }

  /// Tiempo simulado de una petición hasta ahora, incluida la espera en cola y los hijos pendientes.
  double _simElapsed(_Request r) {
    var t = r.sim + (r.queuedAt != null ? _now - r.queuedAt! : 0);
    final children = r.children;
    if (children != null) {
      var m = r.childMax ?? 0;
      for (final c in children) {
        if (!c.done) m = math.max(m, _simElapsed(c));
      }
      t += m;
    }
    return t;
  }

  // ── Comportamiento de cada componente ────────────────────

  void _onRequest(_Transit m) {
    final edge = _edges[m.edge]!;
    final s = _nodes[edge.target]!;
    final req = m.req;
    req.path.add(_Hop(s.node.id, edge.id));
    _bump(s.arrivals);

    if (s.node.down || req.path.length > maxHops) return _fail(s, req);
    if (s.node.slow && !hasCapacity(s.node.kind)) {
      req.sim += slowDelay;
      _timers.add(_Timer(_now + slowDelay, () => s.node.down ? _fail(s, req) : _process(s, req)));
      return;
    }
    _process(s, req);
  }

  void _process(_NodeState s, _Request req) {
    final kind = s.node.kind;
    final params = s.node.params;
    req.sim += _instant[kind] ?? 0;
    final out = _out[s.node.id] ?? const <SimEdge>[];

    switch (kind) {
      case ComponentKind.balancer:
        final candidates = out.where((e) => !e.down && s.healthy[e.target] != false).toList();
        if (candidates.isEmpty) return _fail(s, req);
        SimEdge edge;
        if (paramValue(ComponentKind.balancer, params, ParamKey.lbAlgorithm) == 1) {
          final start = s.rr % candidates.length;
          s.rr++;
          edge = candidates[start];
          for (var i = 1; i < candidates.length; i++) {
            final e = candidates[(start + i) % candidates.length];
            if ((s.outstanding[e.target] ?? 0) < (s.outstanding[edge.target] ?? 0)) edge = e;
          }
        } else {
          edge = _pick(s, candidates);
        }
        s.outstanding[edge.target] = (s.outstanding[edge.target] ?? 0) + 1;
        return _send(req, edge, 1);
      case ComponentKind.gateway:
        if (s.tokens < 1) return _fail(s, req);
        s.tokens -= 1;
        return out.isNotEmpty ? _send(req, _pick(s, out), 1) : _respond(req);
      case ComponentKind.cdn:
      case ComponentKind.cache:
        final hit = _rng() * 100 < paramValue(kind, params, ParamKey.hitRate);
        if (hit || out.isEmpty) return _respond(req);
        return _send(req, _pick(s, out), 1);
      case ComponentKind.queue:
        if (s.backlog.length >= paramValue(ComponentKind.queue, params, ParamKey.queueMax)) return _fail(s, req);
        final msg = _newRequest(_ReqKind.async, s.node.id);
        msg.queuedAt = _now;
        s.backlog.add(msg);
        return _respond(req); // confirma al momento
      case ComponentKind.server:
      case ComponentKind.worker:
      case ComponentKind.database:
        if (s.busy.length < _workers(s)) return _startJob(s, req);
        if (s.queue.length < paramValue(kind, params, ParamKey.queueMax)) {
          req.queuedAt = _now;
          s.queue.add(req);
          return;
        }
        return _fail(s, req);
      case ComponentKind.client:
        return _respond(req);
    }
  }

  void _onResponse(_Transit m) {
    final edge = _edges[m.edge];
    final src = edge != null ? _nodes[edge.source] : null;
    if (edge != null && src?.node.kind == ComponentKind.balancer) {
      src!.outstanding[edge.target] = math.max(0, (src.outstanding[edge.target] ?? 0) - 1);
    }
    final req = m.req;
    if (req.path.isNotEmpty) req.path.removeLast();
    if (req.path.isEmpty) return _arrived(req);
    _respond(req);
  }

  /// La petición volvió a su origen.
  void _arrived(_Request req) {
    switch (req.kind) {
      case _ReqKind.client:
        if (!req.error && !req.abandoned && req.logical != null) _settle(req.logical!, req);
      case _ReqKind.child:
        _childDone(req);
      case _ReqKind.async:
        _asyncDone(req);
    }
  }

  void _afterService(_NodeState s, _Request req) {
    if (req.kind == _ReqKind.async && req.credit && req.consumer == s.node.id) _releaseCredit(req);
    final next = _out[s.node.id];
    if (next == null || next.isEmpty) return _respond(req);
    final fanout = s.node.kind == ComponentKind.server &&
        paramValue(ComponentKind.server, s.node.params, ParamKey.fanout) == 1 &&
        next.length > 1;
    if (!fanout) return _send(req, _pick(s, next), 1);
    final children = <_Request>[];
    req.children = children;
    req.childMax = 0;
    req.childError = false;
    for (var i = 0; i < next.length; i++) {
      final child = _newRequest(_ReqKind.child, s.node.id);
      child.parent = req;
      children.add(child);
    }
    // Se envían después de crear todos: un fallo inmediato no debe cerrar el fan-out antes de tiempo.
    for (var i = 0; i < children.length; i++) {
      _send(children[i], next[i], 1);
    }
  }

  void _childDone(_Request child) {
    if (child.done) return;
    child.done = true;
    final parent = child.parent;
    final siblings = parent?.children;
    if (parent == null || siblings == null) return;
    parent.childMax = math.max(parent.childMax ?? 0, child.sim);
    if (child.error) parent.childError = true;
    if (siblings.any((c) => !c.done)) return;
    parent.sim += parent.childMax ?? 0;
    parent.children = null;
    final s = _nodes[child.origin];
    if (parent.childError) {
      if (s != null) {
        _fail(s, parent);
      } else {
        _lose(parent);
      }
    } else {
      _respond(parent);
    }
  }

  void _dispatch(_NodeState q) {
    if (q.backlog.isEmpty) return;
    final consumers = (_out[q.node.id] ?? const <SimEdge>[])
        .where((e) => !e.down && !_nodes[e.target]!.node.down)
        .toList();
    if (consumers.isEmpty) return;
    for (var i = 0; i < consumers.length && q.backlog.isNotEmpty; i++) {
      final e = consumers[(q.rr + i) % consumers.length];
      final target = _nodes[e.target]!;
      // Como el prefetch de RabbitMQ/Kafka: lo que puede procesar a la vez más lo que cabe en su cola local,
      // más lo que cabe "en el cable" (aquí el viaje va a cámara lenta y, si no, frenaría al consumidor).
      final travel = e.travelTime ?? defaultTravel;
      final prefetch = hasCapacity(target.node.kind)
          ? _workers(target) +
                paramValue(target.node.kind, target.node.params, ParamKey.queueMax) +
                (paramValue(target.node.kind, target.node.params, ParamKey.capacity) * travel).ceil()
          : _defaultPrefetch;
      while ((q.inflight[e.target] ?? 0) < prefetch && q.backlog.isNotEmpty) {
        final msg = q.backlog.removeAt(0);
        msg.sim += _now - (msg.queuedAt ?? _now);
        msg.queuedAt = null;
        msg.consumer = e.target;
        msg.credit = true;
        msg.path = [];
        q.inflight[e.target] = (q.inflight[e.target] ?? 0) + 1;
        _send(msg, e, 1);
      }
    }
    q.rr = (q.rr + 1) % 1000000;
  }

  /// Un mensaje de cola terminó: si falló, vuelve a la cola (entrega al menos una vez).
  void _asyncDone(_Request msg) {
    final q = _nodes[msg.origin];
    if (q == null) return;
    if (msg.credit) _releaseCredit(msg);
    msg.consumer = null;
    if (msg.error) {
      msg.error = false;
      msg.queuedAt = _now;
      msg.path = [];
      q.backlog.insert(0, msg);
      return;
    }
    _asyncLog.add(_now);
  }

  /// El consumidor terminó de procesar (o falló): deja un hueco libre para el siguiente mensaje.
  void _releaseCredit(_Request msg) {
    msg.credit = false;
    final q = _nodes[msg.origin];
    final c = msg.consumer;
    if (q != null && c != null) q.inflight[c] = math.max(0, (q.inflight[c] ?? 0) - 1);
  }

  void _fillWorkers(_NodeState s) {
    final workers = _workers(s);
    while (s.busy.length < workers && s.queue.isNotEmpty) {
      _startFromQueue(s, _now);
    }
  }

  void _startFromQueue(_NodeState s, double at) {
    final req = s.queue.removeAt(0);
    final start = math.max(at, req.queuedAt ?? at);
    req.sim += start - (req.queuedAt ?? start);
    req.queuedAt = null;
    _startJob(s, req, start);
  }

  void _startJob(_NodeState s, _Request req, [double? at]) {
    final service = _serviceTime(s);
    req.sim += service;
    s.busy.add(_Job(req, (at ?? _now) + service));
  }

  /// Un nodo cae: lo que tenía dentro falla. Una cola conserva sus mensajes (es duradera).
  void _crash(_NodeState s) {
    final inside = [...s.queue, ...s.busy.map((j) => j.req)];
    s.queue = [];
    s.busy = [];
    for (final r in inside) {
      r.queuedAt = null;
      _fail(s, r);
    }
  }

  void _fail(_NodeState s, _Request req) {
    _bump(s.drops);
    if (!req.error) {
      req.error = true;
      // El cliente se entera al momento (conexión rechazada); el tren rojo que vuelve es solo visual.
      if (req.kind == _ReqKind.client && req.logical != null) _attemptFailed(req.logical!, req);
    }
    _respond(req);
  }

  /// La respuesta vuelve por la arista por la que llegó la petición al último nodo.
  void _respond(_Request req) {
    final hop = req.path.isNotEmpty ? req.path.last : null;
    final edge = hop != null ? _edges[hop.edge] : null;
    if (edge == null) return _lose(req);
    _send(req, edge, -1);
  }

  /// La petición no puede seguir (arista o nodo borrado, línea cortada): falla para quien la espera.
  void _lose(_Request req) {
    switch (req.kind) {
      case _ReqKind.client:
        if (req.logical != null) _attemptFailed(req.logical!, req);
      case _ReqKind.child:
        req.error = true;
        _childDone(req);
      case _ReqKind.async:
        req.error = true;
        _asyncDone(req);
    }
  }

  void _send(_Request req, SimEdge edge, int dir) {
    if (edge.down) {
      if (dir == -1) return _lose(req);
      final from = _nodes[edge.source];
      // Sin ruta: falla en el nodo que intentaba enviar (o se pierde si sale del origen).
      return from != null && req.path.isNotEmpty ? _fail(from, req) : _lose(req);
    }
    final latency = edge.latencyMs;
    req.sim += (netMs + latency) / 1000;
    final travel = (edge.travelTime ?? defaultTravel) + math.min(latency / 1000, 1.5);
    final TrainKind kind = req.error
        ? TrainKind.error
        : dir == -1
        ? TrainKind.response
        : req.kind == _ReqKind.async
        ? TrainKind.async
        : TrainKind.request;
    _transits.add(_Transit(_nextId++, req, edge.id, dir, kind, _now, _now + travel));
  }

  // ── Utilidades ───────────────────────────────────────────

  _Request _newRequest(_ReqKind kind, String origin) => _Request(_nextId++, kind, origin);

  _NodeState _freshState(SimNode node) => _NodeState(
    node,
    _now,
    node.kind == ComponentKind.gateway ? paramValue(ComponentKind.gateway, node.params, ParamKey.rateLimit) : 0,
  );

  bool _isOverloaded(_NodeState s) {
    if (s.node.down) return false;
    if (s.node.kind == ComponentKind.queue) {
      final max = paramValue(ComponentKind.queue, s.node.params, ParamKey.queueMax);
      return s.backlog.length >= max * Thresholds.overloadQueue;
    }
    if (!hasCapacity(s.node.kind)) return false;
    // Rechazando en el último segundo, o con la cola casi llena.
    final max = paramValue(s.node.kind, s.node.params, ParamKey.queueMax);
    return _sum(s.drops) > 0 || (max > 0 && s.queue.length >= max * Thresholds.overloadQueue);
  }

  /// Round-robin.
  SimEdge _pick(_NodeState s, List<SimEdge> list) {
    final e = list[s.rr % list.length];
    s.rr = (s.rr + 1) % 1000000;
    return e;
  }

  /// Trabajadores en paralelo = capacidad × tiempo de proceso (mínimo 1).
  int _workers(_NodeState s) {
    final kind = s.node.kind;
    final params = s.node.params;
    return math.max(
      1,
      (paramValue(kind, params, ParamKey.capacity) * paramValue(kind, params, ParamKey.processingMs) / 1000).round(),
    );
  }

  /// Duración de cada trabajo, ajustada para que el rendimiento sea exactamente la capacidad.
  double _serviceTime(_NodeState s) {
    final base = _workers(s) / math.max(1e-6, paramValue(s.node.kind, s.node.params, ParamKey.capacity));
    return s.node.slow ? base * slowFactor : base;
  }

  void _bump(List<int> buckets) {
    buckets[_bucketIdx % _buckets]++;
  }

  void _rollBuckets() {
    final idx = (_now / _bucket + 1e-9).floor();
    if (idx == _bucketIdx) return;
    final steps = math.min(idx - _bucketIdx, _buckets);
    for (var k = 1; k <= steps; k++) {
      final b = (_bucketIdx + k) % _buckets;
      for (final s in _nodes.values) {
        s.arrivals[b] = 0;
        s.drops[b] = 0;
      }
    }
    _bucketIdx = idx;
  }
}

int _sum(Iterable<int> xs) {
  var t = 0;
  for (final x in xs) {
    t += x;
  }
  return t;
}

double _sumD(Iterable<double> xs) {
  var t = 0.0;
  for (final x in xs) {
    t += x;
  }
  return t;
}

/// Quita del principio los elementos que cumplen `old` (las ventanas están ordenadas por tiempo).
void _trimFront<T>(List<T> xs, bool Function(T) old) {
  var cut = 0;
  while (cut < xs.length && old(xs[cut])) {
    cut++;
  }
  if (cut > 0) xs.removeRange(0, cut);
}

/// Orden estable (como `Array.prototype.sort` de JS): a igual clave, conserva el orden original.
void _stableSortBy<T>(List<T> xs, double Function(T) key) {
  if (xs.length < 2) return;
  final indexed = [for (var i = 0; i < xs.length; i++) (i, xs[i])];
  indexed.sort((a, b) {
    final c = key(a.$2).compareTo(key(b.$2));
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  for (var i = 0; i < xs.length; i++) {
    xs[i] = indexed[i].$2;
  }
}
