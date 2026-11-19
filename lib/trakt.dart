import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'names.dart';
import 'store.dart';
import 'xtream.dart';

/// Trakt : historique (envoi des titres vus) et liste « à voir » (rangée d'accueil). Le Client ID est public par nature.
class Trakt {
  static const _id = 'uBW1mSsbx9TBlLWlTsvu6h5GQDxVdFNIBfYzpaTTj0U';
  static const _api = 'https://api.trakt.tv';

  static Map<String, dynamic> get _tok {
    try {
      return jsonDecode(Store.str('trakt_tok')) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static bool get linked => (_tok['access_token'] as String? ?? '').isNotEmpty;
  static Future<void> unlink() async {
    await Store.setStr('trakt_tok', '');
    _wl = null;
  }

  static Map<String, String> _h([bool auth = true]) => {
        'Content-Type': 'application/json',
        'trakt-api-key': _id,
        'trakt-api-version': '2',
        if (auth && linked) 'Authorization': 'Bearer ${_tok['access_token']}',
      };

  /// 1re étape : code court à saisir sur trakt.tv/activate
  static Future<Map<String, dynamic>?> start() async {
    try {
      final r = await http.post(Uri.parse('$_api/oauth/device/code'), headers: _h(false), body: jsonEncode({'client_id': _id})).timeout(const Duration(seconds: 15));
      return r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic> : null;
    } catch (_) {
      return null;
    }
  }

  /// 2e étape : attend que le code soit validé sur le site ; vrai si le compte est lié
  static Future<bool> wait(Map<String, dynamic> d, bool Function() cancelled) async {
    final end = DateTime.now().add(Duration(seconds: (d['expires_in'] as num?)?.toInt() ?? 600));
    final every = Duration(seconds: ((d['interval'] as num?)?.toInt() ?? 5) + 1);
    while (DateTime.now().isBefore(end) && !cancelled()) {
      await Future.delayed(every);
      if (cancelled()) return false;
      try {
        final r = await http.post(Uri.parse('$_api/oauth/device/token'), headers: _h(false), body: jsonEncode({'code': d['device_code'], 'client_id': _id})).timeout(const Duration(seconds: 15));
        if (r.statusCode == 200) {
          await Store.setStr('trakt_tok', r.body);
          return true;
        }
        if (r.statusCode != 400) return false;      // 400 = pas encore validé ; autre = refusé / expiré
      } catch (_) {}
    }
    return false;
  }

  // ---- historique : un titre vu à plus de 90 % est envoyé une fois
  static Set<String> get _sent => Store.str('trakt_sent').split('|').where((x) => x.isNotEmpty).toSet();

  static Future<void> watched(Prog p) async {
    if (!linked || p.dur <= 0 || p.pos < p.dur * 0.9) return;
    final sent = _sent;
    if (sent.contains(p.key)) return;
    Map<String, dynamic>? body;
    if (p.kind == 'ep') {
      final m = RegExp(r'S(\d+) · É(\d+)').firstMatch(p.name);
      if (m == null) return;
      body = {
        'shows': [
          {
            'title': p.sname,
            'seasons': [
              {'number': int.parse(m[1]!), 'episodes': [{'number': int.parse(m[2]!)}]}
            ],
          }
        ]
      };
    } else {
      final t = parseTitle(p.name, Kind.vod);
      body = {
        'movies': [
          {'title': t.title, if (t.year.isNotEmpty) 'year': int.tryParse(t.year)}
        ]
      };
    }
    try {
      final r = await http.post(Uri.parse('$_api/sync/history'), headers: _h(), body: jsonEncode(body)).timeout(const Duration(seconds: 15));
      if (r.statusCode == 201 || r.statusCode == 200) await Store.setStr('trakt_sent', ([...sent, p.key].toList()..sort()).reversed.take(300).join('|'));
    } catch (_) {}
  }

  // ---- liste « à voir »
  static List<(String, int)>? _wl;
  static DateTime _wlT = DateTime(2000);

  /// titres (nom, année) de la liste Trakt ; mémorisés 10 min
  static Future<List<(String, int)>> watchlist() async {
    if (!linked) return const [];
    if (_wl != null && DateTime.now().difference(_wlT).inMinutes < 10) return _wl!;
    final out = <(String, int)>[];
    for (final k in ['movies', 'shows']) {
      try {
        final r = await http.get(Uri.parse('$_api/sync/watchlist/$k'), headers: _h()).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) continue;
        for (final e in jsonDecode(r.body) as List) {
          final m = (e as Map)[k == 'movies' ? 'movie' : 'show'] as Map?;
          if (m != null) out.add(('${m['title']}', (m['year'] as num?)?.toInt() ?? 0));
        }
      } catch (_) {}
    }
    _wl = out;
    _wlT = DateTime.now();
    return out;
  }

  /// titres de la liste Trakt présents dans le catalogue
  static Future<List<Item>> inCatalog(List<Item> cat) async {
    final wl = await watchlist();
    if (wl.isEmpty) return const [];
    final by = <String, Item>{};
    for (final i in cat) {
      by.putIfAbsent(norm(i.title), () => i);
    }
    return [for (final w in wl) if (by[norm(w.$1)] != null) by[norm(w.$1)]!];
  }
}
