import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'l10n.dart';
import 'onb_prefs.dart';
import 'perf.dart';
import 'perso.dart' show HomeSettings;
import 'sport.dart' show Side, League, LgIcon, fetchSport, leagues, lgHasLogo, lgOf, sportName;
import 'store.dart';
import 'tmdb.dart' show Tmdb;
import 'ui.dart';

/// Parcours de configuration d'un nouveau compte (après la saisie des identifiants IPTV) :
/// langue, version audio, goûts, récap. Rien n'est écrit dans les réglages avant le récap.
/// `redo` : relancé depuis Réglages (préremplit, ne touche pas aux catégories).
class OnboardingFlow extends StatefulWidget {
  final VoidCallback onDone;
  final bool redo;
  final bool sportOnly;      // Réglages › Sport : seulement sports, compétitions, équipes
  const OnboardingFlow({super.key, required this.onDone, this.redo = false, this.sportOnly = false});
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

String _t(String fr, String en) {
  if (L.lang == 'fr') return fr;
  if (L.lang == 'en') return en;
  if (fr.startsWith('ÉTAPE ')) {
    final w = {'es': 'PASO', 'de': 'SCHRITT', 'pt': 'ETAPA'}[L.lang]!, of = {'es': 'DE', 'de': 'VON', 'pt': 'DE'}[L.lang]!;
    final m = RegExp(r'(\d+) SUR (\d+)').firstMatch(fr)!;
    return '$w ${m[1]} $of ${m[2]}';
  }
  return _tr[fr]?[L.lang] ?? en;
}

const _tr = <String, Map<String, String>>{
  'Continuer': {'es': 'Continuar', 'de': 'Weiter', 'pt': 'Continuar'},
  'Passer': {'es': 'Omitir', 'de': 'Überspringen', 'pt': 'Saltar'},
  'Retour': {'es': 'Atrás', 'de': 'Zurück', 'pt': 'Voltar'},
  'Commencer': {'es': 'Empezar', 'de': 'Los geht\'s', 'pt': 'Começar'},
  'Plus tard': {'es': 'Más tarde', 'de': 'Später', 'pt': 'Mais tarde'},
  'Bienvenue sur MinouFlix': {'es': 'Bienvenido a MinouFlix', 'de': 'Willkommen bei MinouFlix', 'pt': 'Bem-vindo ao MinouFlix'},
  'Quelques choix et c\'est parti.': {'es': 'Unas elecciones y listo.', 'de': 'Ein paar Fragen und es geht los.', 'pt': 'Algumas escolhas e já está.'},
  'Quelle langue préfères-tu ?': {'es': '¿Qué idioma prefieres?', 'de': 'Welche Sprache bevorzugst du?', 'pt': 'Que idioma preferes?'},
  'Pour l\'appli, les catégories proposées et la recherche.': {'es': 'Para la app, las categorías sugeridas y la búsqueda.', 'de': 'Für die App, die vorgeschlagenen Kategorien und die Suche.', 'pt': 'Para a app, as categorias sugeridas e a pesquisa.'},
  'Quelle version préfères-tu ?': {'es': '¿Qué versión prefieres?', 'de': 'Welche Fassung bevorzugst du?', 'pt': 'Que versão preferes?'},
  'Coche celles qui te conviennent. Si un titre n\'existe pas dans la première, l\'appli prend la suivante.': {'es': 'Marca las que te gusten. Si un título no existe en la primera, la app usa la siguiente.', 'de': 'Wähle aus, was dir passt. Gibt es einen Titel nicht in der ersten Fassung, nimmt die App die nächste.', 'pt': 'Marca as que preferes. Se um título não existir na primeira, a app usa a seguinte.'},
  'Que regardez-vous ?': {'es': '¿Qué sueles ver?', 'de': 'Was schaust du?', 'pt': 'O que costumas ver?'},
  'Choisis tout ce qui te plaît, tu pourras changer plus tard.': {'es': 'Elige lo que quieras, podrás cambiarlo después.', 'de': 'Wähle alles, was dir gefällt. Du kannst es später ändern.', 'pt': 'Escolhe o que quiseres, podes mudar depois.'},
  'Films': {'es': 'Películas', 'de': 'Filme', 'pt': 'Filmes'},
  'Séries': {'es': 'Series', 'de': 'Serien', 'pt': 'Séries'},
  'TV en direct': {'es': 'TV en vivo', 'de': 'Live-TV', 'pt': 'TV ao vivo'},
  'Sport': {'es': 'Deportes', 'de': 'Sport', 'pt': 'Desporto'},
  'Enfants': {'es': 'Infantil', 'de': 'Kinder', 'pt': 'Infantil'},
  'Documentaires': {'es': 'Documentales', 'de': 'Dokus', 'pt': 'Documentários'},
  'Ton sport': {'es': 'Tu deporte', 'de': 'Dein Sport', 'pt': 'O teu desporto'},
  'Choisis tes compétitions et tes équipes : leurs matchs passent en premier.': {'es': 'Elige tus competiciones y equipos: sus partidos van primero.', 'de': 'Wähle deine Wettbewerbe und Teams: ihre Spiele kommen zuerst.', 'pt': 'Escolhe as tuas competições e equipas: os jogos delas vêm primeiro.'},
  'Mes compétitions': {'es': 'Mis competiciones', 'de': 'Meine Wettbewerbe', 'pt': 'As minhas competições'},
  'Mes équipes': {'es': 'Mis equipos', 'de': 'Meine Teams', 'pt': 'As minhas equipas'},
  'Tout est prêt': {'es': 'Todo listo', 'de': 'Alles bereit', 'pt': 'Tudo pronto'},
  'Ton MinouFlix est préparé. Tu pourras tout modifier dans Réglages.': {'es': 'Tu MinouFlix está listo. Podrás cambiarlo todo en Ajustes.', 'de': 'Dein MinouFlix ist vorbereitet. Alles lässt sich später in den Einstellungen ändern.', 'pt': 'O teu MinouFlix está pronto. Podes mudar tudo nas Definições.'},
  'Choisir mes catégories': {'es': 'Elegir mis categorías', 'de': 'Kategorien wählen', 'pt': 'Escolher as categorias'},
  'Quels sports ?': {'es': '¿Qué deportes?', 'de': 'Welche Sportarten?', 'pt': 'Que desportos?'},
  'Choisis les sports que tu suis. À l\'étape suivante, tu pourras choisir les compétitions.': {'es': 'Elige los deportes que sigues. En el siguiente paso elegirás las competiciones.', 'de': 'Wähle die Sportarten, die du verfolgst. Im nächsten Schritt wählst du die Wettbewerbe.', 'pt': 'Escolhe os desportos que segues. No passo seguinte escolhes as competições.'},
  'Tes compétitions': {'es': 'Tus competiciones', 'de': 'Deine Wettbewerbe', 'pt': 'As tuas competições'},
  'Tes équipes': {'es': 'Tus equipos', 'de': 'Deine Teams', 'pt': 'As tuas equipas'},
  'Personnaliser mon accueil': {'es': 'Personalizar mi inicio', 'de': 'Startseite anpassen', 'pt': 'Personalizar o meu início'},
  'Langue': {'es': 'Idioma', 'de': 'Sprache', 'pt': 'Idioma'},
  'Version': {'es': 'Versión', 'de': 'Fassung', 'pt': 'Versão'},
  'Goûts': {'es': 'Gustos', 'de': 'Vorlieben', 'pt': 'Gostos'},
  'Automatique': {'es': 'Automático', 'de': 'Automatisch', 'pt': 'Automático'},
  'Tout': {'es': 'Todo', 'de': 'Alles', 'pt': 'Tudo'},
};

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

const _langs = [('fr', 'Français'), ('en', 'English'), ('es', 'Español'), ('de', 'Deutsch'), ('pt', 'Português')];

/// versions proposées selon la langue : doublé / original sous-titré / original (nom courant dans chaque pays + explication)
const _verTxt = <String, List<String>>{
  'fr': ['VF', 'Doublé en français', 'VOSTFR', 'Version originale, sous-titres français', 'VO', 'Version originale, sans sous-titres'],
  'en': ['Dubbed', 'English audio', 'Original, subtitled', 'Original audio, English subtitles', 'Original', 'Original audio, no subtitles'],
  'es': ['Doblada', 'Audio en español', 'VOSE', 'Versión original subtitulada en español', 'VO', 'Versión original, sin subtítulos'],
  'de': ['Synchronisiert', 'Deutsche Tonspur', 'OmU', 'Originalton mit deutschen Untertiteln', 'OV', 'Originalton, ohne Untertitel'],
  'pt': ['Dobrado', 'Áudio em português', 'Legendado', 'Áudio original com legendas em português', 'Original', 'Áudio original, sem legendas'],
};

class _OnboardingFlowState extends State<OnboardingFlow> {
  int step = 0, dir = 1;
  final order = <String>[];      // goûts dans l'ordre où ils sont cochés
  final ver = <String>{};
  List<int> get _seq => widget.sportOnly ? const [4, 5, 6] : [0, 1, 2, 3, if (order.contains('sport')) ...[4, 5, 6], 7];
  final sports = <String>{};      // sports choisis (étape 4)
  int get _steps => _seq.length;
  int _next(int s) => _seq[(_seq.indexOf(s) + 1).clamp(0, _seq.length - 1)];
  int _prev(int s) => _seq[(_seq.indexOf(s) - 1).clamp(0, _seq.length - 1)];
  bool _busy = false;
  int get _first => widget.sportOnly ? 4 : (widget.redo ? 1 : 0);
  bool get _editing => widget.redo || widget.sportOnly;

