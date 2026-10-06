import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum BtnKind { primary, outline, ghost, danger }

/// Botón de píldora (`.btn`, `.btn-primario`, `.btn-borde` de la web).
class Btn extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final Widget? icon;
  final double height;
  final double fontSize;
  final bool expand;
  final String? tooltip;

  const Btn(
    this.label, {
    super.key,
    this.onPressed,
    this.kind = BtnKind.outline,
    this.icon,
    this.height = 44,
    this.fontSize = 16,
    this.expand = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (bg, fg, border, hoverBg, hoverBorder) = switch (kind) {
      BtnKind.primary => (c.verde, c.sobreVerde, c.verde, c.verdeFuerte, c.verdeFuerte),
      BtnKind.outline => (c.papel, c.tinta, c.linea, c.papel, c.verde),
      BtnKind.ghost => (Colors.transparent, c.grisTexto, Colors.transparent, c.verdeSuave, Colors.transparent),
      BtnKind.danger => (c.papel, c.rojo, c.linea, c.papel, c.rojo),
    };
    final disabled = onPressed == null;
    Widget child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: fontSize, color: fg),
          ),
        ),
      ],
    );
    final button = Opacity(
      opacity: disabled ? 0.55 : 1,
      child: _Hoverable(
        enabled: !disabled,
        builder: (hover) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: height,
          padding: EdgeInsets.symmetric(horizontal: height < 40 ? 14 : 20),
          decoration: BoxDecoration(
            color: hover ? hoverBg : bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: hover ? hoverBorder : border, width: 1.5),
          ),
          child: child,
        ),
        onTap: onPressed,
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _Hoverable extends StatefulWidget {
  final bool enabled;
  final Widget Function(bool hover) builder;
  final VoidCallback? onTap;
  const _Hoverable({required this.enabled, required this.builder, this.onTap});
  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    enabled: widget.enabled,
    mouseCursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
    onShowHoverHighlight: (v) => setState(() => _hover = v),
    onShowFocusHighlight: (v) => setState(() => _hover = v),
    actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call())},
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: widget.builder(_hover),
    ),
  );
}

/// Zona pulsable con fondo verde suave al pasar el ratón.
class HoverTile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final EdgeInsets padding;
  final Color? border;
  final Color? hoverBorder;
  final Color? color;
  const HoverTile({
    super.key,
    required this.child,
    this.onTap,
    this.radius = const BorderRadius.all(Radius.circular(10)),
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.border,
    this.hoverBorder,
    this.color,
  });
  @override
  State<HoverTile> createState() => _HoverTileState();
}

class _HoverTileState extends State<HoverTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: widget.border != null ? (widget.color ?? c.papel) : (_hover ? c.verdeSuave : widget.color),
            borderRadius: widget.radius,
            border: widget.border != null
                ? Border.all(color: _hover ? (widget.hoverBorder ?? c.verde) : widget.border!, width: 1.2)
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Botón redondo de icono (tema, cerrar…).
class RoundIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;
  const RoundIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip, this.size = 36});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: HoverTile(
      onTap: onPressed,
      radius: BorderRadius.circular(999),
      padding: EdgeInsets.zero,
      child: SizedBox(width: size, height: size, child: Center(child: icon)),
    ),
  );
}

class ThemeIcon extends StatelessWidget {
  final Color color;
  const ThemeIcon({super.key, required this.color});
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(18, 18), painter: _ThemeIconPainter(color));
}

class _ThemeIconPainter extends CustomPainter {
  final Color color;
  _ThemeIconPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s);
    canvas.drawCircle(
      const Offset(12, 12),
      8,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(Rect.fromCircle(center: const Offset(12, 12), radius: 8), -1.5708, 3.14159, true, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ThemeIconPainter old) => old.color != color;
}

/// Diálogo de confirmación con el estilo de la app.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool danger = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
      content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Text(message)),
      actions: [
        Btn('Cancelar', onPressed: () => Navigator.pop(ctx, false), height: 40),
        Btn(
          confirm,
          onPressed: () => Navigator.pop(ctx, true),
          kind: danger ? BtnKind.danger : BtnKind.primary,
          height: 40,
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Pide un texto (nombre de proyecto…).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String confirm = 'Guardar',
  int maxLength = 60,
}) async {
  final ctl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: maxLength,
          decoration: InputDecoration(labelText: label, counterText: ''),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
      ),
      actions: [
        Btn('Cancelar', onPressed: () => Navigator.pop(ctx), height: 40),
        Btn(confirm, onPressed: () => Navigator.pop(ctx, ctl.text), kind: BtnKind.primary, height: 40),
      ],
    ),
  );
  final v = r?.trim();
  return v == null || v.isEmpty ? null : v;
}

void toast(BuildContext context, String text, {bool error = false}) {
  final c = context.c;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? c.rojo : c.verde, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
        width: 420,
        duration: const Duration(seconds: 4),
      ),
    );
}
