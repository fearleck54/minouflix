import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'l10n.dart';
import 'onb_prefs.dart';
import 'perf.dart';
import 'store.dart';
import 'ui.dart';

/// Parcours de configuration d'un nouveau compte (après la saisie des identifiants IPTV) :
/// langue, version audio, goûts, récap. Rien n'est écrit dans les réglages avant le récap.
/// `redo` : relancé depuis Réglages (préremplit, ne touche pas aux catégories).
class OnboardingFlow extends StatefulWidget {
  final VoidCallback onDone;
  final bool redo;
  const OnboardingFlow({super.key, required this.onDone, this.redo = false});
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

String _t(String fr, String en) => L.en ? en : fr;

class _Taste {
  final String id, fr, en;
  final IconData icon;
  final Color a, b;
  final bool darkText;
  const _Taste(this.id, this.fr, this.en, this.icon, this.a, this.b, {this.darkText = false});
  String get label => _t(fr, en);
}

const _tastes = [
  _Taste('films', 'Films', 'Movies', Icons.movie_rounded, Color(0xFFFF5E62), Color(0xFFB4235A)),
  _Taste('series', 'Séries', 'Series', Icons.video_library_rounded, Color(0xFF8E6CFF), Color(0xFF4B2FD1)),
  _Taste('live', 'TV en direct', 'Live TV', Icons.live_tv_rounded, Color(0xFFFF9F43), Color(0xFFE5484D)),
  _Taste('sport', 'Sport', 'Sports', Icons.sports_soccer_rounded, Color(0xFF34D399), Color(0xFF0E8A6A)),
  _Taste('kids', 'Enfants', 'Kids', Icons.child_care_rounded, Color(0xFFFFD23F), Color(0xFFFF8A3D), darkText: true),
  _Taste('docs', 'Documentaires', 'Documentaries', Icons.public_rounded, Color(0xFF38BDF8), Color(0xFF1D5FD1)),
];

const _kEase = Cubic(0.2, 0.8, 0.2, 1);

class _OnboardingFlowState extends State<OnboardingFlow> {
  int step = 0, dir = 1;
  final order = <String>[];      // goûts dans l'ordre où ils sont cochés
  final ver = <String>{};
  static const _steps = 5;

  bool get reduce => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    if (widget.redo) {
      order.addAll(OnbPrefs.tastes);
      ver.addAll(OnbPrefs.ver);
      step = 1;
    } else {
      try {
        final j = jsonDecode(Store.str('onb_state')) as Map;
        step = (j['step'] as num?)?.toInt().clamp(0, _steps - 1) ?? 0;
        order.addAll([for (final x in (j['order'] as List? ?? const [])) '$x']);
        ver.addAll([for (final x in (j['ver'] as List? ?? const [])) '$x']);
      } catch (_) {}
    }
  }

  Future<void> _save() => widget.redo ? Future.value() : Store.setStr('onb_state', jsonEncode({'step': step, 'order': order, 'ver': ver.toList()}));

  void go(int to) {
    HapticFeedback.lightImpact();
    setState(() {
      dir = to >= step ? 1 : -1;
      step = to.clamp(0, _steps - 1);
    });
    _save();
  }

  Future<void> _finish({bool defaults = false}) async {
    HapticFeedback.mediumImpact();
    if (defaults) {
      await Store.setFlag('onb_done', true);
      await Store.setStr('onb_state', '');
    } else {
      await OnbPrefs.apply(tastes: order.toList(), ver: ver.toList());
    }
    widget.onDone();
  }

  void _toggleTaste(String id) {
    HapticFeedback.selectionClick();
    setState(() => order.contains(id) ? order.remove(id) : order.add(id));
    _save();
  }

  void _toggleVer(String id) {
    HapticFeedback.selectionClick();
    setState(() => ver.contains(id) ? ver.remove(id) : ver.add(id));
    _save();
  }

