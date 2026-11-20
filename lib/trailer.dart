import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'dart:io';

import 'package:http/http.dart' as http;

import 'journal.dart';

/// petit relais local : le lecteur (libmpv Android) n'arrive pas à ouvrir les adresses https de YouTube, l'appli les récupère elle-même
/// (avec l'agent HTTP exigé) et les lui sert en http sur 127.0.0.1, plage d'octets comprise
class _Relay {
  static HttpServer? _srv;
  static final _targets = <String, (String, String)>{};
  static final _client = http.Client();

  static Future<String> serve(String key, String url, String ua) async {
    _targets[key] = (url, ua);
    _srv ??= await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((req) async {
        Journal.add('Bande-annonce : relais reçoit', '${req.method} ${req.uri.path}');
        final t = _targets[req.uri.path.substring(1)];
        if (t == null) {
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }
        try {
          // YouTube refuse les demandes sans borne (« bytes=0- ») : on lit par tranches de 6 Mo et on les enchaîne vers le lecteur
          const chunk = 6 * 1024 * 1024;
          final m = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(req.headers.value('range') ?? '');
          final start = int.tryParse(m?.group(1) ?? '') ?? 0;
          final wantEnd = int.tryParse(m?.group(2) ?? '');
          Future<http.StreamedResponse> tranche(int from) {
            final r = http.Request('GET', Uri.parse(t.$1))
              ..headers['User-Agent'] = t.$2
              ..headers['Range'] = 'bytes=$from-${from + chunk - 1}';
            return _client.send(r).timeout(const Duration(seconds: 20));
          }

          var up = await tranche(start);
          final total = int.tryParse(RegExp(r'/(\d+)$').firstMatch(up.headers['content-range'] ?? '')?.group(1) ?? '') ?? (start + (up.contentLength ?? 0));
          final end = wantEnd == null || wantEnd >= total ? total - 1 : wantEnd;
          final res = req.response;
          res.statusCode = m == null ? 200 : 206;
          res.headers.set('content-type', up.headers['content-type'] ?? 'application/octet-stream');
          res.headers.set('accept-ranges', 'bytes');
          res.headers.set('content-length', '${end - start + 1}');
          if (m != null) res.headers.set('content-range', 'bytes $start-$end/$total');
          Journal.add('Bande-annonce : relais ${req.method} ${req.uri.path}', 'octets $start-$end/$total, amont HTTP ${up.statusCode}');
          if (req.method == 'HEAD' || up.statusCode >= 400) {
            if (up.statusCode >= 400) res.statusCode = up.statusCode;
            await res.close();
            return;
          }
          var pos = start;
          while (true) {
            await for (final b in up.stream) {
              if (pos + b.length > end + 1) {
                res.add(b.sublist(0, end + 1 - pos));
                pos = end + 1;
                break;
              }
              res.add(b);
              pos += b.length;
            }
            if (pos > end) break;
            up = await tranche(pos);
            if (up.statusCode >= 400) break;
          }
          await res.close();
        } catch (e) {
          Journal.add('Bande-annonce : relais', e);
          try {
            req.response.statusCode = 502;
            await req.response.close();
          } catch (_) {}
        }
      });
    return 'http://127.0.0.1:${_srv!.port}/$key';
  }
}

/// bande-annonce lue dans le lecteur de l'appli : adresse du flux YouTube (image, et son à part si besoin)
class Trailer {
  /// (image, son) ; son nul quand le flux contient déjà les deux. Nul si YouTube ne donne rien (l'appelant ouvre alors la page web).
  static Future<(String, String?, String)?> resolve(String id) async {
    final yt = YoutubeExplode();
    try {
      final client = YoutubeApiClient.androidSdkless;
      final ua = client.payload['context']['client']['userAgent'] as String;      // les adresses YouTube ne se lisent qu'avec le même agent que celui qui les a demandées
      final m = await yt.videos.streamsClient.getManifest(id, ytClients: [client]).timeout(const Duration(seconds: 25));
      // image H.264 jusqu'en 1080p + son AAC : bien plus net que le flux « tout en un » (360p)
      final v = m.videoOnly.where((s) => s.container == StreamContainer.mp4 && s.videoResolution.height <= 1080).toList()
        ..sort((a, b) => a.videoResolution.height.compareTo(b.videoResolution.height));
      final a = m.audioOnly.where((s) => s.container == StreamContainer.mp4).toList();
      if (v.isNotEmpty) {
        try {
          final r = await http.get(Uri.parse(v.last.url.toString()), headers: {'User-Agent': ua, 'Range': 'bytes=0-1'}).timeout(const Duration(seconds: 10));
          Journal.add('Bande-annonce : essai du flux image ${v.last.videoResolution.height}p', 'HTTP ${r.statusCode}');
        } catch (e) {
          Journal.add('Bande-annonce : essai du flux image', e);
        }
      }
      if (v.isNotEmpty && a.isNotEmpty) return (await _Relay.serve('v', v.last.url.toString(), ua), await _Relay.serve('a', a.withHighestBitrate().url.toString(), ua), ua);
      if (m.muxed.isNotEmpty) return (await _Relay.serve('v', m.muxed.withHighestBitrate().url.toString(), ua), null, ua);
    } catch (e) {
      Journal.add('Bande-annonce : flux YouTube non obtenu', e);
    } finally {
      yt.close();
    }
    return null;
  }
}
