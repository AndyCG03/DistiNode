import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../editor/editor_screen.dart';
import '../editor/files.dart';
import '../guide/guide_screen.dart';
import '../model/diagram.dart';
import '../model/project_file.dart';
import '../store/project_repository.dart';
import '../theme/tokens.dart';
import '../widgets/logo.dart';
import '../widgets/templates_ui.dart';
import '../widgets/ui.dart';
import 'metro_hero.dart';

const _steps = [
  ('Coloca estaciones', 'CDN, API gateways, balanceadores, servidores, colas, workers, cachés y bases de datos.'),
  ('Tiende las líneas', 'Conecta los componentes como en un mapa de metro.'),
  ('Dale al ▶ y rómpelo', 'Sube el tráfico, activa el caos, corta la red y mira qué aguanta.'),
];

/// Inicio: "Mis proyectos" (sustituye a "Mis salas" de la web; sin cuentas).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProjectMeta>? _projects;
  final _name = TextEditingController();

  ProjectRepository get repo => AppScope.of(context).repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_projects == null) _refresh();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await repo.list();
    if (mounted) setState(() => _projects = list);
  }

  Future<void> _open(String id) async {
    try {
      final store = await repo.load(id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EditorScreen(projectId: id, store: store)),
      );
    } on ProjectParseError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, 'No se pudo abrir el proyecto.', error: true);
    }
    await _refresh();
  }

  String _defaultName() {
    final taken = {for (final p in _projects ?? const <ProjectMeta>[]) p.name};
    for (var n = 1; ; n++) {
      final name = 'Proyecto $n';
      if (!taken.contains(name)) return name;
    }
  }

  Future<void> _create() async {
    final name = _name.text.trim().isEmpty ? _defaultName() : _name.text.trim();
    final id = await repo.create(name.length > 60 ? name.substring(0, 60) : name);
    _name.clear();
    await _open(id);
  }

  Future<void> _fromTemplate() async {
    final t = await showTemplateDialog(context, replacing: false);
    if (t == null) return;
    final built = buildTemplate(t);
    final id = await repo.create(t.name, nodes: built.nodes, edges: built.edges, sim: SimShared(traffic: t.traffic));
    await _open(id);
  }

  Future<void> _import() async {
    try {
      final bytes = await pickProjectFile();
      if (bytes == null) return;
      final id = await repo.importBytes(bytes);
      if (mounted) toast(context, 'Proyecto importado.');
      await _open(id);
    } on ProjectParseError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, 'No se pudo importar el archivo.', error: true);
    }
  }

  Future<void> _rename(ProjectMeta p) async {
    final v = await promptText(context, title: 'Renombrar proyecto', label: 'Nombre', initial: p.name);
    if (v == null) return;
    await repo.rename(p.id, v);
    await _refresh();
  }

  Future<void> _duplicate(ProjectMeta p) async {
    await repo.duplicate(p.id);
    await _refresh();
  }

  Future<void> _export(ProjectMeta p) async {
    final json = await repo.exportJson(p.id);
    if (!mounted) return;
    final ok = await saveFile(
      context,
      name: '${fileSlug(p.name)}.distinode.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
      mime: 'application/json',
      extensionLabel: 'Proyecto de DistiNode',
      extensions: const ['json'],
    );
    if (ok && mounted && !isMobile) toast(context, 'Archivo guardado.');
  }

  Future<void> _delete(ProjectMeta p) async {
    final ok = await confirmDialog(
      context,
      title: 'Borrar «${p.name}»',
      message: 'El proyecto se borra de este equipo y no se puede recuperar. Si quieres conservarlo, guárdalo antes como archivo.',
      confirm: 'Borrar',
      danger: true,
    );
    if (!ok) return;
    await repo.delete(p.id);
    await _refresh();
  }

  void _openFolder() {
    final path = repo.dir.path;
    if (Platform.isWindows) {
      Process.run('explorer', [path]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [path]);
    } else if (Platform.isMacOS) {
      Process.run('open', [path]);
    }
  }

  void _guide() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GuideScreen()));

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = MediaQuery.of(context).size.width;
    final wide = w >= 900;
    final projects = _projects;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Logo(size: 32),
                  const Spacer(),
                  Btn('Guía', kind: BtnKind.ghost, height: 36, fontSize: 14, onPressed: _guide),
                  const SizedBox(width: 4),
                  RoundIconButton(
                    icon: ThemeIcon(color: c.grisTexto),
                    tooltip: 'Modo claro / oscuro',
                    onPressed: () => AppScope.of(context).toggleTheme(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _hero(context, wide),
                        const SizedBox(height: 40),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 360, child: _newPanel(context)),
                              const SizedBox(width: 40),
                              Expanded(child: _list(context, projects)),
                            ],
                          )
                        else ...[
                          _newPanel(context),
                          const SizedBox(height: 32),
                          _list(context, projects),
                        ],
                        const SizedBox(height: 56),
                        _howItWorks(context, wide),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: c.linea))),
              alignment: Alignment.center,
              child: Text(
                'DistiNode · proyecto educativo de Sistemas Distribuidos — CUJAE',
                style: TextStyle(fontSize: 13, color: c.grisTexto),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, bool wide) {
    final c = context.c;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Diseña sistemas distribuidos. '),
              TextSpan(text: 'Y míralos funcionar.', style: TextStyle(color: c.verde)),
            ],
          ),
          style: TextStyle(fontSize: wide ? 50 : 34, fontWeight: FontWeight.w700, height: 1.08, letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        Text(
          'Un lienzo donde cada petición es un tren. Descubre por qué hace falta un balanceador cuando el servidor se pone en rojo. Todo en tu equipo: sin cuentas y sin conexión.',
          style: TextStyle(fontSize: 18, color: c.grisTexto, height: 1.45),
        ),
      ],
    );
    if (!wide) return text;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: text),
        const SizedBox(width: 40),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.papel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.linea),
            ),
            child: const MetroHero(),
          ),
        ),
      ],
    );
  }

  Widget _newPanel(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.papel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.linea),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nuevo proyecto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Un lienzo vacío, una plantilla o un archivo.', style: TextStyle(fontSize: 14, color: c.grisTexto)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            maxLength: 60,
            decoration: InputDecoration(hintText: _defaultName(), counterText: '', labelText: 'Nombre'),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 12),
          Btn('Crear proyecto', kind: BtnKind.primary, expand: true, onPressed: _create),
          const SizedBox(height: 8),
          Btn('Desde una plantilla…', expand: true, onPressed: _fromTemplate),
          const SizedBox(height: 8),
          Btn(
            'Importar archivo…',
            expand: true,
            onPressed: _import,
            tooltip: 'Abre un .distinode.json (también los exportados desde la web)',
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, List<ProjectMeta>? projects) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text('Mis proyectos', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            ),
            if (!isMobile)
              Btn(
                'Abrir carpeta',
                kind: BtnKind.ghost,
                height: 34,
                fontSize: 14,
                icon: Icon(Icons.folder_open_outlined, size: 18, color: c.grisTexto),
                onPressed: _openFolder,
                tooltip: repo.dir.path,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Se guardan solos en este equipo mientras trabajas.', style: TextStyle(color: c.grisTexto)),
        const SizedBox(height: 16),
        if (projects == null)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (projects.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.linea, width: 1.5),
            ),
            child: Column(
              children: [
                const Text('Todavía no tienes proyectos', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Crea el primero o empieza desde una plantilla.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.grisTexto),
                ),
              ],
            ),
          )
        else
          Stack(
            children: [
              Positioned(
                left: 13,
                top: 24,
                bottom: 24,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(color: c.verde, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Column(children: [for (final p in projects) _ProjectRow(p: p, home: this)]),
            ],
          ),
      ],
    );
  }

  Widget _howItWorks(BuildContext context, bool wide) {
    final c = context.c;
    final items = [
      for (var i = 0; i < _steps.length; i++)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.papel,
                shape: BoxShape.circle,
                border: Border.all(color: c.tinta, width: 5),
              ),
              child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_steps[i].$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_steps[i].$2, style: TextStyle(color: c.grisTexto)),
                ],
              ),
            ),
          ],
        ),
    ];
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 32),
                Expanded(child: items[i]),
              ],
            ],
          )
        : Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[if (i > 0) const SizedBox(height: 24), items[i]],
            ],
          );
  }
}

