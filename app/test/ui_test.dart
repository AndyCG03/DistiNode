// Pruebas de humo de la interfaz: montan las pantallas a tamaño escritorio y móvil, simulan unos segundos y
// usan los controles principales. Fallan ante cualquier excepción de dibujo o de diseño (desbordamientos).
import 'dart:io';

import 'package:distinode/app_scope.dart';
import 'package:distinode/editor/diagram_canvas.dart';
import 'package:distinode/editor/editor_screen.dart';
import 'package:distinode/guide/guide_screen.dart';
import 'package:distinode/home/home_screen.dart';
import 'package:distinode/sim/templates.dart';
import 'package:distinode/store/diagram_store.dart';
import 'package:distinode/store/project_repository.dart';
import 'package:distinode/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

late Directory tmp;

Widget host(Widget child, {bool dark = false}) {
  final repo = ProjectRepository.at(tmp);
  final settings = Settings.at(File('${tmp.path}/ajustes.json'));
  return AppScope(
    repo: repo,
    settings: settings,
    themeMode: ValueNotifier(dark ? ThemeMode.dark : ThemeMode.light),
    child: MaterialApp(
      theme: buildTheme(DistiColors.light),
      darkTheme: buildTheme(DistiColors.darkTheme),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: child,
    ),
  );
}

void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

DiagramStore storeWith(String templateId) {
  final s = DiagramStore(name: 'Prueba', createdAt: DateTime.now());
  s.loadTemplate(templateById(templateId)!);
  return s;
}

Future<void> runFor(WidgetTester tester, Duration d) async {
  final end = d.inMilliseconds;
  for (var t = 0; t < end; t += 16) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> loadFonts() async {
  final loader = FontLoader(fontFamily);
  for (final w in ['Regular', 'Semibold', 'Bold']) {
    final bytes = File('assets/fonts/SourceSans3-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(loadFonts);
  setUp(() => tmp = Directory.systemTemp.createTempSync('distinode_test'));
  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {
      // Un autoguardado pendiente puede tener abierto el archivo temporal.
    }
  });

  for (final (label, size) in [('escritorio', const Size(1440, 900)), ('móvil', const Size(390, 844))]) {
    group(label, () {
      testWidgets('inicio', (tester) async {
        setSize(tester, size);
        await tester.pumpWidget(host(const HomeScreen()));
        for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
          await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
          await tester.pump();
        }
        expect(find.text('Mis proyectos'), findsOneWidget);
        expect(find.text('Todavía no tienes proyectos'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('editor: simular, seleccionar, propiedades y fallos', (tester) async {
        setSize(tester, size);
        final store = storeWith('alta-disponibilidad');
        await tester.pumpWidget(host(EditorScreen(projectId: 'x', store: store)));
        await tester.pump();
        store.setRunning(true);
        store.setSimOptions(chaos: true, autoCrash: true);
        await runFor(tester, const Duration(seconds: 3));
        expect(find.textContaining('completadas').evaluate().isNotEmpty || find.text('ok/s').evaluate().isNotEmpty, isTrue);

        // Selecciona un servidor pulsando sobre él.
        final canvas = tester.widget<DiagramCanvas>(find.byType(DiagramCanvas));
        final node = store.nodes.values.firstWhere((n) => n.label == 'Servidor 2');
        final origin = tester.getTopLeft(find.byType(DiagramCanvas));
        final p = canvas.controller.toScreen(Offset(node.x + 120, node.y + 30));
        await tester.tapAt(origin + p);
        await tester.pump();
        expect(canvas.controller.selection.nodes, {node.id});
        expect(find.text('Tumbar'), findsOneWidget);
        await tester.ensureVisible(find.text('Tumbar'));
        await tester.tap(find.text('Tumbar'));
        await runFor(tester, const Duration(milliseconds: 500));
        expect(store.nodes[node.id]!.down, isTrue);
        expect(find.text('Revivir'), findsOneWidget);

        // Teclado: Supr borra lo seleccionado.
        await tester.sendKeyEvent(LogicalKeyboardKeyAlias.delete);
        await tester.pump();
        expect(store.nodes.containsKey(node.id), isFalse);
        store.setRunning(false);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('editor vacío y modo oscuro', (tester) async {
        setSize(tester, size);
        final store = DiagramStore(name: 'Vacío', createdAt: DateTime.now());
        await tester.pumpWidget(host(EditorScreen(projectId: 'y', store: store), dark: true));
        await tester.pump();
        expect(find.text('Un lienzo en blanco'), findsOneWidget);
        await tester.tap(find.text('Cargar ejemplo'));
        await tester.pump();
        expect(store.nodes.length, 4);
        await runFor(tester, const Duration(milliseconds: 300));
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('guía', (tester) async {
        setSize(tester, size);
        await tester.pumpWidget(host(const GuideScreen(anchor: 'queue')));
        await tester.pump();
        expect(find.text('Guía de DistiNode'), findsOneWidget);
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -3000));
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}

/// Alias para no importar services solo por la tecla.
class LogicalKeyboardKeyAlias {
  static final delete = LogicalKeyboardKey.delete;
}
