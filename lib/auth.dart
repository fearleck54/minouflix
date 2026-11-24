import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'keys.dart';

/// compte MinouFlix (Supabase Auth, e-mail + mot de passe) ; la clé de chiffrement des identifiants IPTV est dérivée du mot de passe et reste sur l'appareil
class Account {
  static const _sec = FlutterSecureStorage();
  static String access = '', refresh = '', email = '', uid = '';
  static int exp = 0;
  static List<int>? key;

  static bool get signedIn => refresh.isNotEmpty && uid.isNotEmpty;

  static Future<void> load() async {
    try {
      final s = await _sec.read(key: 'acct');
      if (s != null) {
        final m = jsonDecode(s) as Map<String, dynamic>;
        access = '${m['a']}';
        refresh = '${m['r']}';
        email = '${m['e']}';
        uid = '${m['u']}';
        exp = (m['x'] as num?)?.toInt() ?? 0;
      }
      final k = await _sec.read(key: 'acct_key');
      if (k != null) key = base64Decode(k);
    } catch (_) {}      // trousseau illisible : l'appli démarre sans compte plutôt que de rester bloquée
  }

  /// session refusée par le serveur (mot de passe changé, compte supprimé…) : à reconnecter
  static bool expired = false;

  static Future<void> _save() => _sec.write(key: 'acct', value: jsonEncode({'a': access, 'r': refresh, 'e': email, 'u': uid, 'x': exp}));

  static Map<String, String> get _h => {'apikey': kSbKey, 'Content-Type': 'application/json'};

  static String _err(http.Response r) {
    try {
      final m = jsonDecode(r.body) as Map;
      final t = '${m['msg'] ?? m['error_description'] ?? m['message'] ?? m['error'] ?? ''}'.toLowerCase();
      if (t.contains('invalid login')) return 'E-mail ou mot de passe incorrect.';
      if (t.contains('already')) return 'Un compte existe déjà avec cet e-mail : connecte-toi.';
      if (t.contains('password') && t.contains('character')) return 'Mot de passe trop court (6 caractères minimum).';
      if (t.contains('rate') || r.statusCode == 429) return 'Trop de tentatives, réessaie dans quelques minutes.';
      if (t.contains('not confirmed')) return 'Confirme d\'abord ton e-mail (lien reçu), puis connecte-toi.';
      if (t.isNotEmpty) return t;
    } catch (_) {}
    return 'Erreur ${r.statusCode}.';
  }

  /// null = connecté ; 'confirm' = e-mail de confirmation envoyé ; sinon message d'erreur
  static Future<String?> signUp(String mail, String pw) async {
    try {
      final r = await http.post(Uri.parse('$kSbUrl/auth/v1/signup'), headers: _h, body: jsonEncode({'email': mail.trim(), 'password': pw})).timeout(const Duration(seconds: 15));
      if (r.statusCode >= 300) return _err(r);
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      if (m['access_token'] == null) return 'confirm';
      await _adopt(m, pw);
      return null;
    } catch (_) {
      return 'Connexion impossible : vérifie ta connexion Internet.';
    }
  }

  static Future<String?> signIn(String mail, String pw) async {
    try {
      final r = await http.post(Uri.parse('$kSbUrl/auth/v1/token?grant_type=password'), headers: _h, body: jsonEncode({'email': mail.trim(), 'password': pw})).timeout(const Duration(seconds: 15));
      if (r.statusCode >= 300) return _err(r);
      await _adopt(jsonDecode(r.body) as Map<String, dynamic>, pw);
      return null;
    } catch (_) {
      return 'Connexion impossible : vérifie ta connexion Internet.';
    }
  }

  /// mot de passe oublié : un e-mail avec un lien est envoyé ; le lien ouvre la page web de réinitialisation (null = envoyé, sinon message d'erreur)
  static Future<String?> sendReset(String mail) async {
    try {
      final r = await http.post(Uri.parse('$kSbUrl/auth/v1/recover'), headers: _h, body: jsonEncode({'email': mail.trim()})).timeout(const Duration(seconds: 15));
      return r.statusCode >= 300 ? _err(r) : null;
    } catch (_) {
      return 'Connexion impossible : vérifie ta connexion Internet.';
    }
  }

