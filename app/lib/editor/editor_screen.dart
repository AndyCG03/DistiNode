import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../guide/guide_screen.dart';
import '../model/project_file.dart';
import '../sim/components.dart';
import '../sim/templates.dart';
import '../store/diagram_store.dart';
import '../theme/tokens.dart';
import '../widgets/logo.dart';
import '../widgets/templates_ui.dart';
import '../widgets/ui.dart';
import 'diagram_canvas.dart';
import 'editor_controller.dart';
import 'empty_state.dart';
import 'files.dart';
import 'geometry.dart';
import 'notices.dart';
import 'palette.dart';
import 'properties_panel.dart';
import 'sim_bar.dart';
import 'sim_runtime.dart';
import 'supervisor.dart';

const narrowBreakpoint = 768.0;

/// Vista de un proyecto: paleta, lienzo, barra de simulación y propiedades (port de `RoomView.tsx`).
class EditorScreen extends StatefulWidget {
  final String projectId;
  final DiagramStore store;
  const EditorScreen({super.key, required this.projectId, required this.store});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  DiagramStore get store => widget.store;
  final runtime = SimRuntime();
  late final EditorController ctl = EditorController(store);
  late final Supervisor _supervisor = Supervisor(store, runtime);
  final _clock = ValueNotifier<int>(0);
  final _focus = FocusNode(debugLabel: 'editor');
  Timer? _clockTimer;
  Timer? _saveTimer;
  int _syncedGraph = -1;
  int _savedVersion = 0;
  bool _saving = false;
  bool _busyExport = false;

