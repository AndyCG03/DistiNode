import 'package:flutter/material.dart';

/// Sistema de diseño — identidad CUJAE. Mismos tokens que `src/app/globals.css`.
@immutable
class DistiColors extends ThemeExtension<DistiColors> {
  final Color verde;
  final Color verdeFuerte;
  final Color verdeSuave;
  final Color sobreVerde;
  final Color gris;
  final Color grisTexto;
  final Color grisTren;
  final Color tinta;
  final Color papel;
  final Color fondo;
  final Color linea;
  final Color punto;
  final Color ambar;
  final Color rojo;
  final List<BoxShadow> sombra;
  final bool dark;

  const DistiColors({
    required this.verde,
    required this.verdeFuerte,
    required this.verdeSuave,
    required this.sobreVerde,
    required this.gris,
    required this.grisTexto,
    required this.grisTren,
    required this.tinta,
    required this.papel,
    required this.fondo,
    required this.linea,
    required this.punto,
    required this.ambar,
    required this.rojo,
    required this.sombra,
    required this.dark,
  });

  static const light = DistiColors(
    verde: Color(0xFF00704F),
    verdeFuerte: Color(0xFF005A3F),
    verdeSuave: Color(0xFFE3F1EB),
    sobreVerde: Color(0xFFFFFFFF),
    gris: Color(0xFFA6A6A6),
    grisTexto: Color(0xFF5D6561),
    grisTren: Color(0xFF7A7F7C),
    tinta: Color(0xFF14211C),
    papel: Color(0xFFFFFFFF),
    fondo: Color(0xFFF3F6F4),
    linea: Color(0xFFD9E1DD),
    punto: Color(0xFFC9D3CE),
    ambar: Color(0xFFB86E00),
    rojo: Color(0xFFC2362F),
    sombra: [BoxShadow(color: Color(0x40004632), blurRadius: 18, offset: Offset(0, 6), spreadRadius: -8)],
    dark: false,
  );

  static const darkTheme = DistiColors(
    verde: Color(0xFF2BA77B),
    verdeFuerte: Color(0xFF4CC496),
    verdeSuave: Color(0xFF143128),
    sobreVerde: Color(0xFF04130D),
    gris: Color(0xFFA6A6A6),
    grisTexto: Color(0xFFA3ADA8),
    grisTren: Color(0xFFA6A6A6),
    tinta: Color(0xFFE8EEEB),
    papel: Color(0xFF16201C),
    fondo: Color(0xFF0D1512),
    linea: Color(0xFF2A3832),
    punto: Color(0xFF24312B),
    ambar: Color(0xFFF0A93A),
    rojo: Color(0xFFF06A60),
    sombra: [BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -10)],
    dark: true,
  );

  @override
  DistiColors copyWith() => this;

  @override
  DistiColors lerp(ThemeExtension<DistiColors>? other, double t) => t < 0.5 ? this : (other as DistiColors? ?? this);
}

extension DistiContext on BuildContext {
  DistiColors get c => Theme.of(this).extension<DistiColors>()!;
}

const fontFamily = 'SourceSans3';

/// Cifras tabulares (como la clase `.cifras` de la web).
const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme(DistiColors c) {
  final base = ThemeData(
    useMaterial3: true,
    brightness: c.dark ? Brightness.dark : Brightness.light,
    fontFamily: fontFamily,
    colorScheme: ColorScheme(
      brightness: c.dark ? Brightness.dark : Brightness.light,
      primary: c.verde,
      onPrimary: c.sobreVerde,
      secondary: c.verde,
      onSecondary: c.sobreVerde,
      error: c.rojo,
      onError: Colors.white,
      surface: c.papel,
      onSurface: c.tinta,
      surfaceContainerHighest: c.fondo,
      outline: c.linea,
      outlineVariant: c.linea,
    ),
    scaffoldBackgroundColor: c.fondo,
    canvasColor: c.papel,
    dividerColor: c.linea,
    extensions: [c],
  );
  final text = base.textTheme.apply(bodyColor: c.tinta, displayColor: c.tinta, fontFamily: fontFamily);
  return base.copyWith(
    textTheme: text.copyWith(
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 16, height: 1.4),
      bodySmall: text.bodySmall?.copyWith(fontSize: 13, color: c.grisTexto),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.tinta, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: c.papel, fontSize: 14, fontFamily: fontFamily),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      waitDuration: const Duration(milliseconds: 350),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.papel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.linea)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.papel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.linea)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.papel,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.linea,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.tinta,
      contentTextStyle: TextStyle(color: c.papel, fontFamily: fontFamily, fontSize: 15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: c.papel,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: c.grisTexto),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.linea, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.verde, width: 1.5),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 6,
      activeTrackColor: c.verde,
      inactiveTrackColor: c.linea,
      thumbColor: c.papel,
      overlayColor: c.verde.withValues(alpha: 0.12),
      thumbShape: _RingThumb(c.verde, c.papel),
      trackShape: const RoundedRectSliderTrackShape(),
      showValueIndicator: ShowValueIndicator.never,
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.verde, selectionColor: c.verdeSuave),
    scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStatePropertyAll(c.linea)),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.verde),
  );
}

/// Pulgar del deslizador: anillo verde sobre papel (como `.rango` en la web).
class _RingThumb extends SliderComponentShape {
  final Color ring;
  final Color fill;
  const _RingThumb(this.ring, this.fill);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(18, 18);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 9, Paint()..color = fill);
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }
}

/// Formato de números como `Intl.NumberFormat("es", { maximumFractionDigits: 0 })`.
String fmt(num v) {
  if (!v.isFinite) return '0';
  final n = v.round();
  final neg = n < 0;
  final s = n.abs().toString();
  if (s.length < 5) return neg ? '-$s' : s; // el español no agrupa los números de 4 cifras
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return neg ? '-$buf' : buf.toString();
}

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _monthsShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];

/// "6 de octubre de 2026"
String longDate(DateTime d) => '${d.day} de ${_months[d.month - 1]} de ${d.year}';

/// "6 oct", o "6 oct 2025" si no es de este año; "hoy, 14:05" si es de hoy.
String shortDate(DateTime d) {
  final now = DateTime.now();
  final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (d.year == now.year && d.month == now.month && d.day == now.day) return 'hoy, $hm';
  final y = now.subtract(const Duration(days: 1));
  if (d.year == y.year && d.month == y.month && d.day == y.day) return 'ayer, $hm';
  final base = '${d.day} ${_monthsShort[d.month - 1]}';
  return d.year == now.year ? base : '$base ${d.year}';
}
