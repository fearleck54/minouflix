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
        final t = _targets[req.uri.path.substring(1)];
        if (t == null) {
          req.response.statusCode = 404;
          await req.response.close();
          return;
        }
        try {
          final r = http.Request(req.method == 'HEAD' ? 'GET' : req.method, Uri.parse(t.$1))..headers['User-Agent'] = t.$2;
          final range = req.headers.value('range');
          if (range != null) r.headers['Range'] = range;
          final up = await _client.send(r).timeout(const Duration(seconds: 20));
          req.response.statusCode = up.statusCode;
          for (final h in ['content-type', 'content-length', 'content-range', 'accept-ranges']) {
            final v = up.headers[h];
            if (v != null) req.response.headers.set(h, v);
          }
          if (req.method == 'HEAD') {
            await req.response.close();
            return;
          }
          await req.response.addStream(up.stream);
          await req.response.close();
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
