import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'journal.dart';
import 'names.dart';
import 'perf.dart';
import 'version.dart';

enum Kind { live, vod, series }

extension KindX on Kind {
  String get label => switch (this) { Kind.live => 'Direct', Kind.vod => 'Films', Kind.series => 'Séries' };
  String get catAction => switch (this) { Kind.live => 'get_live_categories', Kind.vod => 'get_vod_categories', Kind.series => 'get_series_categories' };
  String get listAction => switch (this) { Kind.live => 'get_live_streams', Kind.vod => 'get_vod_streams', Kind.series => 'get_series' };
}

class Creds {
  final String server, user, pass;
  const Creds(this.server, this.user, this.pass);
  /// source « playlist M3U » : l'adresse de la playlist est dans `server`, l'identifiant porte le marqueur
  const Creds.m3u(String url) : this(url, '@m3u', '');
  bool get isM3u => user == '@m3u';

  /// adresse normalisée : schéma ajouté si absent, pas de « / » final
  String get base {
    var s = server.trim();
    if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(s)) s = 'http://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Map<String, String> toJson() => {'server': server, 'user': user, 'pass': pass};
  static Creds? fromJson(Map<String, dynamic>? j) => j == null ? null : Creds(j['server'] as String, j['user'] as String, j['pass'] as String);
}

class Cat {
  final String id, name;
  const Cat(this.id, this.name);
}

class Item {
  final int id;
  final String name, icon, ext, catId;
  final Kind kind;
  final double rating;   // sur 10
  final int added;       // date d'ajout (secondes)
  final String epg;      // identifiant du guide (chaînes)
  final int arch;        // rattrapage (chaînes) : jours d'archive proposés par le fournisseur, 0 = aucun
  Item(this.id, this.name, this.icon, this.ext, this.catId, this.kind, {this.rating = 0, this.added = 0, this.epg = '', this.arch = 0});

  /// titre nettoyé, année, qualité (mêmes règles que l'appli web)
  late final Parsed p = parseTitle(name, kind);
  String get title => kind == Kind.live ? splitChannel(name).$1 : p.title;
  String get year => p.year;
  String get quality => kind == Kind.live ? (splitChannel(name).$4.startsWith('4K') ? '4K' : '') : p.q;
  bool get isNew => added > DateTime.now().millisecondsSinceEpoch ~/ 1000 - 7 * 86400;

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'i': icon, 'e': ext, 'c': catId, 'k': kind.index, 'r': rating, 'a': added, 'g': epg, 'h': arch};
  factory Item.fromJson(Map<String, dynamic> j) => Item(j['id'] as int, j['n'] as String, j['i'] as String, j['e'] as String, j['c'] as String, Kind.values[j['k'] as int],
      rating: (j['r'] as num?)?.toDouble() ?? 0, added: (j['a'] as num?)?.toInt() ?? 0, epg: (j['g'] as String?) ?? '', arch: (j['h'] as num?)?.toInt() ?? 0);
}

/// fiche d'un film ou d'une série (résumé, fond d'écran…)
class Detail {
  final String plot, genre, backdrop, duration, year, cast, director;
  const Detail({this.plot = '', this.genre = '', this.backdrop = '', this.duration = '', this.year = '', this.cast = '', this.director = ''});
}

class Episode {
  final int id;
  final String title, ext;
  final int season, number;
  const Episode(this.id, this.title, this.ext, this.season, this.number);
}

class XtreamError implements Exception {
  final String message;
  XtreamError(this.message);
  @override
  String toString() => message;
}

/// Client de l'API Xtream Codes : ne télécharge que ce qu'on lui demande (catégories, puis seulement les catégories choisies).
class Xtream {
  final Creds c;
  String _streamBase;
  Xtream(this.c) : _streamBase = c.base;

  Uri _api(String? action, [Map<String, String>? extra]) => Uri.parse('${c.base}/player_api.php').replace(queryParameters: {
        'username': c.user,
        'password': c.pass,
        if (action != null) 'action': action,
        ...?extra,
      });

