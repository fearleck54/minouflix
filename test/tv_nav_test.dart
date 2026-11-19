import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minouflix/perf.dart';
import 'package:minouflix/ui.dart';

/// navigation à la télécommande : rangées d'affiches dans une liste verticale (comme l'accueil)
Widget _app(List<int> counts, Map<String, FocusNode> nodes) => MaterialApp(
      home: Scaffold(
        body: ListView(cacheExtent: 1800, children: [
          for (var r = 0; r < counts.length; r++)
            SizedBox(
              height: 200,
              child: ListView(
                scrollDirection: Axis.horizontal,
                cacheExtent: 1200,
                children: [
                  for (var c = 0; c < counts[r]; c++)
                    SizedBox(
                      width: 150,
                      child: FocusCard(
                        focusNode: nodes['r$r-c$c'] = FocusNode(),
                        autofocus: r == 0 && c == 0,
                        onTap: () {},
                        child: const SizedBox(width: 140, height: 190),
                      ),
                    ),
                ],
              ),
            ),
        ]),
      ),
    );

String? _focused(Map<String, FocusNode> n) => n.entries.where((e) => e.value.hasFocus).map((e) => e.key).firstOrNull;

Future<void> _press(WidgetTester t, LogicalKeyboardKey k, [int n = 1]) async {
  for (var i = 0; i < n; i++) {
    await t.sendKeyEvent(k);
    await t.pumpAndSettle();
  }
}

void main() {
  setUp(() => Device.tv = true);
  tearDown(() => Device.tv = false);

  testWidgets('droite : jamais de saut à la ligne suivante, bloqué au bout', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    final nodes = <String, FocusNode>{};
    await t.pumpWidget(_app([4, 3, 5], nodes));
    await t.pumpAndSettle();
    expect(_focused(nodes), 'r0-c0');
    await _press(t, LogicalKeyboardKey.arrowRight, 3);
    expect(_focused(nodes), 'r0-c3');
    await _press(t, LogicalKeyboardKey.arrowRight, 3);
    expect(_focused(nodes), 'r0-c3');
  });

  testWidgets('bas : toujours la rangée voisine, même depuis la droite', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    final nodes = <String, FocusNode>{};
    await t.pumpWidget(_app([12, 2, 6], nodes));
    await t.pumpAndSettle();
    await _press(t, LogicalKeyboardKey.arrowRight, 9);
    expect(_focused(nodes), 'r0-c9');
    await _press(t, LogicalKeyboardKey.arrowDown);
    expect(_focused(nodes)?.startsWith('r1-'), isTrue, reason: 'doit descendre sur la 2e rangée, pas sauter à la 3e : ${_focused(nodes)}');
    await _press(t, LogicalKeyboardKey.arrowDown);
    expect(_focused(nodes)?.startsWith('r2-'), isTrue, reason: _focused(nodes));
  });

  testWidgets('haut : on remonte rangée par rangée jusqu\'à la première', (t) async {
    t.view.physicalSize = const Size(1920, 1080);
    t.view.devicePixelRatio = 1;
    final nodes = <String, FocusNode>{};
    await t.pumpWidget(_app([6, 6, 6, 6, 6, 6, 6, 6], nodes));
    await t.pumpAndSettle();
    await _press(t, LogicalKeyboardKey.arrowDown, 7);
    expect(_focused(nodes)?.startsWith('r7-'), isTrue, reason: _focused(nodes));
    await _press(t, LogicalKeyboardKey.arrowUp, 7);
    expect(_focused(nodes)?.startsWith('r0-'), isTrue, reason: 'doit remonter tout en haut : ${_focused(nodes)}');
  });
}