  @override
  void initState() {
    super.initState();
    _savedVersion = store.saveVersion;
    _onStore();
    store.addListener(_onStore);
    _supervisor; // arranca
    _clockTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _clock.value++);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _onStore() {
    if (store.graphVersion != _syncedGraph) {
      _syncedGraph = store.graphVersion;
      runtime.sync(store.nodes, store.edges);
    }
    runtime.setTraffic(store.sim.traffic);
    runtime.running = store.sim.running;
    if (store.saveVersion != _savedVersion) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 400), _save);
    }
  }

  Future<void> _save() async {
    if (_saving) {
      _saveTimer = Timer(const Duration(milliseconds: 200), _save);
      return;
    }
    final version = store.saveVersion;
    if (version == _savedVersion) return;
    _saving = true;
    try {
      await AppScope.of(context).repo.save(widget.projectId, store);
      _savedVersion = version;
    } catch (e) {
      if (mounted) toast(context, 'No se pudo guardar: $e', error: true);
    } finally {
      _saving = false;
    }
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    _saveTimer?.cancel();
    _clockTimer?.cancel();
    _supervisor.dispose();
    _clock.dispose();
    _focus.dispose();
    ctl.dispose();
    runtime.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    _saveTimer?.cancel();
    store.setRunning(false);
    await _save();
    if (mounted) Navigator.of(context).pop(true);
  }

  bool get _narrow => MediaQuery.of(context).size.width < narrowBreakpoint;

  // ── Acciones ────────────────────────────────────────────
  void _addAtCenter(ComponentKind kind) {
    final c = ctl.viewCenter;
    final spot = freeSpot(c.dx - nodeW / 2, c.dy - nodeH / 2, store.nodes.values.map((n) => Offset(n.x, n.y)));
    final node = store.addNode(kind, spot.dx, spot.dy);
    ctl.select(Selection({node.id}));
  }

  void _loadTemplate(Template t) {
    store.loadTemplate(t);
    ctl.clearSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) => ctl.fitView(narrow: _narrow));
  }

  Future<void> _openTemplates() async {
    final t = await showTemplateDialog(context, replacing: !store.isEmpty);
    if (t != null) _loadTemplate(t);
  }

  void _openGuide([ComponentKind? kind]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuideScreen(anchor: kind?.name)));
  }

  Future<void> _exportImage() async {
    if (store.isEmpty || _busyExport) return;
    setState(() => _busyExport = true);
    try {
      final png = await diagramToPng(store, runtime.polylines, runtime.stats, context.c);
      if (png != null && mounted) {
        final ok = await saveFile(
          context,
          name: '${fileSlug(store.name)}.png',
          bytes: png,
          mime: 'image/png',
          extensionLabel: 'Imagen PNG',
          extensions: const ['png'],
        );
        if (ok && mounted && !isMobile) toast(context, 'Imagen guardada.');
      }
    } catch (e) {
      if (mounted) toast(context, 'No se pudo crear la imagen.', error: true);
    } finally {
      if (mounted) setState(() => _busyExport = false);
    }
  }

  Future<void> _saveAsFile() async {
    if (store.isEmpty) return;
    try {
      final ok = await saveProjectFile(context, store);
      if (ok && mounted && !isMobile) toast(context, 'Proyecto guardado como archivo.');
    } catch (e) {
      if (mounted) toast(context, 'No se pudo guardar el archivo.', error: true);
    }
  }

  Future<void> _import() async {
    try {
      final bytes = await pickProjectFile();
      if (bytes == null || !mounted) return;
      final parsed = await _parse(bytes);
      if (!mounted) return;
      if (!store.isEmpty &&
          !await confirmDialog(
            context,
            title: 'Importar proyecto',
            message: 'Importar «${parsed.name}» sustituye el diagrama actual. ¿Seguir?',
            confirm: 'Importar',
          )) {
        return;
      }
      store.replaceDiagram(
        parsed.nodes,
        parsed.edges,
        traffic: parsed.sim.traffic,
        chaos: parsed.sim.chaos,
        autoCrash: parsed.sim.autoCrash,
        restartSec: parsed.sim.restartSec,
      );
      ctl.clearSelection();
      if (mounted) toast(context, 'Importado: ${parsed.nodes.length} componentes.');
      WidgetsBinding.instance.addPostFrameCallback((_) => ctl.fitView(narrow: _narrow));
    } on ProjectParseError catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, 'No se pudo abrir el archivo.', error: true);
    }
  }

  Future<ParsedProject> _parse(List<int> bytes) async {
    try {
      return parseProject(jsonDecodeSafe(bytes));
    } on FormatException {
      throw const ProjectParseError('El archivo no es un JSON válido.');
    }
  }

  Future<void> _rename() async {
    final v = await promptText(context, title: 'Renombrar proyecto', label: 'Nombre', initial: store.name);
    if (v != null) store.rename(v);
  }

  // ── Teclado ─────────────────────────────────────────────
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (k == LogicalKeyboardKey.space && !ctrl) {
      store.setRunning(!store.sim.running);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) {
      final s = ctl.selection;
      if (s.isEmpty) return KeyEventResult.ignored;
      store.removeElements(s.nodes, s.edges);
      ctl.clearSelection();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.escape) {
      ctl.clearSelection();
      return KeyEventResult.handled;
    }
    if (ctrl && k == LogicalKeyboardKey.keyA) {
      ctl.select(Selection(store.nodes.keys.toSet()));
      return KeyEventResult.handled;
    }
    if (ctrl && k == LogicalKeyboardKey.keyS) {
      _saveAsFile();
      return KeyEventResult.handled;
    }
    if (ctrl && k == LogicalKeyboardKey.keyE) {
      _exportImage();
      return KeyEventResult.handled;
    }
    if (ctrl && k == LogicalKeyboardKey.keyO) {
      _import();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.equal || k == LogicalKeyboardKey.numpadAdd) {
      ctl.zoomBy(1.2);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.minus || k == LogicalKeyboardKey.numpadSubtract) {
      ctl.zoomBy(1 / 1.2);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.digit0 || k == LogicalKeyboardKey.numpad0) {
      ctl.fitView(narrow: _narrow);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final narrow = _narrow;
    final wideMetrics = MediaQuery.of(context).size.width >= 1024;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: Focus(
            focusNode: _focus,
            onKeyEvent: _onKey,
            child: Column(
              children: [
                _Header(state: this, compact: narrow),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!narrow)
                        Palette(onAdd: _addAtCenter, onTemplates: _openTemplates, onGuide: _openGuide),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DiagramCanvas(
                                store: store,
                                runtime: runtime,
                                controller: ctl,
                                narrow: narrow,
                                clock: _clock,
                                onInteract: () {
                                  if (!_focus.hasFocus) _focus.requestFocus();
                                },
                              ),
                            ),
                            ListenableBuilder(
                              listenable: store,
                              builder: (context, _) => store.isEmpty
                                  ? Positioned.fill(child: EmptyState(onLoad: _loadTemplate, onAll: _openTemplates))
                                  : const SizedBox.shrink(),
                            ),
                            if (!narrow)
                              Positioned(
                                right: 16,
                                bottom: 100,
                                child: _ZoomControls(ctl: ctl, narrow: narrow),
                              ),
                            Positioned(
                              left: narrow ? 12 : 16,
                              top: narrow ? 12 : null,
                              bottom: narrow ? null : 96,
                              child: Notices(store: store),
                            ),
                            Positioned(
                              left: narrow ? 8 : 16,
                              right: narrow ? 8 : 16,
                              bottom: narrow ? 8 : 16,
                              child: Center(
                                child: SimBar(store: store, runtime: runtime, compact: narrow, sparklines: wideMetrics),
                              ),
                            ),
                            if (narrow)
                              Positioned(
                                right: 16,
                                bottom: 128,
                                child: FloatingActionButton(
                                  onPressed: () => showAddSheet(
                                    context,
                                    onAdd: _addAtCenter,
                                    onTemplates: _openTemplates,
                                    onGuide: _openGuide,
                                  ),
                                  backgroundColor: c.verde,
                                  foregroundColor: c.sobreVerde,
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  focusElevation: 2,
                                  hoverElevation: 3,
                                  tooltip: 'Añadir componente',
                                  child: const Icon(Icons.add, size: 28),
                                ),
                              ),
                            if (narrow) _MobileProperties(state: this),
                          ],
                        ),
                      ),
                      if (!narrow)
                        ListenableBuilder(
                          listenable: Listenable.merge([store, ctl]),
                          builder: (context, _) => PropertiesPanel.hasContent(store, ctl)
                              ? Container(
                                  width: 296,
                                  decoration: BoxDecoration(
                                    color: c.papel,
                                    border: Border(left: BorderSide(color: c.linea)),
                                  ),
                                  child: SingleChildScrollView(child: _props()),
                                )
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _props() => PropertiesPanel(store: store, runtime: runtime, controller: ctl, clock: _clock, onHelp: _openGuide);
}

