import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'l10n.dart';
import 'names.dart';
import 'store.dart';

/// droits TV par pays : qui diffuse quelle compétition, avec dates de validité.
/// Tableau embarqué (assets/rights.json), remplacé par la version publiée sur GitHub (cache 24 h) quand elle est joignable.
/// Hors période de validité ou pays inconnu : aucun diffuseur affirmé, l'appli retombe sur le guide de la playlist.
class Rights {
  static Map<String, dynamic>? _t;

  static const countries = [
    ('FR', 'France'), ('BE', 'Belgique'), ('CH', 'Suisse'), ('GB', 'Royaume-Uni'), ('IE', 'Irlande'), ('US', 'États-Unis'), ('CA', 'Canada'),
    ('ES', 'Espagne'), ('DE', 'Allemagne'), ('AT', 'Autriche'), ('IT', 'Italie'), ('PT', 'Portugal'), ('MA', 'Maroc'), ('DZ', 'Algérie'), ('TN', 'Tunisie'),
  ];

  /// pays choisi dans Réglages, sinon région de l'appareil, sinon langue de l'appli
  static String get country {
    final s = Store.str('country');
    if (s.isNotEmpty) return s;
    final cc = ui.PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? '';
    if (countries.any((c) => c.$1 == cc)) return cc;
    return switch (L.lang) { 'fr' => 'FR', 'es' => 'ES', 'de' => 'DE', 'pt' => 'PT', _ => 'GB' };
  }

  static Future<void> load() async {
    try {
      _t = jsonDecode(await rootBundle.loadString('assets/rights.json')) as Map<String, dynamic>;
    } catch (_) {}
    try {
      final at = int.tryParse(Store.str('rights_t')) ?? 0;
      final cached = Store.str('rights_json');
      if (cached.isNotEmpty) _t = jsonDecode(cached) as Map<String, dynamic>;
      if (DateTime.now().millisecondsSinceEpoch - at > 86400000) {
        final r = await http.get(Uri.parse('https://raw.githubusercontent.com/fearleck54/minouflix/main/data/rights.json')).timeout(const Duration(seconds: 6));
        if (r.statusCode == 200) {
          final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
          if (j['pays'] is Map) {
            _t = j;
            await Store.setStr('rights_json', utf8.decode(r.bodyBytes));
            await Store.setStr('rights_t', '${DateTime.now().millisecondsSinceEpoch}');
          }
        }
      }
    } catch (_) {}
  }

  /// motifs de chaînes pour cette compétition dans le pays courant ; null = pas de donnée (ou hors période)
  static List<RegExp>? patterns(String lg) {
    try {
      final es = (((_t?['pays'] as Map?)?[country] as Map?)?[lg] as List?) ?? const [];
      final now = DateTime.now().toIso8601String().substring(0, 10);
      final out = <RegExp>[];
      for (final x in es) {
        if ('${x['du']}'.compareTo(now) > 0 || '${x['au']}'.compareTo(now) < 0) continue;
        for (final m in (x['motifs'] as List)) {
          out.add(RegExp('$m'));
        }
      }
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// nom de chaîne de playlist ramené à sa forme simple : « FR| Canal+ Sport FHD » → « canal+ sport »
  static String chanKey(String name) {
    var t = norm(name);
    t = t.replaceAll(RegExp(r'^((fr|uk|gb|us|ca|es|de|it|pt|be|ch|ma|dz|tn|ie|at|ex|vip|premium)\s+)+'), '');
    t = t.replaceAll(RegExp(r'\b(fhd|uhd|hd|sd|hevc|h265|4k|50fps|backup|raw|multi)\b'), ' ');
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
