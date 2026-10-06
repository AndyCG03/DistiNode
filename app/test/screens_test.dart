// Capturas de pantalla para revisar el diseño y para la documentación.
// Se ejecuta a mano:  flutter test --update-goldens --tags capturas
@Tags(['capturas'])
library;

import 'dart:io';

import 'package:distinode/app_scope.dart';
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

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await loader.load();
}

void main() {
  late Directory tmp;
  setUpAll(() async {
    await _load(fontFamily, [for (final w in ['Regular', 'Semibold', 'Bold']) 'assets/fonts/SourceSans3-$w.ttf']);
    final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    await _load('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
  });
  setUp(() => tmp = Directory.systemTemp.createTempSync('distinode_caps'));

  Widget host(Widget child, bool dark) => AppScope(
    repo: ProjectRepository.at(tmp),
    settings: Settings.at(File('${tmp.path}/a.json')),
    themeMode: ValueNotifier(dark ? ThemeMode.dark : ThemeMode.light),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(DistiColors.light),
      darkTheme: buildTheme(DistiColors.darkTheme),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: child,
    ),
  );

  Future<void> shot(WidgetTester tester, String name, Size size, Widget w, {bool dark = false, Future<void> Function()? act}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(host(w, dark));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    if (act != null) await act();
    for (var t = 0; t < 2500; t += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('capturas/$name.png'));
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
  }

  DiagramStore running(String id) {
    final s = DiagramStore(name: templateById(id)!.name, createdAt: DateTime.now());
    s.loadTemplate(templateById(id)!);
    s.setRunning(true);
    return s;
  }

  testWidgets('capturas', (tester) async {
    const desk = Size(1440, 900);
    const phone = Size(412, 892);
    await tester.runAsync(() async {
      final repo = ProjectRepository.at(tmp);
      for (final id in ['tienda-online', 'microservicios', 'iot']) {
        await repo.create(templateById(id)!.name);
      }
    });
    await shot(tester, 'inicio', desk, const HomeScreen());
    await shot(tester, 'inicio-movil', phone, const HomeScreen());
    await shot(tester, 'editor', desk, EditorScreen(projectId: 'a', store: running('tienda-online')));
    final micro = running('microservicios');
    await shot(
      tester,
      'editor-oscuro',
      desk,
      EditorScreen(projectId: 'b', store: micro),
      dark: true,
      act: () async {
        micro.setTraffic(140);
        final n = micro.nodes.values.firstWhere((n) => n.label == 'Servicio Catálogo');
        micro.setNodeState(n.id, slow: true);
      },
    );
    final mob = running('alta-disponibilidad');
    await shot(tester, 'editor-movil', phone, EditorScreen(projectId: 'c', store: mob));
    await shot(tester, 'guia', desk, const GuideScreen());
    await shot(tester, 'guia-movil', phone, const GuideScreen(anchor: 'cache'));
  });
}