  bool get reduce => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    if (widget.sportOnly) {
      sports.addAll([for (final k in Store.sportKeys) sportName(lgOf(k))]);
      step = 4;
    } else if (widget.redo) {
      order.addAll(OnbPrefs.tastes);
      ver.addAll(OnbPrefs.ver);
      step = 1;
    } else {
      try {
        final j = jsonDecode(Store.str('onb_state')) as Map;
        step = (j['step'] as num?)?.toInt().clamp(0, 7) ?? 0;
        sports.addAll([for (final x in (j['sports'] as List? ?? const [])) '$x']);
        order.addAll([for (final x in (j['order'] as List? ?? const [])) '$x']);
        ver.addAll([for (final x in (j['ver'] as List? ?? const [])) '$x']);
      } catch (_) {}
    }
  }

  Future<void> _save() => _editing ? Future.value() : Store.setStr('onb_state', jsonEncode({'step': step, 'order': order, 'ver': ver.toList(), 'sports': sports.toList()}));

  void go(int to) {
    HapticFeedback.lightImpact();
    setState(() {
      dir = to >= step ? 1 : -1;
      step = to.clamp(0, 7);
      if (step == 6) _loadTeams();
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

  /// applique les choix puis ouvre l'écran « Écran d'accueil » existant pour ajuster l'ordre ; on termine au retour
  Future<void> _customHome() async {
    HapticFeedback.lightImpact();
    await OnbPrefs.apply(tastes: order.toList(), ver: ver.toList());
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeSettings()));
    if (mounted) widget.onDone();
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
          if (step > _first) {
            go(_prev(step));
          } else if (_editing) {
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
    final pages = <Widget>[_welcome(tv), _lang(tv), _version(tv), _tastesPage(tv), _sportsPage(tv), _leaguesPage(tv), _teams(tv), _recap(tv)];
    final fwd = dir >= 0;
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduce || Perf.lite ? 160 : 420),
      switchOutCurve: const Interval(0, 0.6),
      transitionBuilder: (child, anim) {
        final entering = child.key == ValueKey('p$step');
        if (reduce || Perf.lite) return FadeTransition(opacity: anim, child: child);
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
    Widget? extra,
  }) {
    final pos = _seq.indexOf(step);
    final head = _OnbHead(step: pos, total: _steps, onBack: step > _first ? () => go(_prev(step)) : null, onSkip: skip ? () => step != _seq.last ? go(_next(step)) : widget.sportOnly ? widget.onDone() : _finish() : null);
    final titleW = [
      _In(i: 0, child: mat(_t('ÉTAPE ${pos + 1} SUR $_steps', 'STEP ${pos + 1} OF $_steps'), T(12, w: 700, color: kAccent, ls: 0.12))),
      const SizedBox(height: 10),
      _In(i: 1, child: Text(title, style: T(tv ? 40 : 32, w: 800, ls: -0.03, h: 1.05))),
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
              if (extra != null) Padding(padding: const EdgeInsets.only(top: 8), child: extra),
              const SizedBox(height: 24),
            ]),
          ),
          const SizedBox(width: 40),
          Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: content))),
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
              if (extra != null) Center(child: extra),
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
              _In(i: 1, child: Text(_t('Bienvenue sur MinouFlix', 'Welcome to MinouFlix'), textAlign: TextAlign.center, style: T(tv ? 44 : 36, w: 800, ls: -0.03, h: 1.05))),
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
    const cols = 3;
    return _shell(
      title: _t('Quelle langue préfères-tu ?', 'Which language do you prefer?'),
      sub: _t('Pour l\'appli, les catégories proposées et la recherche.', 'For the app, suggested categories and search.'),
      tv: tv,
      skip: false,
      primary: _t('Continuer', 'Continue'),
      onPrimary: () => go(2),
      content: LayoutBuilder(builder: (context, c) {
        final w = tv ? 148.0 * cols + 24 : c.maxWidth;
        const gap = 12.0;
        final cw = (w - gap * (cols - 1)) / cols;
        return SizedBox(
          width: w,
          child: Wrap(spacing: gap, runSpacing: gap, children: [
            for (final (i, l) in _langs.indexed)
              SizedBox(
                width: cw,
                child: _In(
                  i: 3 + i,
                  child: _Card(
                    label: l.$2,
                    flag: l.$1,
                    a: kAccent,
                    b: const Color(0xFF3B5FD6),
                    selected: L.lang == l.$1,
                    height: tv ? 112 : 104,
                    autofocus: tv && L.lang == l.$1,
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      await L.set(l.$1);
                      Tmdb.reset();
                      setState(() {});
                      _save();
                    },
                  ),
                ),
              ),
          ]),
        );
      }),
    );
  }

  // ---------------------------------------------------------------- 2. version audio / sous-titres
  Widget _version(bool tv) {
    final x = _verTxt[L.lang] ?? _verTxt['en']!;
    final rows = [
      ('vf', Icons.chat_bubble_rounded, x[0], x[1]),
      ('vostfr', Icons.subtitles_rounded, x[2], x[3]),
      ('vo', Icons.public_rounded, x[4], x[5]),
    ];
    return _shell(
      title: _t('Quelle version préfères-tu ?', 'Which version do you prefer?'),
      sub: _t('Coche celles qui te conviennent. Si un titre n\'existe pas dans la première, l\'appli prend la suivante.', 'Tick the ones you like. If a title isn\'t available in the first, the app uses the next one.'),
      tv: tv,
      skip: false,
      primary: _t('Continuer', 'Continue'),
      enabled: ver.isNotEmpty,
      onPrimary: () => go(3),
      content: SizedBox(
        width: tv ? 470 : double.infinity,
        child: Column(children: [
          for (final (i, r) in rows.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _In(i: 3 + i, child: _Row(icon: r.$2, title: r.$3, sub: r.$4, selected: ver.contains(r.$1), autofocus: tv && i == (rows.indexWhere((x) => ver.contains(x.$1)) < 0 ? 0 : rows.indexWhere((x) => ver.contains(x.$1))), onTap: () => _toggleVer(r.$1))),
            ),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- 3. goûts
  Widget _tastesPage(bool tv) {
    const cols = 3;
    final h = tv ? 120.0 : 128.0;
    return _shell(
      title: _t('Que regardez-vous ?', 'What do you watch?'),
      sub: _t('Choisis tout ce qui te plaît, tu pourras changer plus tard.', 'Pick whatever you like, you can change it later.'),
      tv: tv,
      primary: _t('Continuer', 'Continue'),
      enabled: order.isNotEmpty,
      onPrimary: () {
        if (order.contains('sport') && sports.isEmpty) sports.addAll({for (final k in Store.sportKeys) sportName(lgOf(k))});
        go(order.contains('sport') ? 4 : 7);
      },
      content: LayoutBuilder(builder: (context, c) {
        final w = (tv ? 148.0 * cols + 24 : c.maxWidth);
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
                    autofocus: tv && i == (_tastes.indexWhere((x) => order.contains(x.id)) < 0 ? 0 : _tastes.indexWhere((x) => order.contains(x.id))),
                    onTap: () => _toggleTaste(t.id),
                  ),
                ),
              ),
          ]),
        );
      }),
    );
  }

  // ---------------------------------------------------------------- 4. sports (large) puis 5. compétitions de ces sports
  static const _sportIcons = {
    'Football': Icons.sports_soccer_rounded,
    'Rugby': Icons.sports_rugby_rounded,
    'Formule 1': Icons.sports_motorsports_rounded,
    'Basketball': Icons.sports_basketball_rounded,
    'Football américain': Icons.sports_football_rounded,
    'Hockey sur glace': Icons.sports_hockey_rounded,
  };

  /// compétitions des sports choisis ; les sports décochés en retirent leurs compétitions, un sport sans compétition reçoit ses compétitions habituelles
  Future<void> _applySports() async {
    final keep = {for (final k in Store.sportKeys) if (sports.contains(sportName(lgOf(k)))) k};
    for (final sp in sports) {
      final of = [for (final l in leagues) if (sportName(l) == sp) l];
      if (!of.any((l) => keep.contains(l.k))) keep.addAll([for (final l in of) if (l.def) l.k]);
      if (!of.any((l) => keep.contains(l.k)) && of.isNotEmpty) keep.add(of.first.k);
    }
    await Store.saveSportKeys(keep.toList());
    _teamsKey = '';
  }

  Widget _sportsPage(bool tv) {
    final names = <String>[];
    for (final l in leagues) {
      final n = sportName(l);
      if (!names.contains(n)) names.add(n);
    }
    const cols = 3;
    final firstSel = names.indexWhere(sports.contains);
    return _shell(
      title: _t('Quels sports ?', 'Which sports?'),
      sub: _t('Choisis les sports que tu suis. À l\'étape suivante, tu pourras choisir les compétitions.', 'Pick the sports you follow. Next, you can choose the competitions.'),
      tv: tv,
      primary: _t('Continuer', 'Continue'),
      enabled: sports.isNotEmpty,
      onPrimary: () async {
        await _applySports();
        go(5);
      },
      content: LayoutBuilder(builder: (context, c) {
        final w = tv ? 148.0 * cols + 24 : c.maxWidth;
        const gap = 12.0;
        final cw = (w - gap * (cols - 1)) / cols;
        return SizedBox(
          width: w,
          child: Wrap(spacing: gap, runSpacing: gap, children: [
            for (final (i, n) in names.indexed)
              SizedBox(
                width: cw,
                child: _In(
                  i: 3 + i,
                  child: _Card(
                    label: n,
                    icon: _sportIcons[n] ?? Icons.emoji_events_rounded,
                    a: const Color(0xFF34D399),
                    b: const Color(0xFF0E8A6A),
                    selected: sports.contains(n),
                    height: tv ? 112 : 112,
                    autofocus: tv && i == (firstSel < 0 ? 0 : firstSel),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => sports.contains(n) ? sports.remove(n) : sports.add(n));
                      _save();
                    },
                  ),
                ),
              ),
          ]),
        );
      }),
    );
  }

  Widget _leaguesPage(bool tv) {
    final sel = {...Store.sportKeys};
    final bySport = <String, List<League>>{};
    for (final l in leagues) {
      final sp = sportName(l);
      if (sports.isEmpty || sports.contains(sp)) (bySport[sp] ??= []).add(l);
    }
    final firstSel = [for (final l in bySport.values.expand((x) => x)) l].indexWhere((l) => sel.contains(l.k));
    const cols = 3;
    return _shell(
      title: _t('Tes compétitions', 'Your competitions'),
      sub: _t('Coche celles que tu suis : leurs matchs passent en premier.', 'Tick the ones you follow: their matches come first.'),
      tv: tv,
      primary: _t('Continuer', 'Continue'),
      onPrimary: () => go(6),
      content: LayoutBuilder(builder: (context, c) {
        final w = tv ? 148.0 * cols + 24 : c.maxWidth - 16;
        const gap = 10.0;
        final cw = (w - gap * (cols - 1)) / cols;
        var n = -1;
        return SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final e in bySport.entries) ...[
                Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text(e.key.toUpperCase(), style: T(12, w: 700, color: kMut, ls: 0.08))),
                Wrap(spacing: gap, runSpacing: gap, children: [
                  for (final l in e.value)
                    Builder(builder: (_) {
                      n++;
                      final idx = n;
                      return SizedBox(
                        width: cw,
                        child: _PickTile(
                          leading: lgHasLogo(l.k) ? LgIcon(l.k, size: 28) : const Icon(Icons.emoji_events_rounded, size: 24, color: Colors.white70),
                          label: l.n,
                          on: sel.contains(l.k),
                          a: l.color,
                          b: l.color.withOpacity(0.6),
                          autofocus: tv && idx == (firstSel < 0 ? 0 : firstSel),
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            final k = {...Store.sportKeys};
                            k.contains(l.k) ? k.remove(l.k) : k.add(l.k);
                            await Store.saveSportKeys(k.toList());
                            _teamsKey = '';
                            if (mounted) setState(() {});
                          },
                        ),
                      );
                    }),
                ]),
              ],
            ]),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------- 5. équipes (cartes à cocher)
  String _teamsKey = '';
  Map<String, List<Side>> _teamsBy = {};
  bool _loadingTeams = false;

  Future<void> _loadTeams() async {
    final key = (Store.sportKeys.toList()..sort()).join(',');
    if (_loadingTeams || key == _teamsKey) return;
    _loadingTeams = true;
    if (mounted) setState(() {});
    try {
      final ev = await fetchSport(Store.sportKeys);
      final by = <String, Map<String, Side>>{};
      for (final e in ev) {
        if (e.f1) continue;
        for (final sd in [e.h, e.a]) {
          if (sd.name.isEmpty || sd.name == '?') continue;
          (by[e.lg] ??= {})[sd.name] = sd;
        }
      }
      _teamsBy = {for (final e in by.entries) e.key: (e.value.values.toList()..sort((x, y) => x.name.compareTo(y.name)))};
      _teamsKey = key;
    } catch (_) {
      _teamsBy = {};
    }
    _loadingTeams = false;
    if (mounted) setState(() {});
  }

  Widget _teams(bool tv) {
    final mine = {...Store.sportTeams};
    const cols = 3;
    Widget body() {
      if (_loadingTeams) {
        return Padding(padding: const EdgeInsets.all(40), child: Column(children: [const Spinner(), const SizedBox(height: 14), Text(_t('Chargement des équipes…', 'Loading teams…'), style: T(14, color: kMut))]));
      }
      if (_teamsBy.isEmpty) {
        return Padding(padding: const EdgeInsets.all(24), child: Text(_t('Aucune équipe à proposer pour l\'instant : tu pourras les choisir plus tard dans Sport.', 'No teams to suggest right now: you can pick them later in Sport.'), style: T(15, color: kMut, h: 1.4)));
      }
      return LayoutBuilder(builder: (context, c) {
        final w = tv ? 148.0 * cols + 24 : c.maxWidth;
        const gap = 10.0;
        final cw = (w - gap * (cols - 1)) / cols;
        var first = true;
        return SizedBox(
          width: w,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final e in _teamsBy.entries) ...[
              Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 8), child: Text(lgOf(e.key).n.toUpperCase(), style: T(12, w: 700, color: kMut, ls: 0.08))),
              Wrap(spacing: gap, runSpacing: gap, children: [
                for (final sd in e.value)
                  Builder(builder: (_) {
                    final af = tv && first;
                    first = false;
                    return SizedBox(
                      width: cw,
                      child: _PickTile(
                        leading: sd.logo.isEmpty ? const Icon(Icons.shield_rounded, size: 28, color: kMut) : SizedBox(width: 30, height: 30, child: netImage(sd.logo, '', fit: BoxFit.contain)),
                        label: sd.name,
                        on: mine.contains(sd.name),
                        a: const Color(0xFF34D399),
                        b: const Color(0xFF0E8A6A),
                        autofocus: af,
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          final m = {...Store.sportTeams};
                          m.contains(sd.name) ? m.remove(sd.name) : m.add(sd.name);
                          await Store.setSportTeams(m.toList());
                          if (mounted) setState(() {});
                        },
                      ),
                    );
                  }),
              ]),
            ],
          ]),
        );
      });
    }

    return _shell(
      title: _t('Tes équipes', 'Your teams'),
      sub: _t('Coche tes équipes préférées : leurs matchs sont mis en avant.', 'Tick your favourite teams: their matches are highlighted.'),
      tv: tv,
      primary: widget.sportOnly ? _t('Terminer', 'Done') : _t('Continuer', 'Continue'),
      onPrimary: () => widget.sportOnly ? widget.onDone() : go(7),
      content: body(),
    );
  }

  // ---------------------------------------------------------------- 5. récap
  Widget _recap(bool tv) {
    final lang = _langs.firstWhere((l) => l.$1 == L.lang, orElse: () => _langs.first).$2;
    final vx = _verTxt[L.lang] ?? _verTxt['en']!;
    final verTxt = ver.isEmpty ? _t('Automatique', 'Automatic') : [for (final v in ['vf', 'vostfr', 'vo']) if (ver.contains(v)) v == 'vf' ? vx[0] : v == 'vostfr' ? vx[2] : vx[4]].join(' · ');
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
      sub: widget.redo ? _t('Tes onglets et ton accueil seront remplacés. Tes catégories ne changent pas.', 'Your tabs and home will be replaced. Your categories stay as they are.') : _t('Dernière étape : on te propose les catégories qui correspondent à tes choix.', 'Last step: we\'ll suggest the categories that match your choices.'),
      tv: tv,
      skip: false,
      primary: widget.redo ? _t('Appliquer', 'Apply') : _t('Choisir mes catégories', 'Choose my categories'),
      onPrimary: _finish,
      extra: _LinkButton(label: _t('Personnaliser mon accueil', 'Customize my home'), onTap: _customHome),
      content: SizedBox(
        width: tv ? 470 : double.infinity,
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
          SizedBox(width: 64, child: onBack == null ? null : Align(alignment: Alignment.centerLeft, child: RoundButton(size: 40, label: _t('Retour', 'Back'), onTap: onBack!, child: const Icon(Icons.chevron_left_rounded, size: 24, color: kText)))),
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
          SizedBox(width: 92, child: onSkip == null ? null : Align(alignment: Alignment.centerRight, child: _LinkButton(label: _t('Passer', 'Skip'), onTap: onSkip!))),
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
    if (MediaQuery.of(context).disableAnimations || Perf.lite) return child;      // télé : pas de couche d'opacité par élément (mémoire) ; la page entière se fond
    final k = i < 8 ? i : 8;
    final int d = 420 + 45 * k;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: d),
      curve: Interval(45 * k / d, 1, curve: _kEase),
      builder: (_, v, c) => Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c)),
      child: child,
    );
  }
}