  /// 2 requêtes en parallèle au plus, démarrées avec un petit écart : les fournisseurs limitent le débit (erreur 429)
  /// l'écart s'allonge après un refus (429) et revient doucement à 400 ms quand tout va bien
  static int _active = 0;
  static int _gapMs = 250, _minGap = 250, _cap = 3;      // plus rapide au départ ; dès le 1er refus : 2 requêtes, 400 ms
  static DateTime _last = DateTime(2000);
  static final _wait = <Completer<void>>[];
  static Future<T> _gate<T>(Future<T> Function() f) async {
    while (_active >= _cap) {
      final w = Completer<void>();
      _wait.add(w);
      await w.future;
    }
    _active++;
    try {
      final g = Duration(milliseconds: _gapMs);
      final gap = DateTime.now().difference(_last);
      _last = DateTime.now().add(gap < g ? g - gap : Duration.zero);
      if (gap < g) await Future<void>.delayed(g - gap);
      return await f();
    } finally {
      _active--;
      if (_wait.isNotEmpty) _wait.removeAt(0).complete();
    }
  }

  /// `rapide` : connexion et liste des catégories (l'utilisateur attend devant un écran de chargement) : 25 s et 2 essais au lieu de 90 s et 6
  Future<Uint8List> _bytes(Uri u, {bool rapide = false}) async {
    Object? last;
    final essais = rapide ? 2 : 6, delai = Duration(seconds: rapide ? 25 : 90);
    for (var attempt = 0; attempt < essais; attempt++) {
      try {
        final r = await _gate(() => http.get(u).timeout(delai));
        if (r.statusCode == 429 || r.statusCode == 503 || r.statusCode == 502) {
          _cap = 2;
          _minGap = 400;
          _gapMs = _gapMs < 400 ? 800 : (_gapMs * 2 > 4000 ? 4000 : _gapMs * 2);
          last = XtreamError('Le serveur répond ${r.statusCode} (trop de requêtes), nouvelle tentative…');
          final ra = int.tryParse(r.headers['retry-after'] ?? '') ?? 0;
          await Future<void>.delayed(Duration(seconds: ra > 0 && ra < 60 ? ra : 6 * (attempt + 1)));
          continue;
        }
        if (r.statusCode == 401 || r.statusCode == 403) throw XtreamError('Identifiants refusés par le fournisseur (code ${r.statusCode}).');
        if (r.statusCode == 404) throw XtreamError('Adresse introuvable chez le fournisseur (404) : vérifie l\'adresse du serveur.');
        if (r.statusCode == 509) throw XtreamError('Trop de connexions en même temps sur ton abonnement : ferme la lecture sur un autre appareil.');
        if (r.statusCode != 200) throw XtreamError('Le serveur répond ${r.statusCode}.');
        if (_gapMs > _minGap) _gapMs = _gapMs - 100 < _minGap ? _minGap : _gapMs - 100;
        return r.bodyBytes;
      } on XtreamError {
        rethrow;
      } catch (e) {
        last = e;
        await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    if (last is XtreamError) throw last;
    if (last is TimeoutException) throw XtreamError('Le serveur ne répond pas (délai dépassé) : vérifie l\'adresse, ta connexion, et qu\'aucun autre appareil n\'utilise déjà l\'abonnement.');
    throw XtreamError('Serveur injoignable : vérifie l\'adresse du serveur et ta connexion Internet.');
  }

  // ---- source « playlist M3U » : même interface que Xtream, les flux sont des adresses directes (portées par Item.ext)
  Map<int, Map<String, List<Item>>>? _pl;
  String _plEpg = '';

  Future<void> _loadPl() async {
    if (_pl != null) return;
    final u = Uri.tryParse(c.server.trim());
    if (u == null || !u.hasScheme) throw XtreamError('Adresse de la playlist invalide.');
    final b = await _bytes(u);
    final r = await compute(parseM3u, b);
    if (r == null) throw XtreamError('Ce n\'est pas une playlist M3U lisible.');
    _pl = r.$1;
    _plEpg = r.$2;
  }

  Future<dynamic> _get(Uri u, {bool rapide = false}) async {
    final b = await _bytes(u, rapide: rapide);
    try {
      return jsonDecode(utf8.decode(b));
    } catch (_) {
      throw XtreamError('Réponse illisible du serveur.');
    }
  }

  /// vérifie les identifiants ; mémorise l'adresse des flux (parfois différente de celle de l'API)
  bool _authed = false;
  int _srvOff = 0;
  Map<String, String> info = const {};      // état du compte chez le fournisseur (statut, connexions)
  String _authMsg = '';
  Future<String> authenticate() async {
    if (_authed) return _authMsg;
    if (c.isM3u) {
      await _loadPl();
      _authed = true;
      return _authMsg = 'playlist M3U';
    }
    final d = await _get(_api(null), rapide: true);
    if (d is! Map || d['user_info'] is! Map || '${(d['user_info'] as Map)['auth']}' != '1') {
      throw XtreamError('Identifiants refusés par le fournisseur.');
    }
    final si = d['server_info'];
    if (si is Map) {
      // heure du serveur : le rattrapage (timeshift) se demande en heure locale du serveur
      final ts = int.tryParse('${si['timestamp_now']}'), tn = DateTime.tryParse('${si['time_now']}'.replaceFirst(' ', 'T'));
      if (ts != null && tn != null) _srvOff = DateTime.utc(tn.year, tn.month, tn.day, tn.hour, tn.minute, tn.second).millisecondsSinceEpoch ~/ 1000 - ts;
    }
    if (si is Map && '${si['url']}'.isNotEmpty && si['url'] != null) {
      final proto = '${si['server_protocol'] ?? 'http'}';
      final port = '${si['port'] ?? ''}';
      final portPart = (port.isEmpty || (port == '80' && proto == 'http')) ? '' : ':$port';
      _streamBase = '$proto://${si['url']}$portPart';
    }
    final ui = d['user_info'] as Map;
    info = {'status': '${ui['status'] ?? ''}', 'max': '${ui['max_connections'] ?? ''}', 'active': '${ui['active_cons'] ?? ''}'};
    final exp = int.tryParse('${ui['exp_date']}');
    _authed = true;
    return _authMsg = exp == null ? 'abonnement sans date de fin' : 'abonnement jusqu\'au ${DateTime.fromMillisecondsSinceEpoch(exp * 1000).toLocal().toString().substring(0, 10)}';
  }

  /// programmes en cours et à venir d'UNE chaîne (quelques lignes, pas de guide complet) : [début, fin, titre] en secondes
  Future<List<List<Object>>> shortEpg(int sid) async {
    if (c.isM3u) return const [];
    final d = await _get(_api('get_short_epg', {'stream_id': '$sid', 'limit': '3'}));
    final l = d is Map ? d['epg_listings'] : null;
    if (l is! List) return const [];
    String title(dynamic t) {
      final raw = '$t';
      try {
        return utf8.decode(base64.decode(base64.normalize(raw)), allowMalformed: true).trim();
      } catch (_) {
        return raw.trim();
      }
    }
    final out = <List<Object>>[];
    for (final e in l) {
      if (e is! Map) continue;
      final a = int.tryParse('${e['start_timestamp']}'), z = int.tryParse('${e['stop_timestamp']}');
      if (a == null || z == null || z <= a) continue;
      out.add([a, z, title(e['title'])]);
    }
    return out;
  }

  /// guide des programmes (XMLTV) du fournisseur
  Future<Uint8List> xmltv() async {
    if (c.isM3u) {
      await _loadPl();
      if (_plEpg.isEmpty) throw XtreamError('pas de guide dans cette playlist');
      return _bytes(Uri.parse(_plEpg));
    }
    final u = Uri.parse('${c.base}/xmltv.php').replace(queryParameters: {'username': c.user, 'password': c.pass});
    final cl = http.Client();
    try {
      final r = await _gate(() => cl.send(http.Request('GET', u)).timeout(const Duration(seconds: 120)));
      if (r.statusCode != 200) throw XtreamError('guide ${r.statusCode}');
      // petite télé : un guide trop gros (des dizaines de Mo à décoder) ferait manquer de mémoire ; on s'en passe plutôt que de planter
      final max = Perf.lite ? 14 * 1024 * 1024 : 120 * 1024 * 1024;
      if ((r.contentLength ?? 0) > max) throw XtreamError('guide trop volumineux');
      final b = BytesBuilder(copy: false);
      var n = 0;
      await for (final p in r.stream.timeout(const Duration(seconds: 120))) {
        n += p.length;
        if (n > max) throw XtreamError('guide trop volumineux');
        b.add(p);
      }
      return b.takeBytes();
    } finally {
      cl.close();
    }
  }

  Future<List<Cat>> categories(Kind k) async {
    if (c.isM3u) {
      await _loadPl();
      return [for (final g in (_pl![k.index] ?? const <String, List<Item>>{}).keys) Cat(g, g)];
    }
    final d = await _get(_api(k.catAction), rapide: true);
    if (d is! List) return [];
    return [for (final x in d) if (x is Map) Cat('${x['category_id']}', '${x['category_name']}'.trim())];
  }

  /// une seule catégorie (le reste du catalogue n'est jamais téléchargé) : éléments + copie compacte pour le cache disque.
  /// Lecture du JSON hors du fil de l'interface (les grosses catégories font plusieurs Mo).
  Future<(List<Item>, String)> category(Kind k, String cid) async {
    if (c.isM3u) {
      await _loadPl();
      final l = _pl![k.index]?[cid] ?? <Item>[];
      return (l, jsonEncode([for (final i in l) i.toJson()]));
    }
    final b = await _bytes(_api(k.listAction, {'category_id': cid}));
    final r = await compute(parseStreams, (k, cid, b));
    if (r == null) throw XtreamError('Réponse illisible du serveur.');
    return r;
  }

  static final _bulkKo = <Kind>{};      // types dont le chargement groupé a échoué ou était trop gros : on ne réessaie pas pendant cette session
  static int get _bulkMax => Perf.lite ? 6 * 1024 * 1024 : 25 * 1024 * 1024;     // petite télé : on évite de décoder une énorme réponse en mémoire

  /// toutes les catégories voulues d'un type en UNE requête (bien plus rapide que 100+ requêtes) ; null si indisponible
  /// (réponse trop grosse, serveur qui refuse…) : l'appelant retombe alors sur le chargement catégorie par catégorie.
  Future<Map<String, (List<Item>, String)>?> bulk(Kind k, Set<String> want) async {
    if (c.isM3u || _bulkKo.contains(k) || want.isEmpty) return null;
    final cl = http.Client();
    try {
      final resp = await _gate(() => cl.send(http.Request('GET', _api(k.listAction))).timeout(const Duration(seconds: 60)));
      if (resp.statusCode == 200) {
        // pas de limite de taille : la réponse est décodée par morceaux d'environ 1 Mo (mémoire bornée, utile surtout sur petite télé)
        final by = <String, List<Item>>{};
        final sw = Stopwatch()..start();
        var pend = BytesBuilder(copy: false), seen = 0, bytes = 0;
        Future<bool> flush() async {
          final (m, rest, n) = await compute(scanBulk, (k, want, pend.takeBytes()));
          for (final e in m.entries) {
            (by[e.key] ??= []).addAll(e.value);
          }
          seen += n;
          pend = BytesBuilder(copy: false)..add(rest);
          return rest.length < 4 * 1024 * 1024;
        }

        await for (final part in resp.stream.timeout(const Duration(seconds: 60))) {
          pend.add(part);
          bytes += part.length;
          if (pend.length >= 1024 * 1024 && !await flush()) {
            _bulkKo.add(k);
            return null;
          }
        }
        if (pend.length > 0) await flush();
        if (seen == 0) {
          _bulkKo.add(k);
          return null;
        }
        final out = await compute(encodeBulk, by);
        Journal.add('Catalogue ${k.name}', 'groupé : ${(bytes / 1048576).toStringAsFixed(1)} Mo, $seen éléments, ${out.length} catégories, ${sw.elapsed.inSeconds} s');
        return out;
      }
      if (resp.statusCode != 200 || (resp.contentLength ?? 0) > _bulkMax) {
        _bulkKo.add(k);
        return null;
      }
      final buf = BytesBuilder(copy: false);
      var n = 0;
      await for (final part in resp.stream.timeout(const Duration(seconds: 60))) {
        n += part.length;
        if (n > _bulkMax) {
          _bulkKo.add(k);
          return null;
        }
        buf.add(part);
      }
      final r = await compute(parseBulk, (k, want, buf.takeBytes()));
      if (r == null) _bulkKo.add(k);
      return r;
    } catch (e) {
      Journal.add('Catalogue ${k.name} : chargement groupé impossible, repli catégorie par catégorie', e);
      _bulkKo.add(k);
      return null;
    } finally {
      cl.close();
    }
  }

  String _first(dynamic v) => v is List && v.isNotEmpty ? '${v.first}' : (v is String ? v : '');

  Future<Detail> vodDetail(int id) async {
    if (c.isM3u) return const Detail();
    final d = await _get(_api('get_vod_info', {'vod_id': '$id'}));
    final i = d is Map && d['info'] is Map ? d['info'] as Map : const {};
    return Detail(
      plot: '${i['plot'] ?? i['description'] ?? ''}',
      genre: '${i['genre'] ?? ''}',
      backdrop: _first(i['backdrop_path']),
      duration: '${i['duration'] ?? ''}',
      year: '${i['releasedate'] ?? i['releaseDate'] ?? ''}'.split('-').first,
      cast: '${i['cast'] ?? i['actors'] ?? ''}',
      director: '${i['director'] ?? ''}',
    );
  }

  Future<(Detail, List<Episode>)> seriesDetail(int id) async {
    final d = await _get(_api('get_series_info', {'series_id': '$id'}));
    final i = d is Map && d['info'] is Map ? d['info'] as Map : const {};
    final out = <Episode>[];
    if (d is Map && d['episodes'] is Map) {
      (d['episodes'] as Map).forEach((season, list) {
        if (list is! List) return;
        for (final e in list) {
          if (e is! Map) continue;
          final eid = int.tryParse('${e['id']}');
          if (eid == null) continue;
          out.add(Episode(eid, '${e['title'] ?? ''}', '${e['container_extension'] ?? 'mp4'}', int.tryParse('$season') ?? 0, int.tryParse('${e['episode_num']}') ?? 0));
        }
      });
    }
    out.sort((a, b) => a.season != b.season ? a.season - b.season : a.number - b.number);
    return (
      Detail(plot: '${i['plot'] ?? ''}', genre: '${i['genre'] ?? ''}', backdrop: _first(i['backdrop_path']), year: '${i['releaseDate'] ?? i['releasedate'] ?? ''}'.split('-').first, cast: '${i['cast'] ?? ''}', director: '${i['director'] ?? ''}'),
      out,
    );
  }

  Future<List<Episode>> episodes(int seriesId) async {
    final d = await _get(_api('get_series_info', {'series_id': '$seriesId'}));
    final out = <Episode>[];
    if (d is Map && d['episodes'] is Map) {
      (d['episodes'] as Map).forEach((season, list) {
        if (list is! List) return;
        for (final e in list) {
          if (e is! Map) continue;
          final id = int.tryParse('${e['id']}');
          if (id == null) continue;
          out.add(Episode(id, '${e['title'] ?? ''}', '${e['container_extension'] ?? 'mp4'}', int.tryParse('$season') ?? 0, int.tryParse('${e['episode_num']}') ?? 0));
        }
      });
    }
    out.sort((a, b) => a.season != b.season ? a.season - b.season : a.number - b.number);
    return out;
  }

  /// rattrapage : relecture d'un programme passé (début / fin en secondes)
  String timeshiftUrl(int id, int start, int stop) {
    final t = DateTime.fromMillisecondsSinceEpoch((start + _srvOff) * 1000, isUtc: true);
    String two(int v) => v.toString().padLeft(2, '0');
    final mins = ((stop - start) / 60).ceil() + 30;
    return '$_streamBase/timeshift/${c.user}/${c.pass}/$mins/${t.year}-${two(t.month)}-${two(t.day)}:${two(t.hour)}-${two(t.minute)}/$id.ts';
  }

  /// adresse d'un flux direct : portée par l'élément pour une playlist M3U
  String liveUrlOf(Item i) => c.isM3u ? i.ext : liveUrl(i.id);
  String liveUrl(int id) => '$_streamBase/live/${c.user}/${c.pass}/$id.m3u8';
  String vodUrl(int id, String ext) => ext.startsWith('http') ? ext : '$_streamBase/movie/${c.user}/${c.pass}/$id.$ext';
  String episodeUrl(int id, String ext) => ext.startsWith('http') ? ext : '$_streamBase/series/${c.user}/${c.pass}/$id.$ext';
}

/// liste d'une catégorie → éléments + JSON compact (appelé dans un isolat) ; null si la réponse est illisible
(List<Item>, String)? parseStreams((Kind, String, Uint8List) a) {
  final (k, cid, bytes) = a;
  Object? d;
  try {
    d = jsonDecode(utf8.decode(bytes, allowMalformed: true));
  } catch (_) {
    return null;
  }
  if (d is! List) return d is Map && d.isEmpty ? (<Item>[], '[]') : null;
  final out = <Item>[];
  for (final x in d) {
    if (x is! Map) continue;
    // certains fournisseurs ignorent le filtre : on garde seulement la catégorie demandée (si l'élément la précise)
    final own = x['category_id'];
    final many = x['category_ids'];
    if (own != null && '$own'.isNotEmpty && '$own' != 'null' && '$own' != cid) {
      if (!(many is List && many.map((e) => '$e').contains(cid))) continue;
    }
    final id = int.tryParse('${k == Kind.series ? x['series_id'] : x['stream_id']}');
    if (id == null) continue;
    final icon = '${(k == Kind.series ? x['cover'] : x['stream_icon']) ?? ''}';
    final r5 = double.tryParse('${x['rating_5based'] ?? ''}');
    final r = r5 != null && r5 > 0 ? r5 * 2 : (double.tryParse('${x['rating'] ?? ''}') ?? 0);
    final added = int.tryParse('${x['added'] ?? x['last_modified'] ?? 0}') ?? 0;
    out.add(Item(id, '${x['name']}'.trim(), icon, '${x['container_extension'] ?? (k == Kind.live ? 'm3u8' : 'mp4')}', cid, k, rating: r.isFinite ? r : 0.0, added: added, epg: '${x['epg_channel_id'] ?? ''}'.trim().toLowerCase(), arch: '${x['tv_archive']}' == '1' ? (int.tryParse('${x['tv_archive_duration']}') ?? 0) : 0));
  }
  return (out, jsonEncode([for (final i in out) i.toJson()]));
}

/// réponse « tout le catalogue » d'un type → éléments rangés par catégorie voulue (appelé dans un isolat) ; null si illisible
Map<String, (List<Item>, String)>? parseBulk((Kind, Set<String>, Uint8List) a) {
  final (k, want, bytes) = a;
  Object? d;
  try {
    d = jsonDecode(utf8.decode(bytes, allowMalformed: true));
  } catch (_) {
    return null;
  }
  if (d is! List || d.isEmpty) return null;
  final by = <String, List<Item>>{};
  for (final x in d) {
    if (x is Map) _bulkAdd(k, x, want, by);
  }
  return {for (final e in by.entries) e.key: (e.value, jsonEncode([for (final i in e.value) i.toJson()]))};
}

void _bulkAdd(Kind k, Map x, Set<String> want, Map<String, List<Item>> by) {
  final cids = <String>{'${x['category_id']}', if (x['category_ids'] is List) for (final e in x['category_ids'] as List) '$e'}..retainAll(want);
  if (cids.isEmpty) return;
  final id = int.tryParse('${k == Kind.series ? x['series_id'] : x['stream_id']}');
  if (id == null) return;
  final icon = '${(k == Kind.series ? x['cover'] : x['stream_icon']) ?? ''}';
  final r5 = double.tryParse('${x['rating_5based'] ?? ''}');
  final r = r5 != null && r5 > 0 ? r5 * 2 : (double.tryParse('${x['rating'] ?? ''}') ?? 0);
  final added = int.tryParse('${x['added'] ?? x['last_modified'] ?? 0}') ?? 0;
  for (final cid in cids) {
    (by[cid] ??= []).add(Item(id, '${x['name']}'.trim(), icon, '${x['container_extension'] ?? (k == Kind.live ? 'm3u8' : 'mp4')}', cid, k, rating: r.isFinite ? r : 0.0, added: added, epg: '${x['epg_channel_id'] ?? ''}'.trim().toLowerCase(), arch: '${x['tv_archive']}' == '1' ? (int.tryParse('${x['tv_archive_duration']}') ?? 0) : 0));
  }
}

/// lecture « au fil de l'eau » (petite télé) : décode les objets complets d'un morceau de la réponse et rend le reste (objet coupé) à rejoindre au morceau suivant.
/// La mémoire reste bornée à la taille d'un morceau, quelle que soit la taille du catalogue (appelé dans un isolat).
(Map<String, List<Item>>, Uint8List, int) scanBulk((Kind, Set<String>, Uint8List) a) {
  final (k, want, b) = a;
  final by = <String, List<Item>>{};
  var depth = 0, start = -1, n = 0, keep = b.length;
  var inStr = false, esc = false;
  for (var i = 0; i < b.length; i++) {
    final ch = b[i];
    if (inStr) {
      if (esc) {
        esc = false;
      } else if (ch == 0x5C) {
        esc = true;
      } else if (ch == 0x22) {
        inStr = false;
      }
      continue;
    }
    if (ch == 0x22) {
      inStr = true;
    } else if (ch == 0x7B) {
      if (depth++ == 0) start = i;
    } else if (ch == 0x7D && depth > 0 && --depth == 0) {
      try {
        final x = jsonDecode(utf8.decode(Uint8List.sublistView(b, start, i + 1), allowMalformed: true));
        if (x is Map) {
          n++;
          _bulkAdd(k, x, want, by);
        }
      } catch (_) {}
      start = -1;
    }
  }
  if (depth > 0 && start >= 0) {
    keep = start;
  } else {
    keep = b.length;
  }
  return (by, Uint8List.fromList(Uint8List.sublistView(b, keep)), n);
}

Map<String, (List<Item>, String)> encodeBulk(Map<String, List<Item>> by) => {for (final e in by.entries) e.key: (e.value, jsonEncode([for (final i in e.value) i.toJson()]))};

/// playlist M3U → éléments par type puis par groupe (appelé dans un isolat) + adresse du guide ; null si ce n'est pas une playlist
(Map<int, Map<String, List<Item>>>, String)? parseM3u(Uint8List bytes) {
  final txt = utf8.decode(bytes, allowMalformed: true);
  if (!txt.contains('#EXTM3U') && !txt.contains('#EXTINF')) return null;
  final out = <int, Map<String, List<Item>>>{};
  final attr = RegExp(r'([A-Za-z][\w-]*)="([^"]*)"');
  final head = RegExp(r'#EXTM3U[^\n]*').firstMatch(txt)?.group(0) ?? '';
  var epg = '';
  for (final m in attr.allMatches(head)) {
    if (m.group(1)!.toLowerCase() == 'url-tvg' || m.group(1)!.toLowerCase() == 'x-tvg-url') epg = m.group(2)!.split(',').first.trim();
  }
  Map<String, String>? cur;
  var name = '';
  for (final raw in const LineSplitter().convert(txt)) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTINF')) {
      cur = {for (final m in attr.allMatches(line)) m.group(1)!.toLowerCase(): m.group(2)!};
      final i = line.lastIndexOf(',');
      name = i >= 0 ? line.substring(i + 1).trim() : '';
      if (name.isEmpty) name = cur['tvg-name'] ?? '';
      continue;
    }
    if (line.startsWith('#')) continue;
    if (cur == null) continue;
    final low = line.toLowerCase();
    final isVod = low.contains('/movie/') || low.contains('/series/') || low.endsWith('.mp4') || low.endsWith('.mkv') || low.endsWith('.avi');
    final k = isVod ? Kind.vod : Kind.live;
    var h = 0x811c9dc5;
    for (final u in line.codeUnits) {
      h = ((h ^ u) * 0x01000193) & 0x7fffffff;
    }
    final g = (cur['group-title'] ?? '').trim().isEmpty ? 'Sans groupe' : cur['group-title']!.trim();
    (out[k.index] ??= {}).putIfAbsent(g, () => []).add(Item(h, name.isEmpty ? line : name, cur['tvg-logo'] ?? '', line, g, k, epg: (cur['tvg-id'] ?? '').trim().toLowerCase()));
    cur = null;
  }
  return out.isEmpty ? null : (out, epg);
}

/// catégories françaises d'après leur nom (pré-cochage proposé, modifiable)
final _frRx = RegExp(r'(^|[^a-z])(fr|fra|france|francais|français|french|vf|vff|vostfr|truefrench)([^a-z]|$)', caseSensitive: false);
bool looksFrench(String name) => _frRx.hasMatch(name);

/// pré-cochage resserré : français, sans les rayons rarement regardés (VOSTFR, caméra, vieilles années, décalé, outre-mer, adultes)
bool suggested(Kind k, String name) {
  final n = norm(catLabel(name));
  if (RegExp(r'adult|xxx|\+18|18\+|porn|erotique').hasMatch(n)) return false;
  if (k == Kind.live) {
    final th = liveThemeOf(name);
    if (th == 'sport' && !kStore) return true;     // version store : pas de pré-cochage d'après les noms de chaînes payantes
    return looksFrench(name) && !const {'delay', 'outremer', 'bouquets', 'autres'}.contains(th);
  }
  if (!looksFrench(name) || RegExp(r'vostfr|vost|\bcam\b|\bts\b').hasMatch(n)) return false;
  final y = yearOfCat(n);
  return y == 0 || y >= DateTime.now().year - 3;
}
