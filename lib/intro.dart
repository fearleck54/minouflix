import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;

import 'perf.dart';
import 'ui.dart';

/// écran d'attente de marque (à la place du rond de chargement) : le chat apparaît en fondu avec un léger zoom,
/// un halo rouge respire derrière lui et un reflet de lumière le traverse ; la télé garde seulement le fondu et le halo
class BrandIntro extends StatefulWidget {
  final String? status;
  const BrandIntro({super.key, this.status});
  @override
  State<BrandIntro> createState() => _BrandIntroState();
}

class _BrandIntroState extends State<BrandIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  static const _lines = ['Le chat s\'étire…', 'On prépare le pop-corn…', 'Allumage de l\'écran…', 'Réglage du son…', 'Chargement de ta bibliothèque…'];
  int _n = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 2200), (_) => mounted ? setState(() => _n = (_n + 1) % _lines.length) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = Device.tv ? 170.0 : 120.0;
    final lite = Perf.lite || MediaQuery.of(context).disableAnimations;
    final msg = widget.status ?? _lines[_n];
    return Scaffold(
      backgroundColor: kBg,
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final glow = 0.5 - 0.5 * (t * 2 - 1).abs();      // 0 → 1 → 0
          final a = lite ? 0.0 : 2 * 3.14159265 * t;
          return Stack(children: [
            // lueurs qui dérivent doucement derrière le chat
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: Alignment(-0.6 + 0.25 * _sin(a), -0.5 + 0.2 * _sin(a + 1.5)), radius: 1.1, colors: const [Color(0x2EE5484D), Color(0x00E5484D)]),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(center: Alignment(0.7 - 0.25 * _sin(a + 0.8), 0.6 - 0.2 * _sin(a)), radius: 1.0, colors: const [Color(0x245B8CFF), Color(0x005B8CFF)]),
                ),
              ),
            ),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1000),
                  curve: const Cubic(0.2, 0.8, 0.2, 1),
                  builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.8 + 0.2 * v, child: child)),
                  child: Transform.translate(
                    offset: Offset(0, lite ? 0 : -4 * _sin(a)),      // le chat flotte
                    child: Stack(alignment: Alignment.center, children: [
                      Container(
                        width: h * 2.4,
                        height: h * 2.4,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color.fromRGBO(229, 72, 77, 0.18 + 0.24 * glow), const Color(0x00E5484D)])),
                      ),
                      CustomPaint(size: Size(h, h), painter: _CatPainter(t)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1300),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child)),
                  child: Text('MinouFlix', style: T(Device.tv ? 44 : 34, w: 800, ls: 0.01)),
                ),
                const SizedBox(height: 34),
                // barre de chargement : un reflet la parcourt
                SizedBox(
                  width: Device.tv ? 300 : 220,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: Stack(children: [
                      Container(color: const Color(0x1FFFFFFF)),
                      FractionallySizedBox(
                        alignment: Alignment(-1 + 2.6 * t - 0.3, 0),
                        widthFactor: 0.35,
                        child: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0x00E5484D), Color(0xFFE5484D), Color(0x00E5484D)]))),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 24,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(msg, key: ValueKey(msg), textAlign: TextAlign.center, style: T(Device.tv ? 17 : 15, w: 600, color: kMut)),
                  ),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  double _sin(double x) => math.sin(x);
}

/// le chat du logo dessiné à la main (même formes que assets/logo.svg) pour pouvoir le faire bouger : respiration, tête qui penche,
/// clignement des yeux, oreille qui frétille, queue qui balaie. Quelques ovales seulement : léger même avec 1 Go de mémoire.
class _CatPainter extends CustomPainter {
  final double t;      // 0 → 1, boucle de 3,2 s
  _CatPainter(this.t);

  static const _dark = Color(0xFF6B0000), _red = Color(0xFFFF2D45), _ink = Color(0xFF060610);

  double _bump(double c, double w) {      // 0 → 1 → 0 autour de c (largeur w), en boucle
    var d = (t - c).abs();
    if (d > 0.5) d = 1 - d;
    return d >= w ? 0 : 0.5 + 0.5 * math.cos(math.pi * d / w);
  }