  Color? get _tint {
    final sel = [for (final t in _tastes) if (order.contains(t.id)) t.a];
    if (sel.isEmpty) return null;
    var r = 0, g = 0, b = 0;
    for (final c in sel) {
      r += c.red;
      g += c.green;
      b += c.blue;
    }
    return Color.fromARGB(255, r ~/ sel.length, g ~/ sel.length, b ~/ sel.length);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: L.changed,
      builder: (_, __, ___) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (step > (widget.redo ? 1 : 0)) {
            go(step - 1);
          } else if (widget.redo) {
            widget.onDone();
          }
        },
        child: Scaffold(
          backgroundColor: kBg,
          body: Stack(children: [
            Positioned.fill(child: _Aurora(tint: _tint, page: step)),
            Positioned.fill(child: _page(context)),
          ]),
        ),
      ),
    );
  }

  Widget _page(BuildContext context) {
    final tv = Device.tv;
    final pages = <Widget>[_welcome(tv), _lang(tv), _version(tv), _tastesPage(tv), _recap(tv)];
    final fwd = dir >= 0;
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduce ? 150 : 420),
      switchOutCurve: const Interval(0, 0.6),
      transitionBuilder: (child, anim) {
        final entering = child.key == ValueKey('p$step');
        if (reduce) return FadeTransition(opacity: anim, child: child);
        final from = Offset(entering ? (fwd ? 0.06 : -0.06) : (fwd ? -0.04 : 0.04), 0);
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(position: Tween(begin: from, end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: _kEase)), child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey('p$step'), child: pages[step]),
    );
  }

  // ---------------------------------------------------------------- gabarit commun
  Widget _shell({
    required String title,
    required String sub,
    required Widget content,
    required String primary,
    required VoidCallback onPrimary,
    bool enabled = true,
    bool skip = true,
    bool tv = false,
    int stagger = 1,
  }) {
    final head = _OnbHead(step: step, total: _steps, onBack: step > (widget.redo ? 1 : 0) ? () => go(step - 1) : null, onSkip: skip ? () => step < _steps - 1 ? go(step + 1) : _finish() : null);
    final titleW = [
      _In(i: 0, child: mat(_t('ÉTAPE ${step + 1} SUR $_steps', 'STEP ${step + 1} OF $_steps'), T(12, w: 700, color: kAccent, ls: 1.4))),
      const SizedBox(height: 10),
      _In(i: 1, child: Text(title, style: T(tv ? 40 : 32, w: 800, ls: -1, h: 1.05))),
      const SizedBox(height: 10),
      _In(i: 2, child: Text(sub, style: T(tv ? 20 : 16, w: 450, color: kMut, h: 1.35))),
    ];
    if (tv) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(48, 27, 48, 27),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 340,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              head,
              const Spacer(),
              ...titleW,
              const SizedBox(height: 28),
              _In(i: 5, child: _PrimaryButton(label: primary, onTap: onPrimary, enabled: enabled, autofocus: step == 0)),
              const SizedBox(height: 40),
            ]),
          ),
          const SizedBox(width: 40),
          Expanded(child: Center(child: SingleChildScrollView(child: content))),
        ]),
      );
    }
    final wide = isWide(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 560 : 640),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              head,
              const SizedBox(height: 22),
              ...titleW,
              const SizedBox(height: 22),
              Expanded(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), child: content)),
              const SizedBox(height: 12),
              _In(i: 6, child: _PrimaryButton(label: primary, onTap: onPrimary, enabled: enabled, wide: true)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget mat(String s, TextStyle st) => Text(s, style: st);

  // ---------------------------------------------------------------- 0. bienvenue
  Widget _welcome(bool tv) {
    final logo = tv ? 160.0 : 132.0;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Spacer(flex: 3),
              _In(
                i: 0,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 240,
                    height: 240,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0x4DE5484D), Color(0x00E5484D)])),
                  ),
                  SvgPicture.asset('assets/logo.svg', height: logo),
                ]),
              ),
              const SizedBox(height: 28),
              _In(i: 1, child: Text(_t('Bienvenue sur MinouFlix', 'Welcome to MinouFlix'), textAlign: TextAlign.center, style: T(tv ? 44 : 36, w: 800, ls: -1.1, h: 1.05))),
              const SizedBox(height: 12),
              _In(i: 2, child: Text(_t('Quelques choix et c\'est parti.', 'A few choices and you\'re set.'), textAlign: TextAlign.center, style: T(tv ? 22 : 17, w: 450, color: kMut))),
              const Spacer(flex: 4),
              _In(i: 4, child: _PrimaryButton(label: _t('Commencer', 'Start'), onTap: () => go(1), autofocus: true, wide: !tv)),
              const SizedBox(height: 14),
              _In(i: 5, child: _LinkButton(label: _t('Plus tard', 'Later'), onTap: () => _finish(defaults: true))),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 1. langue
  Widget _lang(bool tv) {
    Widget card(String code, String name, String hint) {
      final on = L.lang == code;
      return _Card(
        label: name,
        sub: hint,
        a: kAccent,
        b: const Color(0xFF3B5FD6),
        selected: on,
        watermark: code == 'fr' ? 'Aa' : 'Aa',
        height: tv ? 150 : 100,
        autofocus: tv && on,
        onTap: () async {
          HapticFeedback.selectionClick();
          await L.set(code);
          setState(() {});
          _save();
        },
      );
    }

    final cards = [card('fr', 'Français', 'Application et catégories'), card('en', 'English', 'App and categories')];
    return _shell(
      title: _t('Quelle langue préfères-tu ?', 'Which language do you prefer?'),
      sub: _t('Pour l\'appli, les catégories proposées et la recherche.', 'For the app, suggested categories and search.'),
      tv: tv,
      skip: true,
      primary: _t('Continuer', 'Continue'),
      onPrimary: () => go(2),
      content: tv
          ? Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 250, child: _In(i: 3, child: cards[0])), const SizedBox(width: 18), SizedBox(width: 250, child: _In(i: 4, child: cards[1]))])
          : Column(children: [_In(i: 3, child: cards[0]), const SizedBox(height: 14), _In(i: 4, child: cards[1])]),
    );
  }

  // ---------------------------------------------------------------- 2. version audio / sous-titres
  Widget _version(bool tv) {
    final en = L.en;
    final rows = [
      ('vf', Icons.chat_bubble_rounded, en ? 'Dubbed' : 'VF', en ? 'English audio' : 'Doublé en français'),
      ('vostfr', Icons.subtitles_rounded, en ? 'Original, subtitled' : 'VOSTFR', en ? 'Original audio with English subtitles' : 'Version originale, sous-titres français'),
      ('vo', Icons.public_rounded, en ? 'Original' : 'VO', en ? 'Original audio, no subtitles' : 'Version originale, sans sous-titres'),
    ];
    return _shell(
      title: _t('Quelle version préfères-tu ?', 'Which version do you prefer?'),
      sub: _t('Tu peux en choisir plusieurs. L\'appli prend la première disponible.', 'Pick as many as you like. The app uses the first one available.'),
      tv: tv,
      primary: _t('Continuer', 'Continue'),
      enabled: ver.isNotEmpty,
      onPrimary: () => go(3),
      content: SizedBox(
        width: tv ? 520 : double.infinity,
        child: Column(children: [
          for (final (i, r) in rows.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _In(i: 3 + i, child: _Row(icon: r.$2, title: r.$3, sub: r.$4, selected: ver.contains(r.$1), autofocus: tv && i == 0, onTap: () => _toggleVer(r.$1))),
            ),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- 3. goûts
  Widget _tastesPage(bool tv) {
    final cols = tv ? 3 : 2;
    final h = tv ? 120.0 : 128.0;
    return _shell(
      title: _t('Que regardez-vous ?', 'What do you watch?'),
      sub: _t('Choisis tout ce qui te plaît, tu pourras changer plus tard.', 'Pick whatever you like, you can change it later.'),
      tv: tv,
      primary: _t('Continuer', 'Continue'),
      enabled: order.isNotEmpty,
      onPrimary: () => go(4),
      content: LayoutBuilder(builder: (context, c) {
        final w = (tv ? 160.0 * cols + 24 : c.maxWidth);
        const gap = 12.0;
        final cw = (w - gap * (cols - 1)) / cols;
        return SizedBox(
          width: w,
          child: Wrap(spacing: gap, runSpacing: gap, children: [
            for (final (i, t) in _tastes.indexed)
              SizedBox(
                width: cw,
                child: _In(
                  i: 3 + i,
                  child: _Card(
                    label: t.label,
                    icon: t.icon,
                    a: t.a,
                    b: t.b,
                    darkText: t.darkText,
                    selected: order.contains(t.id),
                    height: h,
                    autofocus: tv && i == 0,
                    onTap: () => _toggleTaste(t.id),
                  ),
                ),
              ),
          ]),
        );
      }),
    );
  }

  // ---------------------------------------------------------------- 4. récap
  Widget _recap(bool tv) {
    final lang = L.lang == 'en' ? 'English' : 'Français';
    final verTxt = ver.isEmpty ? _t('Automatique', 'Automatic') : [for (final v in ['vf', 'vostfr', 'vo']) if (ver.contains(v)) v == 'vf' ? (L.en ? 'Dubbed' : 'VF') : v == 'vostfr' ? (L.en ? 'Subtitled' : 'VOSTFR') : 'VO'].join(' · ');
    Widget line(int i, String k, Widget v, int to) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _In(i: 3 + i, child: _SummaryLine(label: k, value: v, onTap: () => go(to), autofocus: false)),
        );
    final tastesW = order.isEmpty
        ? Text(_t('Tout', 'Everything'), style: T(15, w: 600))
        : Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end, children: [
            for (final id in order)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), gradient: LinearGradient(colors: [_tastes.firstWhere((t) => t.id == id).a, _tastes.firstWhere((t) => t.id == id).b])),
                child: Text(_tastes.firstWhere((t) => t.id == id).label, style: T(12, w: 700, color: _tastes.firstWhere((t) => t.id == id).darkText ? const Color(0xFF1A1200) : Colors.white)),
              ),
          ]);
    return _shell(
      title: _t('Tout est prêt', 'You\'re all set'),
      sub: widget.redo ? _t('Tes onglets et ton accueil seront remplacés. Tes catégories ne changent pas.', 'Your tabs and home will be replaced. Your categories stay as they are.') : _t('Ton MinouFlix est préparé. Tu pourras tout modifier dans Réglages.', 'Your MinouFlix is ready. You can change everything in Settings.'),
      tv: tv,
      skip: false,
      primary: widget.redo ? _t('Appliquer', 'Apply') : _t('Découvrir MinouFlix', 'Discover MinouFlix'),
      onPrimary: _finish,
      content: SizedBox(
        width: tv ? 520 : double.infinity,
        child: Column(children: [
          _In(i: 3, child: Padding(padding: const EdgeInsets.only(bottom: 18), child: _CheckMark(size: tv ? 80 : 96, confetti: !Perf.lite && !reduce))),
          line(1, _t('Langue', 'Language'), Text(lang, style: T(15, w: 600)), 1),
          line(2, _t('Version', 'Version'), Text(verTxt, style: T(15, w: 600)), 2),
          line(3, _t('Goûts', 'Tastes'), tastesW, 3),
        ]),
      ),
    );
  }
}