  static Future<void> _adopt(Map<String, dynamic> m, String pw) async {
    access = '${m['access_token']}';
    refresh = '${m['refresh_token']}';
    expired = false;
    exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + ((m['expires_in'] as num?)?.toInt() ?? 3600);
    final u = (m['user'] as Map?) ?? const {};
    uid = '${u['id'] ?? uid}';
    email = '${u['email'] ?? email}';
    await _save();
    final k = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 50000, bits: 256).deriveKeyFromPassword(password: pw, nonce: utf8.encode('minouflix:$uid'));
    key = await k.extractBytes();
    await _sec.write(key: 'acct_key', value: base64Encode(key!));
    await _sec.write(key: 'acct_pw', value: pw);      // pour connecter une télé (session propre à chaque appareil)
  }

  static Future<String?> savedPw() => _sec.read(key: 'acct_pw');

  /// jeton valide (renouvelé si besoin) ; null si la session n'est plus valable
  static Future<String?>? _refreshing;      // un seul renouvellement à la fois (le jeton de renouvellement tourne)

  static Future<String?> token() async {
    if (!signedIn) return null;
    if (DateTime.now().millisecondsSinceEpoch ~/ 1000 < exp - 60) return access;
    return _refreshing ??= _renew().whenComplete(() => _refreshing = null);
  }

  static Future<String?> _renew() async {
    try {
      final r = await http.post(Uri.parse('$kSbUrl/auth/v1/token?grant_type=refresh_token'), headers: _h, body: jsonEncode({'refresh_token': refresh})).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) {
        if (r.statusCode == 400 || r.statusCode == 401) expired = true;
        return null;
      }
      final m = jsonDecode(r.body) as Map<String, dynamic>;
      expired = false;
      access = '${m['access_token']}';
      refresh = '${m['refresh_token']}';
      exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + ((m['expires_in'] as num?)?.toInt() ?? 3600);
      await _save();
      return access;
    } catch (_) {
      return null;
    }
  }

  /// suppression définitive du compte et de ses données (fonction serveur `delete_account`) ; null = fait, sinon message
  static Future<String?> deleteAccount() async {
    final t = await token();
    if (t == null) return expired ? 'Session expirée : reconnecte-toi au compte, puis réessaie.' : 'Connexion impossible : vérifie ta connexion Internet.';
    try {
      final r = await http.post(Uri.parse('$kSbUrl/rest/v1/rpc/delete_account'), headers: {..._h, 'Authorization': 'Bearer $t'}, body: '{}').timeout(const Duration(seconds: 15));
      if (r.statusCode < 300) return null;
      // fonction pas encore créée sur le serveur (docs/supabase_delete_account.sql)
      if (r.statusCode == 404 || r.body.contains('PGRST202') || r.body.contains('Could not find the function')) {
        return 'La suppression de compte n\'est pas encore activée sur le serveur. Rien n\'a été supprimé : réessaie plus tard.';
      }
      return 'Suppression impossible (erreur ${r.statusCode}). Rien n\'a été supprimé : réessaie plus tard.';
    } catch (_) {
      return 'Connexion impossible : vérifie ta connexion Internet.';
    }
  }

  static Future<void> signOut() async {
    access = refresh = email = uid = '';
    exp = 0;
    expired = false;
    key = null;
    await _sec.delete(key: 'acct');
    await _sec.delete(key: 'acct_key');
    await _sec.delete(key: 'acct_pw');
  }

  /// chiffre / déchiffre un texte (AES-256-GCM) avec la clé du compte
  static Future<String?> seal(String text) async {
    if (key == null) return null;
    final b = await AesGcm.with256bits().encrypt(utf8.encode(text), secretKey: SecretKey(key!));
    return base64Encode(b.concatenation());
  }

  static Future<String?> open(String s) async {
    if (key == null) return null;
    try {
      final box = SecretBox.fromConcatenation(base64Decode(s), nonceLength: 12, macLength: 16);
      return utf8.decode(await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(key!)));
    } catch (_) {
      return null;
    }
  }
}