/// Propiedades en una hoja inferior (pantallas estrechas).
class _MobileProperties extends StatelessWidget {
  final _EditorScreenState state;
  const _MobileProperties({required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ListenableBuilder(
      listenable: Listenable.merge([state.store, state.ctl]),
      builder: (context, _) {
        if (!PropertiesPanel.hasContent(state.store, state.ctl)) return const SizedBox.shrink();
        final nodeId = state.ctl.selection.singleNode;
        final title = nodeId != null ? state.store.nodes[nodeId]!.label : 'Conexión';
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
            decoration: BoxDecoration(
              color: c.papel,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: c.linea)),
              boxShadow: c.sombra,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      RoundIconButton(
                        icon: Icon(Icons.close, size: 20, color: c.grisTexto),
                        onPressed: state.ctl.clearSelection,
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                ),
                Flexible(child: SingleChildScrollView(child: state._props())),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZoomControls extends StatelessWidget {
  final EditorController ctl;
  final bool narrow;
  const _ZoomControls({required this.ctl, required this.narrow});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget b(IconData icon, String tip, VoidCallback onTap) => Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        canRequestFocus: false,
        child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 18, color: c.tinta)),
      ),
    );
    return Material(
      color: c.papel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: c.linea)),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          b(Icons.add, 'Acercar (+)', () => ctl.zoomBy(1.2)),
          Divider(height: 1, color: c.linea),
          b(Icons.remove, 'Alejar (−)', () => ctl.zoomBy(1 / 1.2)),
          Divider(height: 1, color: c.linea),
          b(Icons.fit_screen_outlined, 'Encuadrar todo (0)', () => ctl.fitView(narrow: narrow)),
        ],
      ),
    );
  }
}