// ======================================================================= éléments

/// en-tête : retour, points de progression, passer
class _OnbHead extends StatelessWidget {
  final int step, total;
  final VoidCallback? onBack, onSkip;
  const _OnbHead({required this.step, required this.total, this.onBack, this.onSkip});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: Row(children: [
          SizedBox(width: 56, child: onBack == null ? null : Align(alignment: Alignment.centerLeft, child: RoundButton(size: 40, label: _t('Retour', 'Back'), onTap: onBack!, child: const Icon(Icons.chevron_left_rounded, size: 24, color: kText)))),
          Expanded(
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < total; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: _kEase,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == step ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: i == step ? kAccent : (i < step ? const Color(0x8F5B8CFF) : const Color(0x33FFFFFF))),
                ),
            ]),
          ),
          SizedBox(width: 56, child: onSkip == null ? null : Align(alignment: Alignment.centerRight, child: _LinkButton(label: _t('Passer', 'Skip'), onTap: onSkip!))),
        ]),
      );
}

class _LinkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => FocusCard(
        radius: 14,
        focusScale: 1.04,
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Text(label, style: T(Device.tv ? 17 : 15, w: 600, color: kMut))),
      );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled, wide, autofocus;
  const _PrimaryButton({required this.label, required this.onTap, this.enabled = true, this.wide = false, this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    final h = Device.tv ? 56.0 : 54.0;
    return FocusCard(
      radius: h / 2,
      autofocus: autofocus && Device.tv,
      focusScale: 1.04,
      onTap: () {
        if (enabled) onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: h,
        width: wide ? double.infinity : null,
        constraints: const BoxConstraints(minWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 28),
        alignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(h / 2), color: enabled ? Colors.white : const Color(0x1FFFFFFF)),
        child: Text(label, style: T(17, w: 650, color: enabled ? kBg : kMut)),
      ),
    );
  }
}

