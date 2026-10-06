import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/diagram.dart';
import '../sim/components.dart';
import '../sim/types.dart';
import '../store/diagram_store.dart';
import '../theme/tokens.dart';
import '../widgets/icons.dart';
import '../widgets/ui.dart';
import 'diagram_paint.dart' show secondsLeft;
import 'editor_controller.dart';
import 'sim_runtime.dart';

/// Panel de propiedades del componente o la conexión seleccionada (port de `PropertiesPanel.tsx`).
class PropertiesPanel extends StatelessWidget {
  final DiagramStore store;
  final SimRuntime runtime;
  final EditorController controller;
  final ValueNotifier<int> clock;
  final void Function(ComponentKind kind) onHelp;

  const PropertiesPanel({
    super.key,
    required this.store,
    required this.runtime,
    required this.controller,
    required this.clock,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, controller]),
      builder: (context, _) {
        controller.prune();
        final nodeId = controller.selection.singleNode;
        final edgeId = controller.selection.singleEdge;
        final node = nodeId != null ? store.nodes[nodeId] : null;
        final edge = edgeId != null ? store.edges[edgeId] : null;
        if (node != null) return _NodeProps(key: ValueKey('n${node.id}'), panel: this, node: node);
        if (edge != null) return _EdgeProps(key: ValueKey('e${edge.id}'), panel: this, edge: edge);
        return const SizedBox.shrink();
      },
    );
  }

  static bool hasContent(DiagramStore store, EditorController ctl) {
    final n = ctl.selection.singleNode;
    final e = ctl.selection.singleEdge;
    return (n != null && store.nodes.containsKey(n)) || (e != null && store.edges.containsKey(e));
  }
}

class _NodeProps extends StatefulWidget {
  final PropertiesPanel panel;
  final NodeData node;
  const _NodeProps({super.key, required this.panel, required this.node});
  @override
  State<_NodeProps> createState() => _NodePropsState();
}

class _NodePropsState extends State<_NodeProps> {
  late final TextEditingController _name = TextEditingController(text: widget.node.label);
  final _nameFocus = FocusNode();

  @override
  void didUpdateWidget(_NodeProps old) {
    super.didUpdateWidget(old);
    if (!_nameFocus.hasFocus && _name.text != widget.node.label) _name.text = widget.node.label;
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final node = widget.node;
    final store = widget.panel.store;
    final spec = specOf(node.kind);
    final connectable = store.nodes.values
        .where((n) => n.id != node.id && !store.edges.values.any((e) => e.source == node.id && e.target == n.id))
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HexIcon(kind: node.kind, size: 40, color: node.down ? c.gris : c.verde, fg: c.sobreVerde),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spec.name, style: TextStyle(fontSize: 14, color: c.grisTexto)),
                    Text(node.label, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Tooltip(
                message: 'Qué es un ${spec.name} (abre la guía)',
                child: HoverTile(
                  onTap: () => widget.panel.onHelp(node.kind),
                  radius: BorderRadius.circular(999),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Text('?', style: TextStyle(fontWeight: FontWeight.w700, color: c.verde)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _Label('Nombre'),
          const SizedBox(height: 6),
          TextField(
            controller: _name,
            focusNode: _nameFocus,
            maxLength: 40,
            decoration: const InputDecoration(counterText: ''),
            onChanged: (v) => store.setLabel(node.id, v),
          ),
          for (final p in spec.params) ...[
            const SizedBox(height: 20),
            ParamField(
              key: ValueKey(p.key),
              spec: p,
              value: paramValue(node.kind, node.params, p.key),
              onChanged: (v) => store.setParam(node.id, p.key, v),
            ),
          ],
          const SizedBox(height: 20),
          const _Label('Conectar con…'),
          const SizedBox(height: 6),
          _Dropdown<String>(
            hint: connectable.isNotEmpty ? 'Elige un destino' : 'Ya está conectado a todo',
            value: null,
            items: [for (final n in connectable) (n.id, n.label)],
            onChanged: connectable.isEmpty ? null : (id) => store.connect(node.id, id),
          ),
          const SizedBox(height: 6),
          _Help('Las peticiones irán de ${node.label} al destino. También puedes arrastrar desde su salida (●).'),
          const SizedBox(height: 20),
          if (node.kind != ComponentKind.client)
            ListenableBuilder(
              listenable: widget.panel.runtime,
              builder: (context, _) => _LiveStats(stats: widget.panel.runtime.stats(node.id), kind: node.kind),
            ),
          const SizedBox(height: 16),
          Divider(color: c.linea, height: 1),
          const SizedBox(height: 16),
          if (node.down)
            ValueListenableBuilder(
              valueListenable: widget.panel.clock,
              builder: (context, _, _) {
                final secs = secondsLeft(node.downUntil, DateTime.now().millisecondsSinceEpoch);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    secs != null
                        ? 'Se cayó ${node.downReason == DownReason.sobrecarga ? "por sobrecarga" : "por el caos"}; vuelve en $secs s.'
                        : 'Está caído: todo lo que le llega falla.',
                    style: TextStyle(fontSize: 14, color: c.rojo),
                  ),
                );
              },
            ),
          Btn(
            node.down ? 'Revivir' : 'Tumbar',
            kind: node.down ? BtnKind.primary : BtnKind.danger,
            height: 40,
            expand: true,
            onPressed: () => node.down
                ? store.setNodeState(node.id, down: false, downUntil: null, downReason: null)
                : store.setNodeState(node.id, down: true, downUntil: null, downReason: DownReason.manual),
          ),
          if (node.kind != ComponentKind.client) ...[
            const SizedBox(height: 8),
            Btn(
              node.slow ? 'Quitar degradación' : 'Degradar (lento)',
              height: 40,
              expand: true,
              tooltip: 'Simula un disco lento, un vecino ruidoso o una fuga de memoria',
              onPressed: () => store.setNodeState(node.id, slow: !node.slow, slowUntil: null),
            ),
          ],
          const SizedBox(height: 4),
          Btn(
            'Borrar componente',
            kind: BtnKind.ghost,
            height: 36,
            fontSize: 14,
            expand: true,
            onPressed: () {
              store.removeElements([node.id], const []);
              widget.panel.controller.clearSelection();
            },
          ),
        ],
      ),
    );
  }
}

