import 'package:flutter/material.dart';

import 'store/project_repository.dart';

/// Servicios de la app al alcance de cualquier pantalla.
class AppScope extends InheritedWidget {
  final ProjectRepository repo;
  final Settings settings;
  final ValueNotifier<ThemeMode> themeMode;

  const AppScope({super.key, required this.repo, required this.settings, required this.themeMode, required super.child});

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  /// Alterna claro/oscuro y lo recuerda.
  void toggleTheme(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    themeMode.value = dark ? ThemeMode.light : ThemeMode.dark;
    settings.set('tema', dark ? 'light' : 'dark');
  }

  @override
  bool updateShouldNotify(AppScope old) => false;
}
