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

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = Device.tv ? 150.0 : 112.0;
    final lite = Perf.lite || MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: const Cubic(0.2, 0.8, 0.2, 1),
            builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.88 + 0.12 * v, child: child)),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final t = _c.value;
                final glow = 0.5 - 0.5 * (t * 2 - 1).abs();      // 0 → 1 → 0
                Widget logo = SvgPicture.asset('assets/logo.svg', height: h);
                if (!lite) {
                  logo = ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (r) {
                      final x = -0.5 + 2.0 * t;
                      return LinearGradient(begin: Alignment(x - 0.4, -0.3), end: Alignment(x + 0.4, 0.3), colors: const [Color(0x00FFFFFF), Color(0x55FFFFFF), Color(0x00FFFFFF)]).createShader(r);
                    },
                    child: logo,
                  );
                }
                return Stack(alignment: Alignment.center, children: [
                  Container(
                    width: h * 2.3,
                    height: h * 2.3,
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color.fromRGBO(229, 72, 77, 0.16 + 0.22 * glow), const Color(0x00E5484D)])),
                  ),
                  logo,
                ]);
              },
            ),
          ),
          if (widget.status != null) ...[
            const SizedBox(height: 30),
            Text(widget.status!, textAlign: TextAlign.center, style: T(15, w: 600, color: kMut, h: 1.4)),
          ],
        ]),
      ),
    );
  }
}