class _EdgeProps extends StatelessWidget {
  final PropertiesPanel panel;
  final EdgeData edge;
  const _EdgeProps({super.key, required this.panel, required this.edge});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = panel.store;
    final a = store.nodes[edge.source]?.label ?? '?';
    final b = store.nodes[edge.target]?.label ?? '?';
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Conexión', style: TextStyle(fontSize: 14, color: c.grisTexto)),
          Text('$a → $b', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const _Help('Las peticiones van en el sentido de la flecha; las respuestas vuelven por la misma línea.'),
          const SizedBox(height: 20),
          ParamField(
            spec: const ParamSpec(
              key: ParamKey.processingMs,
              label: 'Latencia de red añadida',
              unit: 'ms',
              min: 0,
              max: 2000,
              step: 5,
              sliderMax: 500,
              help: 'Distancia o red congestionada: se suma a la ida y a la vuelta. 0 = misma red local.',
            ),
            value: edge.latencyMs,
            onChanged: (v) => store.setEdge(edge.id, latencyMs: v),
          ),
          const SizedBox(height: 16),
          Divider(color: c.linea, height: 1),
          const SizedBox(height: 16),
          Btn(
            edge.down ? 'Restaurar conexión' : 'Cortar conexión',
            kind: edge.down ? BtnKind.primary : BtnKind.danger,
            height: 40,
            expand: true,
            tooltip: 'Simula un cable cortado o una partición de red',
            onPressed: () => store.setEdge(edge.id, down: !edge.down, downUntil: null),
          ),
          const SizedBox(height: 4),
          Btn(
            'Borrar conexión',
            kind: BtnKind.ghost,
            height: 36,
            fontSize: 14,
            expand: true,
            onPressed: () {
              store.removeElements(const [], [edge.id]);
              panel.controller.clearSelection();
            },
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600));
}

class _Help extends StatelessWidget {
  final String text;
  const _Help(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontSize: 12.5, height: 1.35, color: context.c.grisTexto));
}

class _Dropdown<T> extends StatelessWidget {
  final String? hint;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T>? onChanged;
  const _Dropdown({this.hint, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.papel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.linea, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: hint != null ? Text(hint!, style: TextStyle(color: c.grisTexto, fontSize: 15)) : null,
          dropdownColor: c.papel,
          borderRadius: BorderRadius.circular(10),
          style: TextStyle(color: c.tinta, fontSize: 15, fontFamily: fontFamily),
          items: [for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l, overflow: TextOverflow.ellipsis))],
          onChanged: onChanged == null ? null : (v) => v != null ? onChanged!(v) : null,
        ),
      ),
    );
  }
}

