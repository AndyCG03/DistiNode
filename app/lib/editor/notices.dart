import 'dart:async';

import 'package:flutter/material.dart';

import '../store/diagram_store.dart';
import '../theme/tokens.dart';

/// Avisos breves del sistema (caos, sobrecarga, reinicios).
class Notices extends StatefulWidget {
  final DiagramStore store;
  const Notices({super.key, required this.store});
  @override
  State<Notices> createState() => _NoticesState();
}

class _Item {
  final int id;
  final Notice n;
  _Item(this.id, this.n);
}

class _NoticesState extends State<Notices> {
  final _items = <_Item>[];
  final _timers = <Timer>[];
  int _seq = 0;
  late void Function() _off;

  @override
  void initState() {
    super.initState();
    _off = widget.store.onNotice((n) {
      if (!n.alert || !mounted) return;
      final id = ++_seq;
      setState(() {
        _items.add(_Item(id, n));
        if (_items.length > 4) _items.removeAt(0);
      });
      _timers.add(
        Timer(const Duration(milliseconds: 3500), () {
          if (mounted) setState(() => _items.removeWhere((i) => i.id == id));
        }),
      );
    });
  }

  @override
  void dispose() {
    _off();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in _items)
            TweenAnimationBuilder<double>(
              key: ValueKey(i.id),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset(0, 6 * (1 - v)), child: child),
              ),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
                decoration: BoxDecoration(
                  color: c.papel,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.linea),
                  boxShadow: c.sombra,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.rojo),
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(i.n.text, style: const TextStyle(fontSize: 14))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
