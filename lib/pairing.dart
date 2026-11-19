import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'auth.dart';
import 'keys.dart';
import 'store.dart';

/// connecter une télé depuis un téléphone déjà connecté : code court, paquet chiffré avec ce code, supprimé dès lu
class Pairing {
  /// dernier incident visible à l'écran de la télé (vide = rien à signaler)
  static String last = '';
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
      await clear(code);      // un ancien paquet du même code (essai précédent) est remplacé
      final r = await http.post(Uri.parse('$kSbUrl/rest/v1/pairing'), headers: _h(code), body: jsonEncode({'code': code, 'payload': base64Encode(box.concatenation())})).timeout(const Duration(seconds: 12));
      return r.statusCode < 300 ? null : 'Envoi impossible : le serveur répond ${r.statusCode}.';
    } catch (_) {
      return 'Connexion au serveur impossible depuis le téléphone.';
    }
  }

  /// télé : efface le paquet une fois la connexion réussie
  static Future<void> clear(String code) async {
    try {
      await http.delete(Uri.parse('$kSbUrl/rest/v1/pairing?code=eq.$code'), headers: _h(code)).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// télé : cherche un paquet pour ce code ; {e, p, c} ou null
  static Future<Map<String, dynamic>?> poll(String code) async {
    try {
      final r = await http.get(Uri.parse('$kSbUrl/rest/v1/pairing?select=payload&code=eq.$code'), headers: _h(code)).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) {
        last = 'Serveur : réponse ${r.statusCode}';
        return null;
      }
      last = '';
      final rows = jsonDecode(r.body) as List;
      if (rows.isEmpty) return null;
      final box = SecretBox.fromConcatenation(base64Decode('${rows.first['payload']}'), nonceLength: 12, macLength: 16);
      final m = jsonDecode(utf8.decode(await AesGcm.with256bits().decrypt(box, secretKey: await _key(code)))) as Map<String, dynamic>;
      final t = (m['t'] as num?)?.toInt() ?? 0;
      if ((DateTime.now().millisecondsSinceEpoch - t).abs() > 15 * 60 * 1000) {
        last = 'Heure incorrecte sur la télé ou le téléphone (écart de plus de 15 min) : vérifie la date et l\'heure';
        return null;      // paquet périmé : ignoré
      }
      return m;
    } on FormatException {
      last = 'Code illisible : relance la connexion sur le téléphone';
      return null;
    } catch (_) {
      last = 'Connexion au serveur impossible depuis la télé';
      return null;
    }
  }
}