/// Un parámetro: selector si tiene opciones; si no, deslizador + campo numérico.
class ParamField extends StatefulWidget {
  final ParamSpec spec;
  final double value;
  final ValueChanged<double> onChanged;
  const ParamField({super.key, required this.spec, required this.value, required this.onChanged});
  @override
  State<ParamField> createState() => _ParamFieldState();
}

class _ParamFieldState extends State<ParamField> {
  late final TextEditingController _num = TextEditingController(text: fmtParam(widget.value));
  final _focus = FocusNode();

  static String fmtParam(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _num.text = fmtParam(widget.value);
    });
  }

  @override
  void didUpdateWidget(ParamField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _num.text != fmtParam(widget.value)) _num.text = fmtParam(widget.value);
  }

  @override
  void dispose() {
    _num.dispose();
    _focus.dispose();
    super.dispose();
  }

  double _clamp(double v) => v.clamp(widget.spec.min, widget.spec.max).toDouble();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final spec = widget.spec;
    if (spec.options != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(spec.label),
          const SizedBox(height: 6),
          _Dropdown<double>(
            value: spec.options!.any((o) => o.value == widget.value) ? widget.value : spec.options!.first.value,
            items: [for (final o in spec.options!) (o.value, o.label)],
            onChanged: widget.onChanged,
          ),
          const SizedBox(height: 6),
          _Help(spec.help),
        ],
      );
    }
    final sliderMax = spec.sliderMax != null && spec.sliderMax! < spec.max ? spec.sliderMax! : spec.max;
    final divisions = ((sliderMax - spec.min) / spec.step).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _Label(spec.label)),
            SizedBox(
              width: 72,
              height: 30,
              child: TextField(
                controller: _num,
                focusNode: _focus,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
                style: const TextStyle(fontSize: 14, fontFeatures: tabular),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: c.linea),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: c.verde),
                  ),
                ),
                onChanged: (t) {
                  final v = double.tryParse(t);
                  if (v != null && v.isFinite) widget.onChanged(_clamp(v));
                },
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(width: 34, child: Text(spec.unit, style: TextStyle(fontSize: 12, color: c.grisTexto))),
          ],
        ),
        SizedBox(
          height: 32,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)),
            child: Slider(
              value: widget.value.clamp(spec.min, sliderMax),
              min: spec.min,
              max: sliderMax,
              divisions: divisions > 0 && divisions <= 2000 ? divisions : null,
              onChanged: (v) => widget.onChanged(_clamp((v / spec.step).round() * spec.step)),
            ),
          ),
        ),
        _Help(spec.help),
      ],
    );
  }
}

class _LiveStats extends StatelessWidget {
  final NodeStats? stats;
  final ComponentKind kind;
  const _LiveStats({required this.stats, required this.kind});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null) return const SizedBox.shrink();
    final c = context.c;
    final (label, color) = switch (s.status) {
      Health.idle => ('En reposo', c.grisTexto),
      Health.ok => ('Va sobrado', c.verde),
      Health.warn => ('Cerca del límite', c.ambar),
      Health.hot => ('Saturado', c.rojo),
      Health.down => ('Caído', c.rojo),
    };
    final capacity = hasCapacity(kind) && s.status != Health.down;
    final isQueue = kind == ComponentKind.queue && s.status != Health.down;
    final isGateway = kind == ComponentKind.gateway && s.status != Health.down;
    final rows = <(String, String)>[
      ('Llegan', '${fmt(s.arrivalRate)} pet/s'),
      if (capacity) ('Carga', '${fmt(s.rho * 100)} %'),
      if (capacity) ('Cola', '${s.queue} / ${fmt(s.queueMax)}'),
      if (capacity) ('Trabajando', '${s.busy} / ${s.workers}'),
      if (isQueue) ('En espera', '${s.queue} / ${fmt(s.queueMax)}'),
      if (isQueue) ('Entregados', '${s.busy}'),
      if (isGateway) ('Uso del límite', '${fmt(s.rho * 100)} %'),
      ('Fallan', '${fmt(s.dropRate)} /s'),
      if (capacity && s.overloadFor > 1) ('Saturado desde', '${fmt(s.overloadFor)} s'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.fondo, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 8),
          Wrap(
            runSpacing: 8,
            children: [
              for (final (k, v) in rows)
                FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(k, style: TextStyle(fontSize: 12, color: c.grisTexto)),
                      Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFeatures: tabular)),
                    ],
                  ),
                ),
            ],
          ),
          if (capacity) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (s.rho).clamp(0, 1).toDouble(),
                minHeight: 6,
                backgroundColor: c.linea,
                color: s.status == Health.hot ? c.rojo : (s.status == Health.warn ? c.ambar : c.verde),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