/// carte de choix : verre teinté au repos, dégradé plein quand elle est cochée, coche à ressort
class _Card extends StatefulWidget {
  final String label;
  final String? sub, flag;
  final IconData? icon;
  final Color a, b;
  final bool selected, darkText, autofocus;
  final double height;
  final VoidCallback onTap;
  const _Card({required this.label, required this.a, required this.b, required this.selected, required this.height, required this.onTap, this.sub, this.flag, this.icon, this.darkText = false, this.autofocus = false});
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
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: kBg2,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: on ? [widget.a, widget.b] : [widget.a.withOpacity(0.10), widget.b.withOpacity(0.10)]),
            border: Border.all(color: on ? const Color(0x59FFFFFF) : kEdge, width: on ? 1.5 : 1),
            boxShadow: on && !Perf.lite ? [BoxShadow(color: widget.a.withOpacity(0.45), blurRadius: 28, spreadRadius: -6)] : null,
          ),
          child: Stack(children: [
            if (widget.flag != null) Positioned(left: 16, top: 14, child: FlagOrb(code: widget.flag!, size: 46, on: on)),
            if (widget.icon != null) Positioned(left: 16, top: 14, child: Icon(widget.icon, size: 40, color: on ? fg : Colors.white.withOpacity(0.92))),
            Positioned(
              left: 16,
              bottom: 14,
              right: 10,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(widget.label, maxLines: 2, style: T(widget.label.split(' ').any((w) => w.length > 11) ? 15 : 17, w: 700, ls: -0.01, color: fg)),
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
                Text(title, style: T(17, w: 700, ls: -0.01)),
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
          duration: Duration(milliseconds: Perf.lite ? 0 : 800),
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

/// pastille drapeau : disque aux couleurs du pays, anneau clair et reflet de verre (dessiné, aucune image)
class FlagOrb extends StatelessWidget {
  final String code;
  final double size;
  final bool on;
  const FlagOrb({required this.code, required this.size, required this.on});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(on ? 0.9 : 0.35), width: 2),
          boxShadow: Perf.lite ? null : [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipOval(child: CustomPaint(painter: _FlagPainter(code), foregroundPainter: _SheenPainter())),
      );
}

class _SheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(r, Paint()..shader = ui.Gradient.radial(Offset(size.width * 0.3, size.height * 0.25), size.width * 0.9, [Colors.white.withOpacity(0.35), Colors.white.withOpacity(0)]));
    canvas.drawRect(r, Paint()..shader = ui.Gradient.linear(Offset(0, size.height * 0.55), Offset(0, size.height), [Colors.black.withOpacity(0), Colors.black.withOpacity(0.22)]));
  }

  @override
  bool shouldRepaint(_SheenPainter o) => false;
}