/// entrée échelonnée : fondu + montée de 18 dp
class _In extends StatelessWidget {
  final int i;
  final Widget child;
  const _In({required this.i, required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final d = 420 + 45 * math.min(i, 8);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: d),
      curve: Interval(45 * math.min(i, 8) / d, 1, curve: _kEase),
      builder: (_, v, c) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c)),
      child: child,
    );
  }
}

/// carte de choix : verre teinté au repos, dégradé plein quand elle est cochée, coche à ressort
class _Card extends StatefulWidget {
  final String label;
  final String? sub, watermark;
  final IconData? icon;
  final Color a, b;
  final bool selected, darkText, autofocus;
  final double height;
  final VoidCallback onTap;
  const _Card({required this.label, required this.a, required this.b, required this.selected, required this.height, required this.onTap, this.sub, this.watermark, this.icon, this.darkText = false, this.autofocus = false});
  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  double _s = 1;

  void _tap() {
    setState(() => _s = 0.94);
    Future.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _s = 1);
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.selected;
    final fg = on && widget.darkText ? const Color(0xFF1A1200) : Colors.white;
    return AnimatedScale(
      scale: _s,
      duration: Duration(milliseconds: _s < 1 ? 90 : 320),
      curve: _s < 1 ? Curves.easeOut : Curves.easeOutBack,
      child: FocusCard(
        radius: 22,
        focusScale: Device.tv ? 1.08 : 1.03,
        autofocus: widget.autofocus && Device.tv,
        onTap: _tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: kBg2,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: on ? [widget.a, widget.b] : [widget.a.withOpacity(0.10), widget.b.withOpacity(0.10)]),
            border: Border.all(color: on ? const Color(0x59FFFFFF) : kEdge, width: on ? 1.5 : 1),
            boxShadow: on && !Perf.lite ? [BoxShadow(color: widget.a.withOpacity(0.45), blurRadius: 28, spreadRadius: -6)] : null,
          ),
          child: Stack(children: [
            if (widget.watermark != null) Positioned(right: 14, bottom: -6, child: Text(widget.watermark!, style: T(64, w: 800, color: Colors.white.withOpacity(0.13)))),
            if (widget.icon != null) Positioned(left: 16, top: 14, child: Icon(widget.icon, size: 40, color: on ? fg : Colors.white.withOpacity(0.92))),
            Positioned(
              left: 16,
              bottom: 14,
              right: 44,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(widget.label, maxLines: 2, style: T(17, w: 700, ls: -0.2, color: fg)),
                if (widget.sub != null) Text(widget.sub!, maxLines: 1, style: T(13, w: 450, color: on ? fg.withOpacity(0.85) : kMut)),
              ]),
            ),
            Positioned(right: 12, top: 12, child: _Tick(on: on, dark: widget.darkText)),
          ]),
        ),
      ),
    );
  }
}

