import 'package:flutter/material.dart';

import '../store/diagram_store.dart';
import '../theme/tokens.dart';
import 'sim_runtime.dart';
import 'supervisor.dart';

/// Barra flotante: ▶/⏸, tráfico y métricas en vivo (port de `SimBar.tsx`).
class SimBar extends StatelessWidget {
  final DiagramStore store;
  final SimRuntime runtime;
  final bool compact;
  final bool sparklines;
  const SimBar({super.key, required this.store, required this.runtime, this.compact = false, this.sparklines = true});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: Listenable.merge([store, runtime]),
      builder: (context, _) {
        final sim = store.sim;
        final m = runtime.metrics;
        final history = runtime.history;
        final errorPct = m.errorRate * 100;
        final errTone = errorPct >= 5 ? c.rojo : (errorPct > 0 ? c.ambar : null);

        final play = _PlayButton(running: sim.running, onTap: () => store.setRunning(!sim.running));
        final slider = SizedBox(
          height: 28,
          child: Slider(
            value: sim.traffic.clamp(1, 200),
            min: 1,
            max: 200,
            divisions: 199,
            onChanged: store.setTraffic,
            semanticFormatterCallback: (v) => '${v.round()} peticiones por segundo',
          ),
        );
        final trafficLabel = Text(
          '${fmt(sim.traffic)} pet/s',
          style: TextStyle(fontSize: 14, color: c.grisTexto, fontFeatures: tabular),
        );
        final toggles = [
          _Toggle(
            on: sim.chaos,
            label: 'Caos',
            tooltip: 'Caídas, lentitud y cortes de red al azar; lo caído vuelve solo tras unos segundos',
            onChanged: (v) => store.setSimOptions(chaos: v),
          ),
          const SizedBox(width: 6),
          _Toggle(
            on: sim.autoCrash,
            label: compact ? 'Sobrecarga' : 'Sobrecarga tumba',
            tooltip:
                'Un componente saturado más de $overloadSeconds s se cae y tarda ${fmt(sim.restartSec)} s en reiniciar',
            onChanged: (v) => store.setSimOptions(autoCrash: v),
          ),
        ];

        final card = BoxDecoration(
          color: c.papel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.linea),
          boxShadow: c.sombra,
        );

        if (compact) {
          return Container(
            decoration: card,
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    play,
                    const SizedBox(width: 8),
                    Expanded(child: slider),
                    trafficLabel,
                    const SizedBox(width: 4),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const SizedBox(width: 4),
                    _Metric(label: 'ok/s', value: fmt(m.throughput), tooltip: 'Respuestas correctas por segundo'),
                    const SizedBox(width: 12),
                    _Metric(label: 'p95', value: '${fmt(m.p95LatencyMs)} ms', tooltip: 'Latencia p95'),
                    const SizedBox(width: 12),
                    _Metric(label: 'errores', value: '${fmt(errorPct)} %', tooltip: 'Errores', tone: errTone),
                    const Spacer(),
                    ...toggles,
                  ],
                ),
              ],
            ),
          );
        }

        Widget divider() => Container(width: 1, height: 36, color: c.linea, margin: const EdgeInsets.symmetric(horizontal: 16));

        return Container(
          decoration: card,
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              play,
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tráfico', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(width: 170, child: slider),
                  SizedBox(width: 72, child: trafficLabel),
                ],
              ),
              divider(),
              _Metric(
                label: 'completadas',
                value: '${fmt(m.throughput)}/s',
                tooltip: 'Respuestas correctas que llegan a los clientes por segundo',
                series: sparklines ? [for (final h in history) h.throughput] : null,
                color: c.verde,
              ),
              const SizedBox(width: 16),
              _Metric(
                label: 'latencia p95',
                value: '${fmt(m.p95LatencyMs)} ms',
                tooltip:
                    'El 95 % de las respuestas tarda menos que esto (media: ${fmt(m.avgLatencyMs)} ms). Cuenta espera, proceso y red; el viaje lento de los trenes no.',
                series: sparklines ? [for (final h in history) h.p95] : null,
                color: c.tinta,
              ),
              const SizedBox(width: 16),
              _Metric(
                label: 'errores',
                value: '${fmt(errorPct)} %',
                tooltip:
                    'Peticiones que terminaron en error (incluidos los tiempos de espera agotados), últimos 2 s',
                tone: errTone,
                series: sparklines ? [for (final h in history) h.errors * 100] : null,
                color: c.rojo,
                fixedMax: 100,
              ),
              if (m.retryRate >= 0.5) ...[
                const SizedBox(width: 16),
                _Metric(
                  label: 'reintentos',
                  value: '${fmt(m.retryRate)}/s',
                  tooltip: 'Reintentos de los clientes por segundo',
                ),
              ],
              if (m.backlog > 0 || m.asyncThroughput > 0) ...[
                const SizedBox(width: 16),
                _Metric(
                  label: 'en segundo plano',
                  value: '${fmt(m.asyncThroughput)}/s · ${fmt(m.backlog)} en cola',
                  tooltip: 'Mensajes procesados por los workers por segundo, y mensajes esperando en las colas',
                ),
              ],
              divider(),
              Row(mainAxisSize: MainAxisSize.min, children: toggles),
            ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool running;
  final VoidCallback onTap;
  const _PlayButton({required this.running, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: running ? 'Pausar (Espacio)' : 'Poner en marcha (Espacio)',
      child: Material(
        color: c.verde,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          canRequestFocus: false,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded, color: c.sobreVerde, size: 26),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String tooltip;
  final Color? tone;
  final List<double>? series;
  final Color? color;
  final double? fixedMax;
  const _Metric({
    required this.label,
    required this.value,
    required this.tooltip,
    this.tone,
    this.series,
    this.color,
    this.fixedMax,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: c.grisTexto, height: 1.2)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tone ?? c.tinta,
                  fontFeatures: tabular,
                  height: 1.25,
                ),
              ),
            ],
          ),
          if (series != null && color != null) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: CustomPaint(size: const Size(64, 22), painter: _Sparkline(series!, color!, c.linea, fixedMax)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Minigráfica del último minuto: una serie, línea de 2 px, sin ejes.
class _Sparkline extends CustomPainter {
  final List<double> values;
  final Color color;
  final Color base;
  final double? fixedMax;
  _Sparkline(this.values, this.color, this.base, this.fixedMax);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawLine(Offset(0, h - 1), Offset(w, h - 1), Paint()..color = base);
    if (values.length < 2) return;
    var max = fixedMax ?? 0;
    for (final v in values) {
      if (v > max) max = v;
    }
    if (max < 1e-9) max = 1e-9;
    final step = w / (values.length - 1);
    final p = Path();
    for (var i = 0; i < values.length; i++) {
      final y = h - 2 - (values[i] / max) * (h - 4);
      i == 0 ? p.moveTo(0, y) : p.lineTo(i * step, y);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Sparkline old) => true;
}

class _Toggle extends StatelessWidget {
  final bool on;
  final String label;
  final String tooltip;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.on, required this.label, required this.tooltip, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        toggled: on,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          canRequestFocus: false,
          onTap: () => onChanged(!on),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: on ? c.rojo : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: on ? c.rojo : c.linea),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: on ? Colors.white : c.gris),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? Colors.white : c.grisTexto),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
