import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'l10n_en.dart';
import 'store.dart';

/// langue de l'appli : français ou anglais (par défaut celle de l'appareil) ; les textes sont écrits en français et traduits à l'affichage
class L {
  static String lang = 'fr';
  static final changed = ValueNotifier<String>('fr');
  static bool get en => lang == 'en';
  static String get tmdb => en ? 'en-US' : 'fr-FR';
  /// disposition du clavier de la télé
  static bool get azerty => !en;

  static void init() {
    final s = Store.str('lang');
    lang = s.isNotEmpty ? s : (PlatformDispatcher.instance.locale.languageCode == 'fr' ? 'fr' : 'en');
    changed.value = lang;
  }

  static Future<void> set(String v) async {
    await Store.setStr('lang', v);
    lang = v;
    _cache.clear();
    changed.value = v;
  }

  static final _cache = <String, String>{};
  static List<(RegExp, String)>? _tpl;

  static String tr(String s) {
    if (lang == 'fr' || s.isEmpty) return s;
    final c = _cache[s];
    if (c != null) return c;
    final t = kEn[s] ?? _template(s) ?? s;
    if (_cache.length < 4000) _cache[s] = t;
    return t;
  }

  /// textes à valeurs variables : « Bonjour {} » correspond à « Bonjour Romain »
  static String? _template(String s) {
    _tpl ??= [
      for (final e in kEn.entries)
        if (e.key.contains('{}')) (RegExp('^${e.key.split('{}').map(RegExp.escape).join('(.+?)')}\$', dotAll: true), e.value)
    ];
    for (final (re, en) in _tpl!) {
      final m = re.firstMatch(s);
      if (m == null) continue;
      var i = 0;
      return en.replaceAllMapped('{}', (_) => ++i <= m.groupCount ? (m.group(i) ?? '') : '');
    }
    return null;
  }
}