class _Tick extends StatelessWidget {
  final bool on, dark;
  const _Tick({required this.on, this.dark = false});
  @override
  Widget build(BuildContext context) => AnimatedScale(
        scale: on ? 1 : 0.4,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: Icon(Icons.check_rounded, size: 17, color: dark ? const Color(0xFF8A4B00) : const Color(0xFF16203A)),
          ),
        ),
      );
}

/// ligne à cocher (version audio) : icône, titre, explication, coche
class _Row extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final bool selected, autofocus;
  final VoidCallback onTap;
  const _Row({required this.icon, required this.title, required this.sub, required this.selected, required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) => FocusCard(
        radius: 20,
        focusScale: Device.tv ? 1.04 : 1.02,
        autofocus: autofocus,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: kBg2,
            gradient: LinearGradient(colors: selected ? const [Color(0xFF4F7DF0), Color(0xFF3556C4)] : const [Color(0x1A5B8CFF), Color(0x0F5B8CFF)]),
            border: Border.all(color: selected ? const Color(0x59FFFFFF) : kEdge, width: selected ? 1.5 : 1),
          ),
          child: Row(children: [
            Icon(icon, size: 34, color: Colors.white.withOpacity(selected ? 1 : 0.85)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T(17, w: 700, ls: -0.2)),
                const SizedBox(height: 2),
                Text(sub, maxLines: 2, style: T(13.5, w: 450, color: selected ? const Color(0xE6FFFFFF) : kMut)),
              ]),
            ),
            _Tick(on: selected),
          ]),
        ),
      );
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final Widget value;
  final VoidCallback onTap;
  final bool autofocus;
  const _SummaryLine({required this.label, required this.value, required this.onTap, this.autofocus = false});
  @override
  Widget build(BuildContext context) => FocusCard(
        radius: 18,
        focusScale: Device.tv ? 1.03 : 1.0,
        autofocus: autofocus,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: kGlass, border: Border.all(color: kEdge)),
          child: Row(children: [
            Text(label, style: T(15, w: 500, color: kMut)),
            const SizedBox(width: 14),
            Expanded(child: Align(alignment: Alignment.centerRight, child: value)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: kMut),
          ]),
        ),
      );
}

// ======================================================================= fond « aurore »