enum _MenuAction { image, save, import, rename }

class _Header extends StatelessWidget {
  final _EditorScreenState state;
  final bool compact;
  const _Header({required this.state, required this.compact});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final store = state.store;
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
      decoration: BoxDecoration(
        color: c.papel,
        border: Border(bottom: BorderSide(color: c.linea)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Volver a mis proyectos',
            child: HoverTile(
              onTap: state._leave,
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Icon(Icons.arrow_back_rounded, size: 18, color: c.grisTexto),
                  const SizedBox(width: 6),
                  const LogoMark(size: 28),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('/', style: TextStyle(color: c.linea, fontSize: 18)),
          ),
          Flexible(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => Tooltip(
                message: 'Renombrar',
                child: HoverTile(
                  onTap: state._rename,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    store.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: c.verdeSuave, borderRadius: BorderRadius.circular(999)),
              child: Text(
                'Se guarda solo en este equipo',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.verde),
              ),
            ),
          ],
          const Spacer(),
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => PopupMenuButton<_MenuAction>(
              tooltip: 'Exportar imagen, guardar o importar el proyecto',
              position: PopupMenuPosition.under,
              onSelected: (a) => switch (a) {
                _MenuAction.image => state._exportImage(),
                _MenuAction.save => state._saveAsFile(),
                _MenuAction.import => state._import(),
                _MenuAction.rename => state._rename(),
              },
              itemBuilder: (context) => [
                _item(
                  context,
                  _MenuAction.image,
                  Icons.image_outlined,
                  state._busyExport ? 'Creando imagen…' : 'Exportar imagen',
                  isMobile ? 'PNG del diagrama completo' : 'PNG del diagrama completo · Ctrl+E',
                  enabled: !store.isEmpty,
                ),
                _item(
                  context,
                  _MenuAction.save,
                  Icons.download_rounded,
                  isMobile ? 'Compartir proyecto' : 'Guardar como archivo',
                  isMobile ? 'Archivo .distinode.json' : 'Archivo .distinode.json · Ctrl+S',
                  enabled: !store.isEmpty,
                ),
                _item(
                  context,
                  _MenuAction.import,
                  Icons.upload_rounded,
                  'Importar proyecto…',
                  'Sustituye el diagrama actual',
                ),
                const PopupMenuDivider(),
                _item(context, _MenuAction.rename, Icons.edit_outlined, 'Renombrar', 'Cambia el nombre del proyecto'),
              ],
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(999)),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined, size: 19, color: c.grisTexto),
                    if (!compact) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Proyecto',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.grisTexto),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (!compact)
            Btn('Guía', kind: BtnKind.ghost, height: 34, fontSize: 14, onPressed: state._openGuide),
          RoundIconButton(
            icon: ThemeIcon(color: c.grisTexto),
            tooltip: 'Modo claro / oscuro',
            onPressed: () => AppScope.of(context).toggleTheme(context),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_MenuAction> _item(
    BuildContext context,
    _MenuAction value,
    IconData icon,
    String title,
    String sub, {
    bool enabled = true,
  }) {
    final c = context.c;
    return PopupMenuItem(
      value: value,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: SizedBox(
          width: 230,
          child: Row(
            children: [
              Icon(icon, size: 20, color: c.verde),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(sub, style: TextStyle(fontSize: 12, color: c.grisTexto)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