  void _poly(Canvas c, List<Offset> p, Color col) {
    c.drawPath(Path()..addPolygon(p, true), Paint()..color = col);
  }

  @override
  void paint(Canvas c, Size size) {
    final k = size.width / 100, a = 2 * math.pi * t;
    c.save();
    c.scale(k);
    final grad = Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF2D45), Color(0xFF8B0000)]).createShader(const Rect.fromLTWH(0, 0, 100, 100));
    // queue : balaie d'un côté à l'autre
    c.save();
    c.translate(78, 70);
    c.rotate(0.28 * math.sin(a * 2));
    c.translate(-78, -70);
    c.drawPath(Path()..moveTo(78, 72)..quadraticBezierTo(92, 60, 88, 45)..quadraticBezierTo(84, 38, 80, 42)..quadraticBezierTo(84, 55, 76, 68)..close(), Paint()..color = _dark);
    c.restore();
    // pattes avant : petit pétrissage en alternance
    c.drawOval(Rect.fromCenter(center: Offset(36, 83 - 1.6 * math.max(0, math.sin(a * 3))), width: 20, height: 12), Paint()..color = _dark);
    c.drawOval(Rect.fromCenter(center: Offset(64, 83 - 1.6 * math.max(0, -math.sin(a * 3))), width: 20, height: 12), Paint()..color = _dark);
    // corps : respire
    c.save();
    c.translate(50, 86);
    c.scale(1 + 0.012 * math.sin(a * 2), 1 + 0.025 * math.sin(a * 2));
    c.translate(-50, -86);
    c.drawOval(Rect.fromCenter(center: const Offset(50, 62), width: 56, height: 48), grad);
    c.restore();
    // tête : penche doucement
    c.save();
    c.translate(50, 56);
    c.rotate(0.07 * math.sin(a));
    c.translate(-50, -56);
    // oreilles (la droite frétille deux fois par boucle)
    _poly(c, const [Offset(30, 24), Offset(22, 6), Offset(40, 18)], _dark);
    _poly(c, const [Offset(32, 22), Offset(26, 10), Offset(38, 19)], _red);
    final tw = 0.22 * _bump(0.62, 0.05) * math.sin(a * 14);
    c.save();
    c.translate(66, 22);
    c.rotate(tw);
    c.translate(-66, -22);
    _poly(c, const [Offset(70, 24), Offset(78, 6), Offset(60, 18)], _dark);
    _poly(c, const [Offset(68, 22), Offset(74, 10), Offset(62, 19)], _red);
    c.restore();
    c.drawOval(Rect.fromCenter(center: const Offset(50, 38), width: 44, height: 40), grad);
    // yeux : clignent, et regardent à gauche puis à droite
    final blink = 1 - 0.92 * math.max(_bump(0.30, 0.025), _bump(0.80, 0.025));
    final look = 1.6 * math.sin(a);
    for (final x in const [42.0, 58.0]) {
      c.drawOval(Rect.fromCenter(center: Offset(x, 36), width: 10, height: 12 * blink), Paint()..color = _ink);
      if (blink > 0.5) c.drawOval(Rect.fromCenter(center: Offset(x + 1.5 + look * 0.5, 34), width: 3, height: 4 * blink), Paint()..color = const Color(0x99FFFFFF));
    }
    c.drawOval(Rect.fromCenter(center: const Offset(50, 43), width: 6, height: 4), Paint()..color = _ink);
    // moustaches : frémissent
    final w = Paint()
      ..color = _ink
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final f = 1.2 * math.sin(a * 4);
    c.drawLine(const Offset(47, 43), Offset(28, 40 + f), w);
    c.drawLine(const Offset(47, 44), Offset(28, 46 - f), w);
    c.drawLine(const Offset(53, 43), Offset(72, 40 + f), w);
    c.drawLine(const Offset(53, 44), Offset(72, 46 - f), w);
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(_CatPainter o) => o.t != t;
}
