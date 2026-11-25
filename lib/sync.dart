import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'auth.dart';
import 'keys.dart';
import 'store.dart';
import 'xtream.dart';

/// synchronisation avec le compte : Ma liste, reprise, prénom/sports et (chiffrés) identifiants IPTV ; chaque catégorie au choix
class Sync {
  static bool _busy = false;
  /// vrai quand le serveur a répondu au moins une fois : « compte neuf » n'est décidé que dans ce cas (réseau lent ≠ compte vide)
  static bool pulled = false;
  static bool get on => Account.signedIn;

  static const opts = [
    ('favs', 'Ma liste', 'Films et séries mis de côté'),
    ('prog', 'Reprise de lecture', 'Reprendre où tu t\'étais arrêté, sur chaque appareil'),
    ('meta', 'Prénom et sports', 'Ton prénom et tes championnats préférés'),
    ('creds', 'Sources IPTV', 'Chiffrées avec ton mot de passe : jamais lisibles par le serveur'),
    ('settings', 'Réglages', 'Qualité, langues audio et sous-titres, lecture automatique'),
    ('sel', 'Catégories, playlists et chaînes masquées', 'Pour chaque source, pour tout retrouver sur un nouvel appareil'),
  ];
  static bool opt(String k) => Store.flag('sync_$k', true);

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
  /// fresh : première connexion de cet appareil à un compte déjà configuré : la copie du serveur l'emporte sur tout ce qui existe ici
  static Future<bool> run({bool fresh = false}) async {
    if (!on) return false;
    for (var i = 0; _busy && i < 150; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));      // une synchro est déjà en cours : on attend son tour au lieu de repartir les mains vides
    }
    if (_busy) return false;
    int lt(int v) => fresh ? 0 : v;
    final origin = Store.activeId.isEmpty && Store.profId.isEmpty;     // liste, reprise et prénom : source et profil d'origine seulement
    _busy = true;
    try {
      final h = await _h();
      if (h == null) return false;
      final d0 = await _pull(h);
      if (d0 == null) return false;
      pulled = true;
      if (d0.isNotEmpty && !Store.flag('acct_known', false)) await Store.setFlag('acct_known', true);
      final d = <String, dynamic>{...d0};
      var changed = false;
      // liste, reprise et playlists : profil d'origine à la racine, chaque autre profil / source dans « ctx » (sans quoi leur liste et leur reprise ne suivaient pas)
      final ck = Store.ppre;
      final ctxAll = d['ctx'] is Map ? (d['ctx'] as Map).cast<String, dynamic>() : <String, dynamic>{};
      final ctxMine = ck.isEmpty ? d : (ctxAll[ck] is Map ? (ctxAll[ck] as Map).cast<String, dynamic>() : <String, dynamic>{});
      if (opt('favs')) {
        final rf = (ctxMine['favs_t'] as num?)?.toInt() ?? 0;
        if (rf > lt(Store.favsT)) {
          await Store.setFavs([for (final x in (ctxMine['favs'] as List? ?? [])) '$x'], rf);
          changed = true;
        }
        ctxMine['favs'] = Store.favs.toList();
        ctxMine['favs_t'] = Store.favsT;
      }
      if (origin && opt('meta')) {
        final rm = (d['meta_t'] as num?)?.toInt() ?? 0;
        if (rm > lt(Store.metaT)) {
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
        for (final x in (ctxMine['prog'] as List? ?? [])) {
          final p = Prog.fromJson((x as Map).cast<String, dynamic>());
          final m = loc[p.key];
          if (m == null || p.t > m.t || (p.t == m.t && p.hidden && !m.hidden)) {      // à date égale, le retrait l'emporte
            loc[p.key] = p;
            changed = true;
          }
        }
        final all = loc.values.toList()..sort((a, b) => b.t.compareTo(a.t));
        if (changed) await Store.setAllProg(all);
        ctxMine['prog'] = [for (final p in all.take(40)) p.toJson()];
      }
      if (Store.profId.isNotEmpty && opt('favs')) {      // playlists d'un autre profil (celles du profil d'origine voyagent avec la sélection)
        final rt = (ctxMine['colls_t'] as num?)?.toInt() ?? 0;
        if (rt > lt(Store.collsT) && ctxMine['colls'] is String) {
          await Store.setCollsRaw(ctxMine['colls'] as String, rt);
          changed = true;
        } else if (Store.collsT > 0) {
          ctxMine['colls'] = Store.collsRaw;
          ctxMine['colls_t'] = Store.collsT;
        }
      }
      if (ck.isNotEmpty && (opt('favs') || opt('prog'))) {
        ctxAll[ck] = ctxMine;
        d['ctx'] = ctxAll;
      }
      if (opt('creds')) {
        // source d'origine : la copie la plus récente gagne (modifiable sur n'importe quel appareil)
        final rt = (d['creds_t'] as num?)?.toInt() ?? 0, rc = d['creds'];
        // source d'origine supprimée sur un appareil : elle ne revient pas, et disparaît des autres
        final delT = math.max((d['creds_del_t'] as num?)?.toInt() ?? 0, Store.credsDelT);
        if (delT > 0 && delT > lt(Store.credsT) && await Store.credsOf('') != null) {
          await Store.removeSource('', at: delT);
          changed = true;
        }
        if (delT > 0) d['creds_del_t'] = delT;
        if (rc is String && rt > lt(Store.credsT) && rt > delT) {
          final txt = await Account.open(rc);
          final nc = txt == null ? null : Creds.fromJson(jsonDecode(txt) as Map<String, dynamic>);
          if (nc != null) {
            await Store.setCredsFromCloud(nc, rt);
            changed = true;
          }
        } else if (await Store.credsOf('') != null) {
          final c = await Store.credsOf('');
          final enc = c == null ? null : await Account.seal(jsonEncode(c.toJson()));
          if (enc != null) {
            d['creds'] = enc;
            d['creds_t'] = Store.credsT;
          }
        } else if (rc is String && delT > 0 && rt <= delT) {
          d.remove('creds');      // supprimée : plus rien d'elle dans le compte
          d.remove('creds_t');
        }
        // sources supplémentaires : chiffrées aussi, ajoutées ou modifiées sur tes autres appareils (une suppression faite sur un appareil est retenue et suivie par les autres)
        final (dels, delChanged) = await Store.mergeDeletions(d['sources_del'] is Map ? (d['sources_del'] as Map).cast<String, dynamic>() : <String, dynamic>{});
        if (delChanged) changed = true;
        if (dels.isNotEmpty) d['sources_del'] = dels;
        final encX = await Account.open('${d['sources'] ?? ''}');
        if (encX != null && await Store.mergeSources(jsonDecode(encX) as List)) changed = true;
        final ex = await Store.extraSources();
        if (ex.isNotEmpty) {
          final sealed = await Account.seal(jsonEncode(ex));
          if (sealed != null) d['sources'] = sealed;
        }
      }   // option coupée : on ne touche pas aux identifiants des autres appareils
      if (opt('settings')) {
        final rt = (d['settings_t'] as num?)?.toInt() ?? 0;
        if (rt > lt(Store.settingsT) && d['settings'] is Map) {
          await Store.applySettings((d['settings'] as Map).cast<String, dynamic>(), rt);
          changed = true;
        } else if (Store.settingsT > 0) {
          d['settings'] = Store.settingsSnap();
          d['settings_t'] = Store.settingsT;
        }
      }
      if (opt('settings') && origin) {
        // réglages de chaque profil, et version choisie pour chaque film
        if (d['psettings'] is Map && await Store.applyProfs((d['psettings'] as Map).cast<String, dynamic>(), fresh: fresh)) changed = true;
        final mine = Store.profSnap();
        d['psettings'] = {...(d['psettings'] is Map ? (d['psettings'] as Map).cast<String, dynamic>() : <String, dynamic>{}), ...mine};
        final rv = (d['vers_t'] as num?)?.toInt() ?? 0;
        if (d['vers'] is Map && await Store.mergeVers((d['vers'] as Map).cast<String, dynamic>(), fresh ? 1 << 50 : rv)) changed = true;
        d['vers'] = Store.versSnap();
        d['vers_t'] = Store.versT;
      }
      if (opt('sel')) {
        final remote = d['sel'] is Map ? (d['sel'] as Map).cast<String, dynamic>() : <String, dynamic>{};
        final out = <String, dynamic>{...remote};
        for (final src in await Store.sources()) {
          final id = src.$1, key = id.isEmpty ? '_' : id;
          final rm = remote[key];
          final rt = rm is Map ? (rm['t'] as num?)?.toInt() ?? 0 : 0;
          if (rm is Map && rt > lt(Store.selT(id))) {
            await Store.applySel(id, rm.cast<String, dynamic>());
            changed = true;
          } else {
            final snap = Store.selSnap(id);
            if (snap != null) out[key] = snap;
          }
        }
        d['sel'] = out;
        if (origin) {
          if (await Store.restoreProfiles(d['profs'] is List ? d['profs'] as List : const [])) changed = true;
          d['profs'] = Store.profilsSnap();
        }
      }
      // retours des utilisateurs : ajoutés à la copie du compte, marqués envoyés seulement si le serveur a accepté
      final fb = Store.feedbackPending();
      if (fb.isNotEmpty) {
        d['feedback'] = [...(d['feedback'] is List ? d['feedback'] as List : const []), for (final e in fb) {...e}..remove('sent')];
      }
      final r = await http.post(Uri.parse('$kSbUrl/rest/v1/user_data'), headers: {...h, 'Prefer': 'resolution=merge-duplicates'}, body: jsonEncode({'user_id': Account.uid, 'data': d, 'updated_at': DateTime.now().toUtc().toIso8601String()})).timeout(const Duration(seconds: 12));
      if (r.statusCode < 300 && fb.isNotEmpty) await Store.markFeedbackSent([for (final e in fb) e['id']]);
      return changed;
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }
}
