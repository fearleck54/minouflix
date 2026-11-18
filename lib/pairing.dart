import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'auth.dart';
import 'keys.dart';
import 'store.dart';

/// connecter une télé depuis un téléphone déjà connecté : code court, paquet chiffré avec ce code, supprimé dès lu
class Pairing {
  static const _alpha = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String newCode() {
    final r = Random.secure();
    return List.generate(8, (_) => _alpha[r.nextInt(_alpha.length)]).join();
  }

  static String norm(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  static String show(String c) => '${c.substring(0, 4)}-${c.substring(4)}';

  static Map<String, String> _h(String code) => {'apikey': kSbKey, 'x-pair': code, 'Content-Type': 'application/json'};

  static Future<SecretKey> _key(String code) => Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 50000, bits: 256).deriveKeyFromPassword(password: code, nonce: utf8.encode('minouflix-pair'));

  /// téléphone : envoie compte + identifiants IPTV chiffrés ; null = ok, sinon message
  static Future<String?> send(String raw) async {
    final code = norm(raw);
    if (code.length != 8) return 'Code à 8 caractères (affiché sur la télé).';
    final pw = await Account.savedPw();
    if (!Account.signedIn || pw == null) return 'Reconnecte-toi à ton compte, puis réessaie.';
    final c = await Store.creds();
    final box = await AesGcm.with256bits().encrypt(utf8.encode(jsonEncode({'e': Account.email, 'p': pw, 'c': c?.toJson(), 't': DateTime.now().millisecondsSinceEpoch})), secretKey: await _key(code));
    try {
      final r = await http.post(Uri.parse('$kSbUrl/rest/v1/pairing'), headers: _h(code), body: jsonEncode({'code': code, 'payload': base64Encode(box.concatenation())})).timeout(const Duration(seconds: 12));
      return r.statusCode < 300 ? null : 'Envoi impossible (${r.statusCode}).';
    } catch (_) {
      return 'Connexion impossible.';
    }
  }

  /// télé : cherche un paquet pour ce code ; {e, p, c} ou null
  static Future<Map<String, dynamic>?> poll(String code) async {
    try {
      final r = await http.get(Uri.parse('$kSbUrl/rest/v1/pairing?select=payload&code=eq.$code'), headers: _h(code)).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final rows = jsonDecode(r.body) as List;
      if (rows.isEmpty) return null;
      final box = SecretBox.fromConcatenation(base64Decode('${rows.first['payload']}'), nonceLength: 12, macLength: 16);
      final m = jsonDecode(utf8.decode(await AesGcm.with256bits().decrypt(box, secretKey: await _key(code)))) as Map<String, dynamic>;
      await http.delete(Uri.parse('$kSbUrl/rest/v1/pairing?code=eq.$code'), headers: _h(code)).timeout(const Duration(seconds: 10));
      final t = (m['t'] as num?)?.toInt() ?? 0;
      if ((DateTime.now().millisecondsSinceEpoch - t).abs() > 15 * 60 * 1000) return null;      // paquet périmé : ignoré
      return m;
    } catch (_) {
      return null;
    }
  }
}