class _FlagPainter extends CustomPainter {
  final String code;
  _FlagPainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Paint f(int c) => Paint()..color = Color(c);
    switch (code) {
      case 'fr':
        canvas.drawRect(Rect.fromLTWH(0, 0, w / 3, h), f(0xFF1F4FD8));
        canvas.drawRect(Rect.fromLTWH(w / 3, 0, w / 3, h), f(0xFFFFFFFF));
        canvas.drawRect(Rect.fromLTWH(2 * w / 3, 0, w / 3, h), f(0xFFE5303C));
      case 'es':
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h), f(0xFFC8102E));
        canvas.drawRect(Rect.fromLTWH(0, h * 0.25, w, h * 0.5), f(0xFFFFC400));
      case 'de':
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 3), f(0xFF1A1A1A));
        canvas.drawRect(Rect.fromLTWH(0, h / 3, w, h / 3), f(0xFFDD0000));
        canvas.drawRect(Rect.fromLTWH(0, 2 * h / 3, w, h / 3), f(0xFFFFCE00));
      case 'pt':
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.4, h), f(0xFF046A38));
        canvas.drawRect(Rect.fromLTWH(w * 0.4, 0, w * 0.6, h), f(0xFFDA291C));
        canvas.drawCircle(Offset(w * 0.4, h / 2), h * 0.2, f(0xFFFFE000));
        canvas.drawCircle(Offset(w * 0.4, h / 2), h * 0.12, f(0xFFDA291C));
        canvas.drawCircle(Offset(w * 0.4, h / 2), h * 0.07, f(0xFFFFFFFF));
      default:
        canvas.drawRect(Offset.zero & size, f(0xFF1B2F7A));
        Path band(double d, bool rev) => Path()
          ..moveTo(rev ? w : 0, 0)
          ..lineTo(rev ? w - d : d, 0)
          ..lineTo(rev ? 0 : w, h)
          ..lineTo(rev ? d : w - d, h)
          ..close();
        for (final rev in [false, true]) {
          canvas.drawPath(band(h * 0.2, rev), f(0xFFFFFFFF));
          canvas.drawPath(band(h * 0.08, rev), f(0xFFD02A3C));
        }
        canvas.drawRect(Rect.fromLTWH(w * 0.39, 0, w * 0.22, h), f(0xFFFFFFFF));
        canvas.drawRect(Rect.fromLTWH(0, h * 0.39, w, h * 0.22), f(0xFFFFFFFF));
        canvas.drawRect(Rect.fromLTWH(w * 0.44, 0, w * 0.12, h), f(0xFFD02A3C));
        canvas.drawRect(Rect.fromLTWH(0, h * 0.44, w, h * 0.12), f(0xFFD02A3C));
    }
  }

  @override
  bool shouldRepaint(_FlagPainter o) => o.code != code;
}

