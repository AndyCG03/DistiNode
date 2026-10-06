import 'package:flutter/material.dart';

import '../sim/templates.dart';
import '../theme/tokens.dart';
import '../widgets/logo.dart';
import '../widgets/templates_ui.dart';
import '../widgets/ui.dart';

const _featured = ['tienda-online', 'streaming-video', 'microservicios', 'alta-disponibilidad'];

/// Lienzo vacío: cargar el ejemplo, ver las plantillas o partir de un sistema real.
class EmptyState extends StatelessWidget {
  final void Function(Template) onLoad;
  final VoidCallback onAll;
  const EmptyState({super.key, required this.onLoad, required this.onAll});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final wide = MediaQuery.of(context).size.width > 640;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 672),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoMark(size: 56),
              const SizedBox(height: 16),
              const Text('Un lienzo en blanco', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Añade componentes, o empieza con un sistema hecho y dale al ▶.',
                textAlign: TextAlign.center,
                style: TextStyle(color: c.grisTexto),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Btn('Cargar ejemplo', kind: BtnKind.primary, onPressed: () => onLoad(templates.first)),
                  Btn('Ver las ${templates.length} plantillas', onPressed: onAll),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'o parte de un sistema real',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.grisTexto),
              ),
              const SizedBox(height: 8),
              Grid(
                columns: wide ? 2 : 1,
                children: [
                  for (final id in _featured) TemplateButton(template: templateById(id)!, onPick: onLoad),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
