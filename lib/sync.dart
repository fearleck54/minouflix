import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth.dart';
import 'keys.dart';
import 'store.dart';
import 'xtream.dart';

/// synchronisation avec le compte : Ma liste, reprise, prénom/sports et (chiffrés) identifiants IPTV ; chaque catégorie au choix
class Sync {
  static bool _busy = false;
  static bool get on => Account.signedIn;

  static const opts = [
    ('favs', 'Ma liste', 'Films et séries mis de côté'),
    ('prog', 'Reprise de lecture', 'Reprendre où tu t\'étais arrêté, sur chaque appareil'),
    ('meta', 'Prénom et sports', 'Ton prénom et tes championnats préférés'),
    ('creds', 'Identifiants IPTV', 'Chiffrés avec ton mot de passe : jamais lisibles par le serveur'),
  ];
  static bool opt(String k) => Store.flag('sync_$k', k != 'creds');

  static Future<Map<String, String>?> _h() async {
    final t = await Account.token();
    return t == null ? null : {'apikey': kSbKey, 'Authorization': 'Bearer $t', 'Content-Type': 'application/json'};
  }

  /// récupère la copie du serveur ; null si rien ou pas connecté
  static Future<Map<String, dynamic>?> _pull(Map<String, String> h) async {
    final r = await http.get(Uri.parse('$kSbUrl/rest/v1/user_data?select=data'), headers: h).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    final rows = jsonDecode(r.body) as List;
    final d = rows.isEmpty ? null : rows.first['data'];
    return d is Map ? d.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// nouvel appareil : retrouve les identifiants IPTV chiffrés du compte
  static Future<Creds?> cloudCreds() async {
    try {
      final h = await _h();
      if (h == null) return null;
      final d = await _pull(h);
      final enc = d?['creds'];
      if (enc is! String) return null;
      final s = await Account.open(enc);
      return s == null ? null : Creds.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// « Effacer mes données » : supprime la copie du compte sur le serveur (si la règle d'accès le permet) ; true si c'est fait
  static Future<bool> wipe() async {
    try {
      final h = await _h();
      if (h == null || Account.uid.isEmpty) return false;
      final r = await http.delete(Uri.parse('$kSbUrl/rest/v1/user_data?user_id=eq.${Account.uid}'), headers: h).timeout(const Duration(seconds: 12));
      return r.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// fusionne avec le serveur, puis renvoie le résultat ; true si les données locales ont changé
  static Future<bool> run() async {
    if (!on || _busy || Store.activeId.isNotEmpty || Store.profId.isNotEmpty) return false;     // la synchro ne concerne que la source et le profil d'origine
    _busy = true;
    try {
      final h = await _h();
      if (h == null) return false;
      final d0 = await _pull(h);
      if (d0 == null) return false;
      final d = <String, dynamic>{...d0};
      var changed = false;
      if (opt('favs')) {
        final rf = (d['favs_t'] as num?)?.toInt() ?? 0;
        if (rf > Store.favsT) {
          await Store.setFavs([for (final x in (d['favs'] as List? ?? [])) '$x'], rf);
          changed = true;
        }
        d['favs'] = Store.favs.toList();
        d['favs_t'] = Store.favsT;
      }
      if (opt('meta')) {
        final rm = (d['meta_t'] as num?)?.toInt() ?? 0;
        if (rm > Store.metaT) {
          var sport = [for (final x in (d['sport'] as List? ?? [])) '$x'];
          if (sport.isEmpty) sport = Store.sportKeys;
          await Store.setMeta('${d['name'] ?? ''}', sport, rm);
          changed = true;
        }
        d['name'] = Store.name;
        d['sport'] = Store.sportKeys;
        d['meta_t'] = Store.metaT;
      }
      if (opt('prog')) {
        final loc = {for (final p in Store.allProg()) p.key: p};
        for (final x in (d['prog'] as List? ?? [])) {
          final p = Prog.fromJson((x as Map).cast<String, dynamic>());
          final m = loc[p.key];
          if (m == null || p.t > m.t) {
            loc[p.key] = p;
            changed = true;
          }
        }
        final all = loc.values.toList()..sort((a, b) => b.t.compareTo(a.t));
        if (changed) await Store.setAllProg(all);
        d['prog'] = [for (final p in all.take(40)) p.toJson()];
      }
      if (opt('creds')) {
        final c = await Store.creds();
        final enc = c == null ? null : await Account.seal(jsonEncode(c.toJson()));
        if (enc != null) d['creds'] = enc;
        // sources supplémentaires : chiffrées aussi, ajoutées sur tes autres appareils (jamais supprimées à distance)
        final encX = await Account.open('${d['sources'] ?? ''}');
        if (encX != null && await Store.mergeSources(jsonDecode(encX) as List)) changed = true;
        final ex = await Store.extraSources();
        if (ex.isNotEmpty) {
          final sealed = await Account.seal(jsonEncode(ex));
          if (sealed != null) d['sources'] = sealed;
        }
      }   // option coupée : on ne touche pas aux identifiants des autres appareils
      await http.post(Uri.parse('$kSbUrl/rest/v1/user_data'), headers: {...h, 'Prefer': 'resolution=merge-duplicates'}, body: jsonEncode({'user_id': Account.uid, 'data': d, 'updated_at': DateTime.now().toUtc().toIso8601String()})).timeout(const Duration(seconds: 12));
      return changed;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }
}
