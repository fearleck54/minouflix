import 'dart:convert';
import 'package:http/http.dart' as http;
import 'names.dart';
import 'sport.dart';

/// Ligue 1 / Ligue 2 : chaîne officielle de chaque match (API publique de la LFP, un petit JSON par journée, mis en cache 6 h).
/// Toute erreur = liste vide : l'appli retombe sur le guide et les chaînes habituelles, sans rien afficher.
class Lfp {
  static final _weeks = <String, (DateTime, List<Map>)>{};
  static int _guess = 12;

  static const _alias = {'losc': 'lille', 'ol': 'lyon', 'om': 'marseille', 'psg': 'paris', 'havre': 'havre'};

  static Set<String> _tok(Iterable<String?> names) {
    final out = <String>{};
    for (final n in names) {
      for (final w in norm(n ?? '').split(RegExp(r'[^a-z0-9]+'))) {
        if (w.length >= 3 && !const {'football', 'club', 'stade', 'olympique', 'association', 'sporting', 'ogc', 'fc', 'ac', 'as', 'rc', 'sco', 'les', 'des'}.contains(w)) out.add(_alias[w] ?? w);
      }
    }
    return out;
  }

  static Future<List<Map>?> _week(int champ, int n) async {
    final k = '$champ:$n';
    final hit = _weeks[k];
    if (hit != null && DateTime.now().difference(hit.$1) < const Duration(hours: 6)) return hit.$2;
    try {
      final r = await http.get(Uri.parse('https://ma-api.ligue1.fr/championship-matches/championship/$champ/game-week/$n?season=2026')).timeout(const Duration(seconds: 4));
      if (r.statusCode != 200) return null;
      final l = [for (final m in (jsonDecode(utf8.decode(r.bodyBytes))['matches'] as List? ?? [])) if (m is Map) m];
      _weeks[k] = (DateTime.now(), l);
      return l;
    } catch (_) {
      return null;
    }
  }

  /// noms français des chaînes qui diffusent ce match (vide si inconnu)
  static Future<List<String>> channels(Ev e) async {
    final champ = e.lg == 'l1' ? 1 : e.lg == 'l2' ? 4 : 0;
    if (champ == 0 || e.f1) return const [];
    final when = DateTime.fromMillisecondsSinceEpoch(e.ts * 1000, isUtc: true);
    final th = _tok([e.h.name, e.h.short]), ta = _tok([e.a.name, e.a.short]);
    var n = _guess;
    for (var step = 0; step < 6; step++) {
      final l = await _week(champ, n);
      if (l == null || l.isEmpty) return const [];
      final ds = [for (final m in l) if (DateTime.tryParse('${m['date']}') != null) DateTime.parse('${m['date']}')];
      for (final m in l) {
        final d = DateTime.tryParse('${m['date']}');
        if (d == null || d.difference(when).abs() > const Duration(hours: 3)) continue;
        Set<String> side(String k) => _tok([for (final f in const ['name', 'officialName', 'shortName']) '${(m[k]?['clubIdentity'] ?? {})[f] ?? ''}']);
        final mh = side('home'), ma = side('away');
        if (mh.intersection(th).isNotEmpty && ma.intersection(ta).isNotEmpty) {
          _guess = n;
          final loc = (m['broadcasters']?['local'] as List? ?? []);
          return [for (final b in loc) '${(b['name'] ?? {})['fr-FR'] ?? ''}'.trim()].where((s) => s.isNotEmpty).toList();
        }
      }
      if (ds.isEmpty) return const [];
      ds.sort();
      if (when.isBefore(ds.first.subtract(const Duration(hours: 3)))) {
        n--;
      } else if (when.isAfter(ds.last.add(const Duration(hours: 3)))) {
        n++;
      } else {
        return const [];      // dans la journée mais match introuvable
      }
      if (n < 1 || n > 40) return const [];
    }
    return const [];
  }

  /// « FR| Ligue 1+ 2 FHD » → « LIGUE1+2 »
  static String key(String s) {
    var t = norm(s).toUpperCase();
    t = t.replaceAll(RegExp(r'\b(FHD|UHD|HD|SD|4K|HEVC|H265|FR|FRANCE)\b'), ' ').replaceAll(RegExp(r'[\[\](){}|:\-_]'), ' ');
    return t.replaceAll(RegExp(r'\s+'), '');
  }
}
