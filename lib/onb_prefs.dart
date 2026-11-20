import 'l10n.dart';
import 'store.dart';

/// Réponses du parcours de configuration (nouveau compte) et leurs effets sur les réglages.
/// Goûts, dans l'ordre où l'utilisateur les a cochés : films, series, live, sport, kids, docs.
class OnbPrefs {
  static List<String>? _t;
  static bool ignore = false;      // secours : présélection vide → on retombe sur la règle d'origine

  static List<String> get tastes => _t ??= Store.str('onb_tastes').split(',').where((x) => x.isNotEmpty).toList();
  static Future<void> setTastes(List<String> v) async {
    _t = v;
    await Store.setStr('onb_tastes', v.join(','));
  }

  /// versions voulues (cumulatif) : vf, vostfr, vo
  static List<String> get ver => Store.str('onb_ver').split(',').where((x) => x.isNotEmpty).toList();
  static Future<void> setVer(List<String> v) => Store.setStr('onb_ver', v.join(','));

  static bool get active => tastes.isNotEmpty && !ignore;

  static const tabOf = {'films': 2, 'series': 3, 'live': 1, 'sport': 4};
  static const _sections = {
    'films': ['top10', 'affiche', 'recoV', 'recent'],
    'series': ['soon', 'recoS', 'recentS'],
    'live': ['chains'],
    'sport': ['sport'],
  };

  /// onglets : Accueil toujours, puis les goûts dans l'ordre choisi ; les autres sont masqués
  static (List<int>, Set<int>) tabsFor(List<String> t) {
    var tabs = [0, for (final x in t) if (tabOf[x] != null) tabOf[x]!];
    if (tabs.length == 1) tabs = [0, 2, 3];      // rien de précis (ex. seulement enfants/docs) : films et séries
    final rest = [for (final k in [2, 3, 1, 4]) if (!tabs.contains(k)) k];
    return ([...tabs, ...rest], rest.toSet());
  }

  /// accueil : sections de chaque goût dans l'ordre choisi, puis les communes ; sections des goûts non choisis masquées
  static (List<String>, Set<String>) homeFor(List<String> t) {
    final hasTab = t.any((x) => tabOf[x] != null);
    final order = <String>[];
    void add(String s) {
      if (!order.contains(s)) order.add(s);
    }

    final soloSport = t.length == 1 && t.first == 'sport';
    if (soloSport) add('sport');
    add('hero');
    add('continue');
    for (final x in t) {
      for (final s in _sections[x] ?? const <String>[]) {
        add(s);
      }
    }
    for (final s in ['mylist', 'playlists', 'downloads', 'trakt']) {
      add(s);
    }
    final hidden = <String>{};
    if (hasTab) {
      for (final e in _sections.entries) {
        if (!t.contains(e.key)) hidden.addAll(e.value);
      }
      if (t.contains('films') || t.contains('series')) hidden.remove('top10');
      if (soloSport) hidden.add('hero');
    }
    for (final s in Store.homeIds) {
      add(s);
    }
    return (order, hidden);
  }

  /// langue audio / sous-titres d'après les versions cochées (les réglages existants ne gèrent qu'un choix par rubrique)
  static (String, String) audioSub(List<String> v, String lang) {
    final a = L.supported.contains(lang) ? lang : 'fr';
    if (v.isEmpty) return ('', '');
    final vf = v.contains('vf'), st = v.contains('vostfr');
    if (vf) return (a, st ? '' : 'no');
    if (st) return ('', a);
    return ('', 'no');
  }

  /// écrit tous les réglages (jamais avant le récap) ; `categories` n'est pas touché ici
  static Future<void> apply({required List<String> tastes, required List<String> ver}) async {
    await setTastes(tastes);
    await setVer(ver);
    final tb = tabsFor(tastes);
    await Store.setTabs(tb.$1, tb.$2, -1);
    final h = homeFor(tastes);
    await Store.setHome(h.$1, h.$2);
    final au = audioSub(ver, L.lang);
    await Store.setStr('pref_aud', au.$1);
    await Store.setStr('pref_sub', au.$2);
    await Store.setFlag('onb_done', true);
    await Store.setStr('onb_state', '');
  }
}

final _enRx = RegExp(r'(^|[^a-z])(en|eng|english|uk|gb|us|usa|ca)([^a-z]|$)', caseSensitive: false);
bool looksEnglish(String name) => _enRx.hasMatch(name);

final _langRx = {
  'es': RegExp(r'(^|[^a-z])(es|esp|spa|spain|espagne|espanol|castellano|latino|lat)([^a-z]|$)', caseSensitive: false),
  'de': RegExp(r'(^|[^a-z])(de|ger|germany|deutsch|allemand|allemagne|at|ch)([^a-z]|$)', caseSensitive: false),
  'pt': RegExp(r'(^|[^a-z])(pt|por|portugal|portuguese|portugais|br|brasil|brazil)([^a-z]|$)', caseSensitive: false),
};

/// la catégorie du fournisseur est-elle dans la langue voulue ? (d'après son nom : préfixes « FR| », « ES| »…)
bool looksLang(String lang, String name, bool Function(String) fr) {
  switch (lang) {
    case 'en':
      return looksEnglish(name);
    case 'fr':
      return fr(name);
    default:
      return _langRx[lang]?.hasMatch(name) ?? looksEnglish(name);
  }
}
