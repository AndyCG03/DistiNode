import 'dart:async';
import 'dart:math' as math;

import '../model/diagram.dart';
import '../sim/components.dart';
import '../store/diagram_store.dart';
import 'sim_runtime.dart';

/// Segundos seguidos saturado antes de caerse (si "Sobrecarga tumba" está activo).
const overloadSeconds = 5;
const _slowSeconds = 10;
const _cutSeconds = 6;

/// Probabilidad de un evento de caos en cada segundo.
const _chaosPerSecond = 0.15;
const _maxChaosDown = 2;

/// Supervisor de fallos (port de `Supervisor.tsx`). En local siempre es el "líder".
/// - Reinicia lo que se cayó solo cuando vence su tiempo.
/// - Con "Sobrecarga tumba": tumba los nodos saturados demasiado tiempo.
/// - Con "Caos": tumba, degrada o corta conexiones al azar.
class Supervisor {
  final DiagramStore store;
  final SimRuntime runtime;
  final _rand = math.Random();
  Timer? _timer;
  int _lastChaos = DateTime.now().millisecondsSinceEpoch;

  Supervisor(this.store, this.runtime) {
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  void dispose() => _timer?.cancel();

  void _tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final opts = store.sim;
    final nodes = store.nodes.values.toList();
    final edges = store.edges.values.toList();

    // 1. Reinicios y recuperaciones programadas.
    for (final n in nodes) {
      if (n.down && n.downUntil != null && now >= n.downUntil!) {
        store.setNodeState(n.id, down: false, downUntil: null, downReason: null);
        store.announce('${n.label} volvió a arrancar');
      }
      if (n.slow && n.slowUntil != null && now >= n.slowUntil!) store.setNodeState(n.id, slow: false, slowUntil: null);
    }
    for (final e in edges) {
      if (e.down && e.downUntil != null && now >= e.downUntil!) store.setEdge(e.id, down: false, downUntil: null);
    }
    if (!store.sim.running) return;

    // 2. Caídas por sobrecarga sostenida.
    if (opts.autoCrash) {
      for (final n in nodes) {
        if (n.down) continue;
        final s = runtime.engine.nodeStats(n.id);
        if (s != null && s.overloadFor >= overloadSeconds) {
          store.setNodeState(
            n.id,
            down: true,
            downReason: DownReason.sobrecarga,
            downUntil: now + (opts.restartSec * 1000).round(),
          );
          store.announce('💥 ${n.label} se cayó por sobrecarga');
        }
      }
    }

    // 3. Caos.
    if (!opts.chaos || now - _lastChaos < 1000) return;
    _lastChaos = now;
    if (_rand.nextDouble() > _chaosPerSecond) return;
    T pickOne<T>(List<T> xs) => xs[_rand.nextInt(xs.length)];
    final current = store.nodes.values.toList();
    final alive = current.where((n) => !n.down && n.kind != ComponentKind.client).toList();
    final chaosDown = current.where((n) => n.down && n.downReason == DownReason.caos).length;
    final roll = _rand.nextDouble();
    if (roll < 0.55 && alive.isNotEmpty && chaosDown < _maxChaosDown) {
      final n = pickOne(alive);
      store.setNodeState(
        n.id,
        down: true,
        downReason: DownReason.caos,
        downUntil: now + (opts.restartSec * 1000).round(),
      );
      store.announce('⚡ Caos: ${n.label} se cayó');
    } else if (roll < 0.8 && alive.isNotEmpty) {
      final notSlow = alive.where((x) => !x.slow).toList();
      final n = pickOne(notSlow.isNotEmpty ? notSlow : alive);
      store.setNodeState(n.id, slow: true, slowUntil: now + _slowSeconds * 1000);
      store.announce('⚡ Caos: ${n.label} va lento');
    } else {
      final candidates = store.edges.values.where((e) => !e.down).toList();
      if (candidates.isEmpty) return;
      final e = pickOne(candidates);
      store.setEdge(e.id, down: true, downUntil: now + _cutSeconds * 1000);
      store.announce(
        '⚡ Caos: se cortó ${store.nodes[e.source]?.label ?? "?"} → ${store.nodes[e.target]?.label ?? "?"}',
      );
    }
  }
}
