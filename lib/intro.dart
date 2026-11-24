import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_svg/flutter_svg.dart';

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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
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
                    offset: Offset(0, lite ? 0 : -6 * _sin(a)),      // le chat flotte
                    child: Stack(alignment: Alignment.center, children: [
                      Container(
                        width: h * 2.4,
                        height: h * 2.4,
                        decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color.fromRGBO(229, 72, 77, 0.18 + 0.24 * glow), const Color(0x00E5484D)])),
                      ),
                      lite
                          ? SvgPicture.asset('assets/logo.svg', height: h)
                          : ShaderMask(
                              blendMode: BlendMode.srcATop,
                              shaderCallback: (r) {
                                final x = -0.5 + 2.0 * t;
                                return LinearGradient(begin: Alignment(x - 0.4, -0.3), end: Alignment(x + 0.4, 0.3), colors: const [Color(0x00FFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)]).createShader(r);
                              },
                              child: SvgPicture.asset('assets/logo.svg', height: h),
                            ),
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
