import 'package:flutter/material.dart';

import '../sim/components.dart';
import '../theme/tokens.dart';
import '../widgets/icons.dart';
import '../widgets/ui.dart';
import 'diagram_canvas.dart';

/// Barra lateral de componentes: arrastrar al lienzo o pulsar para añadir en el centro.
class Palette extends StatelessWidget {
  final void Function(ComponentKind) onAdd;
  final VoidCallback onTemplates;
  final VoidCallback onGuide;
  const Palette({super.key, required this.onAdd, required this.onTemplates, required this.onGuide});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 212,
      decoration: BoxDecoration(
        color: c.papel,
        border: Border(right: BorderSide(color: c.linea)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Componentes', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Arrástralos al lienzo.', style: TextStyle(fontSize: 14, color: c.grisTexto)),
                    ],
                  ),
                ),
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                    child: Text(
                      group.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.grisTexto),
                    ),
                  ),
                  for (final kind in componentOrder.where((k) => specOf(k).group == group))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _PaletteItem(kind: kind, onAdd: onAdd),
                    ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Btn('Plantillas…', onPressed: onTemplates, height: 36, fontSize: 14, expand: true),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 12, height: 1.5, color: c.grisTexto),
                children: [
                  const TextSpan(text: 'Une la salida ● derecha de una estación con la entrada izquierda de otra.\n'),
                  const TextSpan(text: 'Espacio', style: TextStyle(fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' inicia/pausa · '),
                  const TextSpan(text: 'Supr', style: TextStyle(fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' borra · '),
                  const TextSpan(text: 'Mayús', style: TextStyle(fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' + arrastrar selecciona · '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: onGuide,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(
                          'Guía',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.verde),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteItem extends StatelessWidget {
  final ComponentKind kind;
  final void Function(ComponentKind) onAdd;
  const _PaletteItem({required this.kind, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final spec = specOf(kind);
    final row = Row(
      children: [
        HexIcon(kind: kind, size: 30, color: c.verde, fg: c.sobreVerde),
        const SizedBox(width: 10),
        Expanded(child: Text(spec.name, style: const TextStyle(fontWeight: FontWeight.w600))),
      ],
    );
    return Tooltip(
      message: spec.tooltip,
      preferBelow: false,
      verticalOffset: 22,
      child: Draggable<PaletteDrag>(
        data: PaletteDrag(kind),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.translate(
            offset: const Offset(-92, -30),
            child: Opacity(
              opacity: 0.85,
              child: Container(
                width: 184,
                height: 60,
                padding: const EdgeInsets.only(left: 10, right: 14),
                decoration: BoxDecoration(
                  color: c.papel,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: c.tinta, width: 3.5),
                  boxShadow: c.sombra,
                ),
                child: Row(
                  children: [
                    HexIcon(kind: kind, size: 38, color: c.verde, fg: c.sobreVerde),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        spec.name,
                        style: TextStyle(fontWeight: FontWeight.w600, color: c.tinta, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: HoverTile(onTap: () => onAdd(kind), child: row),
        ),
      ),
    );
  }
}

/// Hoja inferior para añadir componentes en pantallas estrechas.
Future<void> showAddSheet(
  BuildContext context, {
  required void Function(ComponentKind) onAdd,
  required VoidCallback onTemplates,
  required VoidCallback onGuide,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (ctx) {
      final c = ctx.c;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 4),
                child: Text('Añadir componente', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              ),
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                  child: Text(
                    group.label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.grisTexto),
                  ),
                ),
                Row(
                  children: [
                    for (final kind in componentOrder.where((k) => specOf(k).group == group)) ...[
                      Expanded(
                        child: HoverTile(
                          border: c.linea,
                          radius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(ctx);
                            onAdd(kind);
                          },
                          padding: EdgeInsets.zero,
                          child: SizedBox(
                            height: 92,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                HexIcon(kind: kind, size: 36, color: c.verde, fg: c.sobreVerde),
                                const SizedBox(height: 6),
                                Text(
                                  specOf(kind).name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.15),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Btn(
                      'Plantillas…',
                      expand: true,
                      onPressed: () {
                        Navigator.pop(ctx);
                        onTemplates();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Btn(
                      'Guía',
                      expand: true,
                      onPressed: () {
                        Navigator.pop(ctx);
                        onGuide();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
