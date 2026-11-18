import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// adresse réduite au serveur (ni chemin, ni paramètres, ni « user:pass@ ») : les flux Xtream portent les identifiants dans l'URL
String scrub(String s) {
  var t = s.replaceAllMapped(RegExp(r'([a-zA-Z][a-zA-Z0-9+.-]*://)(?:[^\s/@"]*@)?([^\s/?#"]+)[^\s"]*'), (m) => '${m.group(1)}${m.group(2)}/…');
  t = t.replaceAllMapped(RegExp(r'(username|password|user|pass|token|apikey|access_token|refresh_token)=[^&\s"]*', caseSensitive: false), (m) => '${m.group(1)}=…');
  t = t.replaceAll(RegExp(r'eyJ[A-Za-z0-9_-]{10,}(?:\.[A-Za-z0-9_-]+){0,2}'), 'jeton…');
  t = t.replaceAll(RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'), 'e-mail…');
  return t;
}

/// journal d'erreurs local (fichier sur l'appareil, jamais envoyé) : « Réglages > À propos > Voir le journal »
class Journal {
  static File? _f;
  static final _mem = <String>[];     // avant l'ouverture du fichier (ou sur le web)
  static Future<void> _w = Future.value();

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      _f = File('${(await getApplicationSupportDirectory()).path}/journal.txt');
      // plafond : au-delà de 200 Ko on ne garde que la fin
      if (await _f!.exists() && await _f!.length() > 200 * 1024) {
        final s = await _f!.readAsString();
        await _f!.writeAsString(s.substring(s.length > 100 * 1024 ? s.length - 100 * 1024 : 0), flush: true);
      }
      if (_mem.isNotEmpty) {
        await _f!.writeAsString(_mem.join(), mode: FileMode.append, flush: true);
        _mem.clear();
      }
    } catch (_) {
      _f = null;
    }
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// une ligne datée, identifiants retirés ; ne lève jamais d'erreur
  static void add(String what, [Object? err, StackTrace? st]) {
    try {
      final n = DateTime.now();
      final head = '${n.year}-${_two(n.month)}-${_two(n.day)} ${_two(n.hour)}:${_two(n.minute)}:${_two(n.second)}';
      var body = err == null ? what : '$what : $err';
      if (st != null) body += '\n${st.toString().split('\n').take(8).join('\n')}';
      if (body.length > 2000) body = body.substring(0, 2000);
      final line = '$head  ${scrub(body)}\n';
      final f = _f;
      if (f == null) {
        if (_mem.length < 200) _mem.add(line);
        return;
      }
      _w = _w.then((_) => f.writeAsString(line, mode: FileMode.append, flush: true)).catchError((_) => f);
    } catch (_) {}
  }

  static Future<String> read() async {
    try {
      await _w;
      final f = _f;
      final s = f != null && await f.exists() ? await f.readAsString() : _mem.join();
      return s.trim().isEmpty ? '' : s;
    } catch (_) {
      return _mem.join();
    }
  }

  static Future<void> clear() async {
    _mem.clear();
    try {
      await _w;
      final f = _f;
      if (f != null && await f.exists()) await f.writeAsString('', flush: true);
    } catch (_) {}
  }
}

/// réseau : « hors ligne » après un échec récent, levé dès qu'une requête aboutit
class Net {
  static final offline = ValueNotifier<bool>(false);
  static void fail() => offline.value = true;
  static void ok() => offline.value = false;
}