/// trois halos flous (bleu, rouge, violet teinté par les goûts) qui dérivent lentement ; figé sur la télé et en « réduire les animations »
class _Aurora extends StatefulWidget {
  final Color? tint;
  final int page;
  const _Aurora({this.tint, required this.page});
  @override
  State<_Aurora> createState() => _AuroraState();
}

class _AuroraState extends State<_Aurora> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = Perf.lite || MediaQuery.of(context).disableAnimations;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: widget.tint ?? const Color(0xFF7A5CFF)),
          duration: const Duration(milliseconds: 800),
          builder: (_, col, __) => AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(painter: _AuroraPainter(_c.value, col ?? const Color(0xFF7A5CFF), widget.page)),
          ),
        ),
      );
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final Color third;
  final int page;
  _AuroraPainter(this.t, this.third, this.page);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = kBg);
    final a = 2 * math.pi * t;
    final shift = page * 0.03 * w;
    void blob(Offset c, Color col, double op) {
      final r = w * 0.9;
      canvas.drawCircle(c, r, Paint()..shader = ui.Gradient.radial(c, r, [col.withOpacity(op), col.withOpacity(0)]));
    }

    blob(Offset(w * 0.15 - shift + 0.08 * w * math.sin(a), h * 0.10 + 0.08 * h * math.cos(a)), const Color(0xFF5B8CFF), 0.22);
    blob(Offset(w * 0.90 - shift + 0.08 * w * math.sin(a + 2.1), h * 0.55 + 0.08 * h * math.cos(a + 2.1)), const Color(0xFFE5484D), 0.14);
    blob(Offset(w * 0.30 - shift + 0.08 * w * math.sin(a + 4.2), h * 0.95 + 0.08 * h * math.cos(a + 4.2)), third, 0.18);
    // voile du bas : le texte et le bouton restent lisibles
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.62, w, h * 0.38),
      Paint()..shader = ui.Gradient.linear(Offset(0, h * 0.62), Offset(0, h), [kBg.withOpacity(0), kBg.withOpacity(0.85)]),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter o) => o.t != t || o.third != third || o.page != page;
}

// ======================================================================= coche du récap

/// cercle puis coche tracés au trait, onde, confettis aux couleurs des goûts
class _CheckMark extends StatefulWidget {
  final double size;
  final bool confetti;
  const _CheckMark({required this.size, required this.confetti});
  @override
  State<_CheckMark> createState() => _CheckMarkState();
}

class _CheckMarkState extends State<_CheckMark> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.size + 40,
        child: Center(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(size: Size(widget.size * 2.6, widget.size + 40), painter: _CheckPainter(_c.value, widget.size, widget.confetti)),
            ),
          ),
        ),
      );
}

class _CheckPainter extends CustomPainter {
  final double v, d;
  final bool confetti;
  _CheckPainter(this.v, this.d, this.confetti);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = d / 2;
    final circ = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = kAccent;
    final t1 = (v / 0.43).clamp(0.0, 1.0), t2 = ((v - 0.35) / 0.3).clamp(0.0, 1.0);
    for (final m in circ.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * Curves.easeOutCubic.transform(t1)), p);
    }
    final ck = Path()
      ..moveTo(c.dx - r * 0.42, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.1, c.dy + r * 0.34)
      ..lineTo(c.dx + r * 0.46, c.dy - r * 0.3);
    for (final m in ck.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * Curves.easeOutCubic.transform(t2)), p..color = Colors.white);
    }
    // onde
    final o = ((v - 0.55) / 0.3).clamp(0.0, 1.0);
    if (o > 0 && o < 1) {
      canvas.drawCircle(c, r * (1 + 0.6 * o), Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = kAccent.withOpacity(0.5 * (1 - o)));
    }
    // confettis
    if (confetti && v > 0.5) {
      final rnd = math.Random(7);
      final k = ((v - 0.5) / 0.5).clamp(0.0, 1.0);
      for (var i = 0; i < 40; i++) {
        final ang = rnd.nextDouble() * 2 * math.pi, sp = 0.5 + rnd.nextDouble();
        final pos = c + Offset(math.cos(ang) * r * 1.6 * sp * k, math.sin(ang) * r * 1.6 * sp * k + 40 * k * k);
        final col = _tastes[i % _tastes.length].a;
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(ang + k * 4);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-3, -2, 6, 4), const Radius.circular(1)), Paint()..color = col.withOpacity(1 - k));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_CheckPainter o) => o.v != v;
}