/// carte à cocher compacte : pastille (logo), nom, coche ; dégradé quand elle est cochée
class _PickTile extends StatelessWidget {
  final Widget leading;
  final String label;
  final bool on, autofocus;
  final Color a, b;
  final VoidCallback onTap;
  const _PickTile({required this.leading, required this.label, required this.on, required this.a, required this.b, required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) => FocusCard(
        radius: 18,
        focusScale: Device.tv ? 1.05 : 1.02,
        autofocus: autofocus,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: kBg2,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: on ? [a, b] : [a.withOpacity(0.10), b.withOpacity(0.10)]),
            border: Border.all(color: on ? const Color(0x59FFFFFF) : kEdge, width: on ? 1.5 : 1),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(children: [
              Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(on ? 0.16 : 0.08)), child: leading),
              const Spacer(),
              _Tick(on: on),
            ]),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(14, w: 700, h: 1.15))),
          ]),
        ),
      );
}

/// Réglages › Sport : mêmes cartes que la configuration (sports, compétitions, équipes) ; rend les compétitions suivies
Future<List<String>?> editSports(BuildContext context) async {
  await Navigator.push(context, MaterialPageRoute(builder: (ctx) => OnboardingFlow(sportOnly: true, onDone: () => Navigator.of(ctx).pop())));
  return Store.sportKeys;
}