enum _RowAction { open, rename, duplicate, export, delete }

class _ProjectRow extends StatelessWidget {
  final ProjectMeta p;
  final _HomeScreenState home;
  const _ProjectRow({required this.p, required this.home});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return HoverTile(
      onTap: () => home._open(p.id),
      radius: BorderRadius.circular(12),
      padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.papel,
              shape: BoxShape.circle,
              border: Border.all(color: c.tinta, width: 5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  'Editado ${shortDate(p.updatedAt)} · ${p.nodeCount} ${p.nodeCount == 1 ? "componente" : "componentes"}',
                  style: TextStyle(fontSize: 14, color: c.grisTexto),
                ),
              ],
            ),
          ),
          PopupMenuButton<_RowAction>(
            tooltip: 'Más acciones',
            icon: Icon(Icons.more_horiz, color: c.grisTexto),
            onSelected: (a) => switch (a) {
              _RowAction.open => home._open(p.id),
              _RowAction.rename => home._rename(p),
              _RowAction.duplicate => home._duplicate(p),
              _RowAction.export => home._export(p),
              _RowAction.delete => home._delete(p),
            },
            itemBuilder: (context) => [
              _mi(context, _RowAction.open, Icons.open_in_new, 'Abrir'),
              _mi(context, _RowAction.rename, Icons.edit_outlined, 'Renombrar'),
              _mi(context, _RowAction.duplicate, Icons.copy_outlined, 'Duplicar'),
              _mi(context, _RowAction.export, Icons.download_rounded, isMobile ? 'Compartir archivo' : 'Guardar como archivo'),
              const PopupMenuDivider(),
              _mi(context, _RowAction.delete, Icons.delete_outline, 'Borrar', danger: true),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_RowAction> _mi(BuildContext context, _RowAction v, IconData icon, String label, {bool danger = false}) {
    final c = context.c;
    return PopupMenuItem(
      value: v,
      child: Row(
        children: [
          Icon(icon, size: 19, color: danger ? c.rojo : c.verde),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: danger ? c.rojo : c.tinta)),
        ],
      ),
    );
  }
}
