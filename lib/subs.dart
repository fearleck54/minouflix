import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'keys.dart';

/// sous-titres trouvés en ligne (SubDL) : le fichier est téléchargé à la demande
class SubHit {
  final String name, lang, url;
  const SubHit(this.name, this.lang, this.url);
}

class Subs {
  /// la recherche n'existe que si une clé SubDL a été fournie à la compilation (--dart-define=SUBDL_KEY=…)
  static bool get available => kSubsKey.isNotEmpty;

  /// `tmdbId` si on le connaît (résultat exact), sinon le titre ; saison et épisode pour les séries
  static Future<List<SubHit>> search({required String title, int tmdbId = 0, String lang = 'FR', bool tv = false, int season = 0, int episode = 0}) async {
    final q = <String, String>{'api_key': kSubsKey, 'languages': lang, 'subs_per_page': '20', 'type': tv ? 'tv' : 'movie'};
    if (tmdbId > 0) {
      q['tmdb_id'] = '$tmdbId';
    } else {
      q['film_name'] = title;
    }
    if (tv && season > 0) q['season_number'] = '$season';
    if (tv && episode > 0) q['episode_number'] = '$episode';
    final r = await http.get(Uri.https('api.subdl.com', '/api/v1/subtitles', q)).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('SubDL ${r.statusCode}');
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    final l = j is Map ? j['subtitles'] as List? : null;
    return [
      for (final x in l ?? const [])
        if (x is Map && '${x['url']}'.isNotEmpty) SubHit('${x['release_name'] ?? x['name'] ?? 'Sous-titres'}', '${x['lang'] ?? lang}', '${x['url']}'),
    ];
  }

  /// télécharge l'archive et renvoie le texte du premier fichier .srt (ou .vtt / .ass) trouvé
  static Future<String?> fetch(SubHit h) async {
    final u = h.url.startsWith('http') ? h.url : 'https://dl.subdl.com${h.url}';
    final r = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw Exception('SubDL ${r.statusCode}');
    final z = ZipDecoder().decodeBytes(r.bodyBytes);
    for (final ext in ['.srt', '.vtt', '.ass']) {
      for (final f in z) {
        if (f.isFile && f.name.toLowerCase().endsWith(ext)) return utf8.decode(f.content as List<int>, allowMalformed: true);
      }
    }
    return null;
  }
}
