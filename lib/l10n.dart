import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'l10n_de.dart';
import 'l10n_en.dart';
import 'l10n_es.dart';
import 'l10n_pt.dart';
import 'store.dart';

/// langue de l'appli : français ou anglais (par défaut celle de l'appareil) ; les textes sont écrits en français et traduits à l'affichage
class L {
  static String lang = 'fr';
  static final changed = ValueNotifier<String>('fr');
  /// l'interface n'est traduite qu'en français et en anglais : toute autre langue (es, de, pt) affiche l'anglais ; la langue sert aux contenus (fiches, catégories, audio, sous-titres)
  static bool get en => lang != 'fr';
  static const supported = ['fr', 'en', 'es', 'de', 'pt'];
  static const names = {'fr': 'Français', 'en': 'English', 'es': 'Español', 'de': 'Deutsch', 'pt': 'Português'};
  static String get tmdb => const {'fr': 'fr-FR', 'en': 'en-US', 'es': 'es-ES', 'de': 'de-DE', 'pt': 'pt-PT'}[lang] ?? 'en-US';
  /// disposition du clavier de la télé
  static bool get azerty => !en;

  /// le code de langue d'une piste audio ou sous-titres (« fra », « fre », « fr »…) correspond-il à la langue choisie ?
  static bool trackIs(String? code, String pref) {
    final c = (code ?? '').toLowerCase();
    if (pref.isEmpty || c.isEmpty) return false;
    const alias = {'fr': ['fr', 'fra', 'fre'], 'en': ['en', 'eng'], 'es': ['es', 'spa'], 'de': ['de', 'deu', 'ger'], 'pt': ['pt', 'por']};
    return (alias[pref] ?? [pref]).any(c.startsWith);
  }

  static void init() {
    final s = Store.str('lang');
    final dev = PlatformDispatcher.instance.locale.languageCode;
    lang = s.isNotEmpty ? s : (supported.contains(dev) ? dev : 'en');
    changed.value = lang;
  }

  static Future<void> set(String v) async {
    await Store.setStr('lang', v);
    lang = v;
    _cache.clear();
    changed.value = v;
  }

  static final _cache = <String, String>{};
  static final _tpl = <String, List<(RegExp, String)>>{};

  /// dictionnaire de la langue (l'anglais sert de repli aux autres)
  static Map<String, String> get _map => switch (lang) {
        'es' => kEs,
        'de' => kDe,
        'pt' => kPt,
        _ => kEn,
      };

  static String tr(String s) {
    if (lang == 'fr' || s.isEmpty) return s;
    final c = _cache[s];
    if (c != null) return c;
    final t = _map[s] ?? kEn[s] ?? _template(s) ?? s;
    if (_cache.length < 4000) _cache[s] = t;
    return t;
  }

  /// textes à valeurs variables : « Bonjour {} » correspond à « Bonjour Romain »
  static String? _template(String s) {
    final tpl = _tpl[lang] ??= [
      for (final e in kEn.entries)
        if (e.key.contains('{}')) (RegExp('^${e.key.split('{}').map(RegExp.escape).join('(.+?)')}\$', dotAll: true), _map[e.key] ?? e.value)
    ];
    for (final (re, tx) in tpl) {
      final m = re.firstMatch(s);
      if (m == null) continue;
      var i = 0;
      return tx.replaceAllMapped('{}', (_) => ++i <= m.groupCount ? (m.group(i) ?? '') : '');
    }
    return null;
  }
}
