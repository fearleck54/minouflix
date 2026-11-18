import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'keys.dart';
import 'names.dart';
import 'l10n.dart';
import 'store.dart';
import 'xtream.dart';

/// TMDB : logos de titres, grandes images, casting, suggestions, tendances (mêmes données que l'appli web)
String tmImg(String path, [String w = 'w342']) => path.isEmpty ? '' : 'https://image.tmdb.org/t/p/$w$path';

class Cast {
  final String name, role, photo;
  const Cast(this.name, this.role, this.photo);
}

class Fiche {
  final int tmdbId;
  final String trailer, logo, tagline, plot, bg, sagaName, title, cert;     // cert : classification française (U, 10, 12, 16, 18)
  final int runtime;
  final List<String> genres;
  final List<Cast> cast;
  final List<String> simTitles, sagaTitles;
  final List<(String, String)> providers;
  const Fiche({this.tmdbId = 0, this.cert = '', this.title = '', this.runtime = 0, this.genres = const [], this.trailer = '', this.logo = '', this.tagline = '', this.plot = '', this.bg = '', this.sagaName = '', this.cast = const [], this.simTitles = const [], this.sagaTitles = const [], this.providers = const []});
}

/// âge minimal d'après la classification française : 0 (tout public), 10, 12, 16, 18 ; -1 si inconnue
int certAge(String c) {
  final s = c.trim().toUpperCase();
  if (s.isEmpty) return -1;
  if (s == 'U' || s == 'TP' || s == 'ALL') return 0;
  return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? -1;
}

class Tmdb {
  static final _fiches = <String, Future<Fiche?>>{};

