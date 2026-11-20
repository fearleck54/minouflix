import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import 'perf.dart';
import 'ui.dart';

/// grille de cartes à choisir (comme « Quelle langue préfères-tu ? ») : la carte choisie est pleine, le curseur de la télécommande arrive dessus
class ChoiceGrid extends StatelessWidget {
  final List<(String, String)> options;
  final String selected;
  final Future<void> Function(String) onPick;
  const ChoiceGrid({super.key, required this.options, required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final cols = Device.tv ? 3 : (isWide(context) ? 3 : 2);
    final firstSel = options.indexWhere((o) => o.$1 == selected);
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final cw = (c.maxWidth - gap * (cols - 1)) / cols;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(spacing: gap, runSpacing: gap, children: [
          for (final (i, o) in options.indexed)
            SizedBox(
              width: cw,
              child: ChoiceCard(
                label: o.$2,
                selected: o.$1 == selected,
                autofocus: Device.tv && i == (firstSel < 0 ? 0 : firstSel),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onPick(o.$1);
                },
              ),
            ),
        ]),
      );
    });
  }
}

class ChoiceCard extends StatelessWidget {
  final String label;
  final bool selected, autofocus;
  final VoidCallback onTap;
  const ChoiceCard({super.key, required this.label, required this.selected, required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) => FocusCard(
        radius: 18,
        focusScale: Device.tv ? 1.05 : 1.02,
        autofocus: autofocus,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: kBg2,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: selected ? const [kAccent, Color(0xFF3B5FD6)] : const [Color(0x1A5B8CFF), Color(0x0F5B8CFF)]),
            border: Border.all(color: selected ? const Color(0x59FFFFFF) : kEdge, width: selected ? 1.5 : 1),
          ),
          child: Row(children: [
            Expanded(child: Text(label, maxLines: 3, style: T(15, w: 650, h: 1.15))),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: selected ? 1 : 0.4,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 140),
                child: Container(width: 22, height: 22, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF16203A))),
              ),
            ),
          ]),
        ),
      );
}
