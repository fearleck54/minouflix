import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'auth.dart';
import 'keys.dart';
import 'perf.dart';
import 'store.dart';

/// MinouFlix Connect : un appareil du même compte en commande un autre (lancer un titre sur la télé, taper une recherche au clavier du téléphone,
/// pause / ±30 s). Les commandes passent par une « boîte aux lettres » du serveur (table de jumelage) nommée d'après la clé du compte et
/// chiffrées avec cette clé : le serveur ne voit rien, et personne d'autre ne peut les lire ni les envoyer.
class Connect {
  static const _alpha = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static String? _devId;
  static bool? _tv;
  static Timer? _poll;
  static String? _seen;       // dernière boîte aux lettres vue ; null = pas encore lue (la 1re lecture n'exécute rien : jamais de commande ancienne rejouée)
  static bool _busy = false;
  static void Function(Map<String, dynamic>)? _onCmd;

  /// texte tapé sur le téléphone pour la recherche de la télé
  static final query = ValueNotifier<String>('');
  /// commande de lecture reçue (« toggle », « back », « fwd », « stop ») pour le lecteur ouvert
  static final player = ValueNotifier<String>('');
  static bool inPlayer = false;      // un lecteur est ouvert sur cet appareil

  static bool get canSend => Account.signedIn && Account.key != null;

  /// la télé (Android TV) écoute par défaut ; un téléphone seulement si l'option est activée
  static Future<bool> isTv() async {
    if (_tv != null) return _tv!;
    if (kIsWeb || !Platform.isAndroid) return _tv = false;
    try {
      _tv = (await const MethodChannel('minou/pip').invokeMethod<bool>('isTv')) ?? false;
    } catch (_) {
      _tv = false;
    }
    return _tv!;
  }

  static bool get tvNow => Device.tv;

  static Future<bool> listening() => isTv();      // seule la télé reçoit les commandes

  /// commande « lance ce titre à cette position » (titre ou épisode)
  static Map<String, dynamic> playCmd(Prog p) => {'a': 'play', 'k': p.kind, 'id': p.id, 'sid': p.sid, 'e': p.ext, 'n': p.name, 'i': p.icon, 'sn': p.sname, 'p': p.pos};

  static Future<String> _id() async {
    if (_devId != null) return _devId!;
    final p = Store.str('dev_id');
    if (p.isNotEmpty) return _devId = p;
    final r = Random.secure();
    final id = List.generate(10, (_) => _alpha[r.nextInt(_alpha.length)]).join();
    await Store.setStr('dev_id', id);
    return _devId = id;
  }

  /// nom de la boîte aux lettres : 8 caractères dérivés (à sens unique) de la clé du compte
  static Future<String?> _room([String salt = 'minouflix-connect']) async {
    final k = Account.key;
    if (k == null) return null;
    final h = await Sha256().hash([...k, ...utf8.encode(salt)]);
    return String.fromCharCodes([for (var i = 0; i < 8; i++) _alpha.codeUnitAt(h.bytes[i] % _alpha.length)]);
  }

  static Map<String, String> _h(String room) => {'apikey': kSbKey, 'x-pair': room, 'Content-Type': 'application/json'};

  /// envoie une commande à l'autre appareil ; true si le serveur l'a prise
  static Future<bool> send(Map<String, dynamic> cmd) async {
    try {
      final room = await _room();
      if (room == null) return false;
      final sealed = await Account.seal(jsonEncode({'f': await _id(), 't': DateTime.now().millisecondsSinceEpoch, 'c': cmd}));
      if (sealed == null) return false;
      await http.delete(Uri.parse('$kSbUrl/rest/v1/pairing?code=eq.$room'), headers: _h(room)).timeout(const Duration(seconds: 8));
      final r = await http.post(Uri.parse('$kSbUrl/rest/v1/pairing'), headers: _h(room), body: jsonEncode({'code': room, 'payload': sealed})).timeout(const Duration(seconds: 8));
      return r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static int _lastT = 0;

  /// « un seul écran » : l'appareil qui veut lire demande aux autres appareils du compte d'arrêter leur lecture
  static Future<bool> kick() async {
    try {
      final room = await _room('minouflix-kick');
      if (room == null) return false;
      final sealed = await Account.seal(jsonEncode({'f': await _id(), 't': DateTime.now().millisecondsSinceEpoch}));
      if (sealed == null) return false;
      await http.delete(Uri.parse('$kSbUrl/rest/v1/pairing?code=eq.$room'), headers: _h(room)).timeout(const Duration(seconds: 8));
      final r = await http.post(Uri.parse('$kSbUrl/rest/v1/pairing'), headers: _h(room), body: jsonEncode({'code': room, 'payload': sealed})).timeout(const Duration(seconds: 8));
      return r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Timer? _kt;

  /// pendant qu'un lecteur est ouvert : si un autre appareil réclame la source après `since`, `onKick` est appelé
  static void watchKick(DateTime since, void Function() onKick) {
    unwatchKick();
    if (!canSend) return;
    var busy = false;
    _kt = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (busy) return;
      busy = true;
      try {
        final room = await _room('minouflix-kick');
        if (room == null) return;
        final r = await http.get(Uri.parse('$kSbUrl/rest/v1/pairing?select=payload&code=eq.$room'), headers: _h(room)).timeout(const Duration(seconds: 6));
        if (r.statusCode != 200) return;
        final rows = jsonDecode(r.body) as List;
        if (rows.isEmpty) return;
        final m = jsonDecode(await Account.open('${rows.first['payload']}') ?? '{}') as Map<String, dynamic>;
        final t = (m['t'] as num?)?.toInt() ?? 0;
        if (m['f'] == null || m['f'] == await _id() || t <= since.millisecondsSinceEpoch || (DateTime.now().millisecondsSinceEpoch - t).abs() > 90000) return;
        unwatchKick();
        onKick();
      } catch (_) {
      } finally {
        busy = false;
      }
    });
  }

  static void unwatchKick() {
    _kt?.cancel();
    _kt = null;
  }

  static Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    try {
      final room = await _room();
      if (room == null) return;
      final r = await http.get(Uri.parse('$kSbUrl/rest/v1/pairing?select=payload&code=eq.$room'), headers: _h(room)).timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return;
      final rows = jsonDecode(r.body) as List;
      if (rows.isEmpty) {
        _seen ??= '';
        return;
      }
      final raw = '${rows.first['payload']}';
      if (_seen == null) {
        _seen = raw;
        return;
      }
      if (raw == _seen) return;
      _seen = raw;
      final s = await Account.open(raw);
      if (s == null) return;
      final m = jsonDecode(s) as Map<String, dynamic>;
      if (m['f'] == await _id()) return;
      final t = (m['t'] as num?)?.toInt() ?? 0;
      if ((DateTime.now().millisecondsSinceEpoch - t).abs() > 60000 || t <= _lastT) return;      // périmée ou rejouée
      _lastT = t;
      final c = m['c'];
      if (c is Map) _onCmd?.call(c.cast<String, dynamic>());
    } catch (_) {
    } finally {
      _busy = false;
    }
  }

  /// l'accueil écoute tant qu'il est ouvert (toutes les 2,5 s)
  static Future<void> start(void Function(Map<String, dynamic>) onCmd) async {
    stop();
    if (!canSend || !await listening()) return;
    _onCmd = onCmd;
    _seen = null;
    _poll = Timer.periodic(const Duration(milliseconds: 2500), (_) => _tick());
  }

  static void stop() {
    _poll?.cancel();
    _poll = null;
    _onCmd = null;
  }
}