  static Future<dynamic> _get(String path, Map<String, String> q) async {
    final u = Uri.https('api.themoviedb.org', '/3$path', {'api_key': kTmdbKey, ...q});
    final r = await http.get(u).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('tmdb ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  /// changement de source : fiches, studios et calendrier de l'ancienne source sont oubliés
  static void reset() {
    _fiches.clear();
    Studios._mem.clear();
  }

  static Future<dynamic> raw(String path, Map<String, String> q) => _get(path, q);

  static Future<Fiche?> fiche(Item it) => _fiches.putIfAbsent('${it.kind.name}${it.id}', () => _fiche(it));

  static Future<Fiche?> _fiche(Item it) async {
    if (kTmdbKey.isEmpty || it.kind == Kind.live) return null;
    try {
      final ep = it.kind == Kind.vod ? 'movie' : 'tv';
      final y = it.year;
      final res = ((await _get('/search/$ep', {'query': it.title, 'language': L.tmdb, if (RegExp(r'^\d{4}$').hasMatch(y)) (it.kind == Kind.vod ? 'year' : 'first_air_date_year'): y}))['results'] as List? ?? []).cast<Map>();
      final nm = norm(it.title);
      Map? hit;
      for (final x in res) {
        if (nm == norm('${x['title'] ?? x['name'] ?? ''}') || nm == norm('${x['original_title'] ?? x['original_name'] ?? ''}')) {
          hit = x;
          break;
        }
      }
      hit ??= res.isNotEmpty && RegExp(r'^\d{4}$').hasMatch(y) ? res.first : null;
      if (hit == null) return null;
      final x = await _get('/$ep/${hit['id']}', {'language': L.tmdb, 'append_to_response': 'credits,videos,watch/providers,images,recommendations,release_dates,content_ratings', 'include_video_language': 'fr,en,null', 'include_image_language': 'fr,en'}) as Map;
      final vids = (((x['videos'] as Map?)?['results']) as List? ?? []).cast<Map>().where((v) => v['site'] == 'YouTube' && (v['type'] == 'Trailer' || v['type'] == 'Teaser')).toList()
        ..sort((a, b) {
          int k(Map v) => (v['type'] != 'Trailer' ? 4 : 0) + (v['iso_639_1'] != 'fr' ? 2 : 0) + (v['official'] == true ? 0 : 1);
          return k(a) - k(b);
        });
      final cast = [
        for (final m in (((x['credits'] as Map?)?['cast']) as List? ?? []).take(14))
          if (m is Map && m['name'] != null) Cast('${m['name']}', '${m['character'] ?? ''}', '${m['profile_path'] ?? ''}'),
      ];
      final fr = ((((x['watch/providers'] as Map?)?['results']) as Map?)?['FR']) as Map? ?? {};
      final seen = <dynamic>{};
      final prov = <(String, String)>[];
      for (final kd in const ['flatrate', 'free', 'ads']) {
        for (final p in (fr[kd] as List? ?? []).cast<Map>()) {
          if (p['logo_path'] != null && seen.add(p['provider_id'])) prov.add(('${p['provider_name']}', '${p['logo_path']}'));
        }
      }
      final sim = [for (final m in (((x['recommendations'] as Map?)?['results']) as List? ?? []).take(20)) if (m is Map) '${m['title'] ?? m['name'] ?? ''}'];
      final lgs = (((x['images'] as Map?)?['logos']) as List? ?? []).cast<Map>().where((g) => '${g['file_path']}'.endsWith('.png')).toList()
        ..sort((a, b) {
          final fa = a['iso_639_1'] == 'fr' ? 0 : 1, fb = b['iso_639_1'] == 'fr' ? 0 : 1;
          return fa != fb ? fa - fb : ((b['vote_average'] as num?) ?? 0).compareTo((a['vote_average'] as num?) ?? 0);
        });
      var sagaName = '';
      var sagaTitles = <String>[];
      final col = x['belongs_to_collection'];
      if (it.kind == Kind.vod && col is Map) {
        try {
          final c = await _get('/collection/${col['id']}', {'language': L.tmdb}) as Map;
          sagaName = '${col['name'] ?? ''}';
          sagaTitles = [for (final p in (c['parts'] as List? ?? []).cast<Map>()) '${p['title'] ?? ''}'];
        } catch (_) {}
      }
      final rt = (x['runtime'] as num?)?.toInt() ?? ((x['episode_run_time'] as List?)?.isNotEmpty == true ? (x['episode_run_time'][0] as num).toInt() : 0);
      var cert = '';
      for (final r in (((x['release_dates'] as Map?)?['results']) as List? ?? []).cast<Map>()) {
        if (r['iso_3166_1'] != 'FR') continue;
        for (final d in (r['release_dates'] as List? ?? []).cast<Map>()) {
          if ('${d['certification']}'.isNotEmpty && cert.isEmpty) cert = '${d['certification']}';
        }
      }
      for (final r in (((x['content_ratings'] as Map?)?['results']) as List? ?? []).cast<Map>()) {
        if (r['iso_3166_1'] == 'FR' && '${r['rating']}'.isNotEmpty && cert.isEmpty) cert = '${r['rating']}';
      }
      return Fiche(
        tmdbId: (hit['id'] as num?)?.toInt() ?? 0,
        cert: cert,
        title: '${x['title'] ?? x['name'] ?? ''}',
        runtime: rt,
        genres: [for (final g in (x['genres'] as List? ?? [])) if (g is Map) '${g['name']}'],
        trailer: vids.isEmpty ? '' : '${vids.first['key']}',
        logo: lgs.isEmpty ? '' : '${lgs.first['file_path']}',
        tagline: '${x['tagline'] ?? ''}',
        plot: '${x['overview'] ?? ''}',
        bg: '${x['backdrop_path'] ?? ''}',
        cast: cast,
        providers: prov.take(10).toList(),
        simTitles: sim,
        sagaName: sagaName,
        sagaTitles: sagaTitles,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map>>? _aff;

  /// films sortis au cinéma en France ces 5 derniers mois
  static Future<List<Map>> nowPlaying() => _aff ??= () async {
        try {
          final now = DateTime.now();
          final lim = now.subtract(const Duration(days: 150)).toIso8601String().substring(0, 10), today = now.toIso8601String().substring(0, 10);
          final pages = await Future.wait([for (var p = 1; p <= 6; p++) _get('/movie/now_playing', {'language': L.tmdb, 'region': 'FR', 'page': '$p'}).then<dynamic>((v) => v).catchError((_) => null)]);
          final out = <Map>[];
          for (final pg in pages) {
            if (pg == null) continue;
            for (final x in (pg['results'] as List? ?? []).cast<Map>()) {
              final d = '${x['release_date'] ?? ''}';
              if (x['poster_path'] != null && d.compareTo(lim) >= 0 && d.compareTo(today) <= 0 && ((x['popularity'] as num?) ?? 0) >= 3 && ((x['vote_count'] as num?) ?? 0) >= 3) out.add(x);
            }
          }
          out.sort((a, b) => '${b['release_date']}'.compareTo('${a['release_date']}'));
          return out;
        } catch (_) {
          return <Map>[];
        }
      }();

  static Future<List<Map>>? _top;

  /// tendances de la semaine (films et séries)
  static Future<List<Map>> trending() => _top ??= () async {
        try {
          final pages = await Future.wait([for (var p = 1; p <= 5; p++) _get('/trending/all/week', {'language': L.tmdb, 'page': '$p'}).then<dynamic>((v) => v).catchError((_) => null)]);
          return [
            for (final pg in pages)
              if (pg != null) for (final x in (pg['results'] as List? ?? []).cast<Map>()) if ((x['media_type'] == 'movie' || x['media_type'] == 'tv') && x['adult'] != true) x,
          ];
        } catch (_) {
          return <Map>[];
        }
      }();
}

/// studio apparié au catalogue : nom, logo TMDB, titres présents chez le fournisseur
class StudioHit {
  final String name, logo;
  final List<Item> items;
  const StudioHit(this.name, this.logo, this.items);
}

const _studiosFilm = ['Marvel Studios', 'Walt Disney Pictures', 'Pixar', 'Lucasfilm Ltd.', 'Columbia Pictures', '20th Century Studios', 'DreamWorks Animation', 'Warner Bros. Pictures', 'Universal Pictures', 'Paramount Pictures', 'Legendary Pictures', 'Blumhouse Productions', 'A24', 'Lionsgate', 'Illumination', 'Sony Pictures', 'New Line Cinema', 'Metro-Goldwyn-Mayer', 'Studio Ghibli', 'Focus Features', 'Amblin Entertainment', 'Netflix', 'Apple Studios', 'Gaumont', 'Pathé', 'StudioCanal', 'EuropaCorp'];
const _studiosTv = ['HBO', 'Netflix', 'Amazon MGM Studios', 'Apple Studios', 'Warner Bros. Television', 'BBC Studios', 'FX Productions', 'AMC Studios', 'Showtime', 'Paramount Television Studios', 'Sony Pictures Television', 'Universal Television', '20th Television', 'Disney Television Studios', 'Marvel Television', 'Lionsgate Television', 'Legendary Television', 'Canal+', 'France Télévisions', 'TF1 Production', 'Hulu', 'Starz', 'Syfy', 'Hartswood Films', 'ITV Studios'];

class Studios {
  static final _mem = <Kind, Future<List<StudioHit>>>{};

  /// mêmes studios que l'appli web : sociétés de production TMDB appariées aux titres choisis (mémorisé 7 jours)
  static Future<List<StudioHit>> of(Lib lib) => _mem.putIfAbsent(lib.kind, () => _build(lib));
  static bool ready(Kind k) => _mem.containsKey(k);
  /// bibliothèque complète (ou rechargée) : on refait l'appariement (le fichier de 7 jours évite de redemander TMDB)
  static void forget(Kind k) => _mem.remove(k);

  static Future<List<StudioHit>> _build(Lib lib) async {
    if (kTmdbKey.isEmpty) return [];
    final tv = lib.kind == Kind.series;
    File? f;
    if (!kIsWeb) {
      f = File('${(await getApplicationSupportDirectory()).path}/${Store.pre}studios_${lib.kind.name}.json');
      if (await f.exists() && DateTime.now().difference(await f.lastModified()) < const Duration(days: 7)) {
        try {
          final byId = {for (final r in lib.rows) r.id: r};
          final out = <StudioHit>[];
          for (final s in jsonDecode(await f.readAsString()) as List) {
            final l = [for (final i in s['ids'] as List) if (byId[i as int] != null) byId[i]!];
            if (l.length >= 4) out.add(StudioHit('${s['n']}', '${s['l']}', l));
          }
          if (out.isNotEmpty) return out;
        } catch (_) {}
      }
    }
    final names = tv ? _studiosTv : _studiosFilm;
    final res = List<StudioHit?>.filled(names.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < names.length) {
        final n = next++;
        try {
          res[n] = await _one(lib, names[n], tv);
        } catch (_) {}
      }
    }
    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
    final out = [for (final r in res) if (r != null) r];
    if (f != null && out.isNotEmpty) {
      await f.writeAsString(jsonEncode([for (final s in out) {'n': s.name, 'l': s.logo, 'ids': [for (final i in s.items) i.id]}]));
    }
    return out;
  }

  static Future<StudioHit?> _one(Lib lib, String name, bool tv) async {
    final d = await Tmdb._get('/search/company', {'query': name});
    final rs = [for (final x in (d['results'] as List? ?? [])) if (x is Map && '${x['logo_path'] ?? ''}'.isNotEmpty) x];
    if (rs.isEmpty) return null;
    final co = rs.firstWhere((x) => norm('${x['name']}') == norm(name), orElse: () => rs.first);
    final items = <Item>[];
    final seen = <int>{};
    for (var pg = 1; pg <= 6; pg++) {
      final p = await Tmdb._get(tv ? '/discover/tv' : '/discover/movie', {'with_companies': '${co['id']}', 'sort_by': 'popularity.desc', 'language': L.tmdb, 'page': '$pg'});
      final l = p['results'] as List? ?? [];
      for (final m in l) {
        final date = '${m['release_date'] ?? m['first_air_date'] ?? ''}';
        final y = date.length >= 4 ? date.substring(0, 4) : '';
        for (final t in {'${m['title'] ?? ''}', '${m['original_title'] ?? ''}', '${m['name'] ?? ''}', '${m['original_name'] ?? ''}'}) {
          if (t.isEmpty) continue;
          final hit = lib.byTitle(t, year: tv ? '' : y);
          if (hit != null && seen.add(hit.id)) {
            items.add(hit);
            break;
          }
        }
      }
      if (l.length < 20) break;
    }
    if (items.length < 4) return null;
    return StudioHit(name.replaceAll(' Ltd.', '').replaceAll(' Productions', ''), '${co['logo_path']}', items);
  }
}
