import 'dart:async';
import 'package:cast/cast.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'journal.dart';

export 'package:cast/cast.dart' show CastDevice;

/// état de la diffusion en cours
class CastInfo {
  final String name;
  final bool playing;
  final int posMs, durMs;
  const CastInfo(this.name, this.playing, this.posMs, this.durMs);
}

/// diffusion vers une Chromecast (récepteur multimédia standard de Google) : recherche sur le réseau, lancement, pause, saut, arrêt.
/// La Chromecast lit elle-même le flux, l'appli sert de télécommande. Formats pris en charge : ceux du récepteur standard (MP4, HLS ; MKV et MPEG-TS selon l'appareil).
class CastCtl {
  static const _appId = 'CC1AD845';      // récepteur multimédia par défaut
  static final state = ValueNotifier<CastInfo?>(null);
  static CastSession? _s;
  static int _req = 0, _mediaId = 0;
  static String _name = '';

  static Future<List<CastDevice>> search() => CastDiscoveryService().search(timeout: const Duration(seconds: 4));

  static String _type(String url) {
    final u = url.toLowerCase().split('?').first;
    if (u.endsWith('.m3u8')) return 'application/x-mpegURL';
    if (u.endsWith('.mkv')) return 'video/x-matroska';
    if (u.endsWith('.ts')) return 'video/mp2t';
    if (u.endsWith('.webm')) return 'video/webm';
    return 'video/mp4';
  }

  /// lance le flux sur la Chromecast ; true quand elle a répondu qu'elle le lit
  static Future<bool> start(CastDevice d, {required String url, required String title, String poster = '', int posMs = 0, bool live = false}) async {
    await stop();
    try {
      final s = await CastSessionManager().startSession(d, const Duration(seconds: 8));
      _s = s;
      _name = d.name;
      final done = Completer<bool>();
      s.messageStream.listen((m) {
        final t = m['type'];
        if (t == 'MEDIA_STATUS') {
          final st = (m['status'] as List?)?.cast<Map>() ?? const [];
          if (st.isEmpty) return;
          final x = st.first;
          _mediaId = (x['mediaSessionId'] as num?)?.toInt() ?? _mediaId;
          final ps = '${x['playerState']}';
          final dur = (((x['media'] as Map?)?['duration'] as num?) ?? 0) * 1000;
          state.value = CastInfo(_name, ps == 'PLAYING' || ps == 'BUFFERING', ((((x['currentTime'] as num?) ?? 0) * 1000).toInt()), dur.toInt());
          if (ps == 'IDLE' && '${x['idleReason']}' == 'ERROR' && !done.isCompleted) done.complete(false);
          if ((ps == 'PLAYING' || ps == 'BUFFERING' || ps == 'PAUSED') && !done.isCompleted) done.complete(true);
          if (ps == 'IDLE' && '${x['idleReason']}' == 'FINISHED') state.value = null;
        } else if (t == 'LOAD_FAILED' || t == 'INVALID_REQUEST' || t == 'ERROR') {
          Journal.add('Chromecast : refus', '$m');
          if (!done.isCompleted) done.complete(false);
        }
      }, onDone: () {
        state.value = null;
        if (!done.isCompleted) done.complete(false);
      });
      s.stateStream.listen((st) {
        if (st == CastSessionState.connected) {
          s.sendMessage(CastSession.kNamespaceMedia, {
            'type': 'LOAD',
            'requestId': ++_req,
            'autoplay': true,
            'currentTime': posMs / 1000,
            'media': {
              'contentId': url,
              'contentType': _type(url),
              'streamType': live ? 'LIVE' : 'BUFFERED',
              'metadata': {'type': 0, 'metadataType': 0, 'title': title, if (poster.startsWith('http')) 'images': [{'url': poster}]},
            },
          });
        }
      });
      s.sendMessage(CastSession.kNamespaceReceiver, {'type': 'LAUNCH', 'appId': _appId, 'requestId': ++_req});
      final ok = await done.future.timeout(const Duration(seconds: 20), onTimeout: () => false);
      if (!ok) await stop();
      return ok;
    } catch (e) {
      Journal.add('Chromecast : échec', e);
      await stop();
      return false;
    }
  }

  static void _media(String type, [Map<String, dynamic> extra = const {}]) {
    final s = _s;
    if (s == null) return;
    s.sendMessage(CastSession.kNamespaceMedia, {'type': type, 'mediaSessionId': _mediaId, 'requestId': ++_req, ...extra});
  }

  static void play() => _media('PLAY');
  static void pause() => _media('PAUSE');
  static void seekBy(int sec) {
    final c = state.value;
    if (c == null) return;
    _media('SEEK', {'currentTime': (c.posMs / 1000 + sec).clamp(0, double.infinity)});
  }

  static Future<void> stop() async {
    final s = _s;
    _s = null;
    state.value = null;
    if (s == null) return;
    try {
      if (_mediaId != 0) s.sendMessage(CastSession.kNamespaceMedia, {'type': 'STOP', 'mediaSessionId': _mediaId, 'requestId': ++_req});      // la vidéo s'arrête sur la Chromecast
      _mediaId = 0;
      await s.flush();
      await CastSessionManager().endSession(s.sessionId);
    } catch (_) {}
  }
}
