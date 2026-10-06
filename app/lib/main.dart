import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_scope.dart';
import 'home/home_screen.dart';
import 'store/project_repository.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await ProjectRepository.open();
  final settings = await Settings.open();
  final saved = settings['tema'];
  final mode = ValueNotifier<ThemeMode>(
    saved == 'dark'
        ? ThemeMode.dark
        : saved == 'light'
        ? ThemeMode.light
        : ThemeMode.system,
  );
  runApp(AppScope(repo: repo, settings: settings, themeMode: mode, child: const DistiNodeApp()));
}

class DistiNodeApp extends StatelessWidget {
  const DistiNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: scope.themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'DistiNode',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(DistiColors.light),
        darkTheme: buildTheme(DistiColors.darkTheme),
        themeMode: mode,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            child: child!,
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}
