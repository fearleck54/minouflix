import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:cryptography/dart.dart' show DartSha256;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pin_guard.dart';
import 'xtream.dart';

/// Identifiants : chiffrés sur l'appareil (Keychain / Keystore), jamais envoyés ailleurs.
class Store {
  static const _sec = FlutterSecureStorage();
  static late SharedPreferences _p;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    _active = _p.getString('src_active') ?? '';
    _prof = _p.getString('prof_active') ?? '';
  }

  // ---- sources IPTV : une seule est active à la fois ; la source d'origine a l'id '' (ses clés ne changent pas)
  static String _active = '';
  static String? _pending;           // nouvelle source en cours d'ajout (nom choisi)
  /// appelé après un changement de source : les caches en mémoire (studios, fiches, calendrier) sont à vider
  static VoidCallback? onSourceChanged;
  static String get activeId => _active;
  /// préfixe des clés propres à la source active (vide pour la source d'origine)
  static String get pre => _active.isEmpty ? '' : '${_active}_';

  // ---- profils : favoris, reprise, collections et prénom propres à chaque personne (le profil d'origine a l'id '')
  static String _prof = '';
  static String get profId => _prof;
  static String get ppre => '$pre${_prof.isEmpty ? '' : 'p${_prof}_'}';
  static List<(String, String)> profiles() {
    final l = <(String, String)>[('', _p.getString('prof_name') ?? 'Moi')];
    try {
      for (final x in jsonDecode(_p.getString('profs') ?? '[]') as List) {
        l.add(('${(x as Map)['id']}', '${x['name']}'));
      }
    } catch (_) {}
    return l;
  }

  static Future<void> _saveProfs(List<(String, String)> l) => _p.setString('profs', jsonEncode([for (final e in l.skip(1)) {'id': e.$1, 'name': e.$2}]));

  static Future<void> addProfile(String name) async {
    final l = profiles()..add((DateTime.now().millisecondsSinceEpoch.toRadixString(36), name.trim().isEmpty ? 'Profil' : name.trim()));
    await _saveProfs(l);
    await setProfile(l.last.$1);
  }

  static Future<void> renameProfile(String id, String name) async {
    if (id.isEmpty) {
      await _p.setString('prof_name', name.trim().isEmpty ? 'Moi' : name.trim());
      await setName(name.trim().isEmpty ? '' : name.trim());      // « Bonjour … » et synchronisation
      return;
    }
    await _saveProfs([for (final e in profiles()) e.$1 == id ? (id, name.trim().isEmpty ? e.$2 : name.trim()) : e]);
  }

  static Future<void> setProfile(String id) async {
    _prof = id;
    await _p.setString('prof_active', id);
    onSourceChanged?.call();
  }

  static Future<void> removeProfile(String id) async {
    if (id.isEmpty) return;
    final src = [''] + [for (final x in await _extras()) '${x['id']}_'];
    for (final p in src) {
      for (final k in ['favs', 'favs_t', 'prog', 'colls']) {
        await _p.remove('${p}p${id}_$k');
      }
    }
    await _p.remove('${id}_name_p');
    await _saveProfs([for (final e in profiles()) if (e.$1 != id) e]);
    if (_prof == id) await setProfile('');
  }

  static Future<List<Map<String, dynamic>>> _extras() async {
    try {
      final s = await _sec.read(key: 'sources');
      return s == null ? [] : [for (final x in jsonDecode(s) as List) (x as Map).cast<String, dynamic>()];
    } catch (_) {
      return [];
    }
  }

  /// synchro du compte : sources supplémentaires (identifiants compris) à envoyer, et sources reçues d'un autre appareil à ajouter
  static Future<List<Map<String, dynamic>>> extraSources() => _extras();
  static Future<bool> mergeSources(List<dynamic> incoming) async {
    final l = await _extras();
    final have = {for (final x in l) '${x['id']}'};
    var added = false;
    for (final x in incoming) {
      if (x is! Map || '${x['id']}'.isEmpty) continue;
      if (have.contains('${x['id']}')) {
        // source déjà connue : la copie la plus récente (modifiée sur un autre appareil) gagne
        for (final y in l) {
          if ('${y['id']}' == '${x['id']}' && ((x['t'] as num?)?.toInt() ?? 0) > ((y['t'] as num?)?.toInt() ?? 0)) {
            for (final e in x.entries) {
              y['${e.key}'] = e.value;
            }
            added = true;
          }
        }
        continue;
      }
      l.add({for (final e in x.entries) '${e.key}': e.value});
      added = true;
    }
    if (added) await _saveExtras(l);
    return added;
  }

  /// identifiants d'une source précise (modification en place)
  static Future<Creds?> credsOf(String id) async {
    if (id.isEmpty) return _legacy();
    for (final x in await _extras()) {
      if (x['id'] == id) return Creds('${x['server']}', '${x['user']}', '${x['pass']}');
    }
    return null;
  }

  /// modifie une source en place (nom et identifiants) ; la sélection de catégories, la liste et la reprise sont gardées, le catalogue est rechargé
  static Future<void> updateSource(String id, String name, Creds c) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (id.isEmpty) {
      await _sec.write(key: 'creds', value: jsonEncode(c.toJson()));
      await _p.setInt('creds_t', now);
      if (name.trim().isNotEmpty) await _p.setString('src_name', name.trim());
    } else {
      final l = await _extras();
      for (final x in l) {
        if (x['id'] == id) {
          if (name.trim().isNotEmpty) x['name'] = name.trim();
          x['server'] = c.server;
          x['user'] = c.user;
          x['pass'] = c.pass;
          x['t'] = now;
        }
      }
      await _saveExtras(l);
    }
    final p = id.isEmpty ? '' : '${id}_';
    await _p.remove('${p}cat_t');      // le catalogue sera relu chez le fournisseur
    if (!kIsWeb) {
      try {
        final sup = (await getApplicationSupportDirectory()).path;
        final d = Directory(id.isEmpty ? '$sup/cats' : '$sup/cats_$id');
        if (await d.exists()) await d.delete(recursive: true);
      } catch (_) {}
    }
  }

  static int get credsT => _p.getInt('creds_t') ?? 0;
  static Future<void> setCredsFromCloud(Creds c, int t) async {
    await _sec.write(key: 'creds', value: jsonEncode(c.toJson()));
    await _p.setInt('creds_t', t);
  }

  // ---- réglages synchronisés avec le compte (qualité, audio, sous-titres, lecture auto)
  static const _setStrKeys = ['pref_q', 'pref_aud', 'pref_sub'];
  static const _setFlagKeys = ['autonext', 'skipauto', 'sport_nospoil'];
  static int get settingsT => _p.getInt('settings_t') ?? 0;
  static Map<String, dynamic> settingsSnap() => {
        if (_p.getStringList('tab_order') != null) 'tab_order': _p.getStringList('tab_order'),
        if (_p.getStringList('tab_hid') != null) 'tab_hid': _p.getStringList('tab_hid'),
        if (_p.getInt('tab_start') != null) 'tab_start': _p.getInt('tab_start'),
        if (_p.getStringList('home_order') != null) 'home_order': _p.getStringList('home_order'),
        if (_p.getStringList('home_hid') != null) 'home_hid': _p.getStringList('home_hid'),
        if (_p.getStringList('sport_teams') != null) 'sport_teams': _p.getStringList('sport_teams'),
        for (final k in _setStrKeys)
          if (_p.getString('s_$k') != null) k: _p.getString('s_$k'),
        for (final k in _setFlagKeys)
          if (_p.getBool('f_$k') != null) k: _p.getBool('f_$k'),
      };
  static Future<void> applySettings(Map<String, dynamic> m, int t) async {
    for (final k in _setStrKeys) {
      if (m[k] is String) await _p.setString('s_$k', m[k] as String);
    }
    for (final k in _setFlagKeys) {
      if (m[k] is bool) await _p.setBool('f_$k', m[k] as bool);
    }
    for (final k in ['tab_order', 'tab_hid', 'home_order', 'home_hid', 'sport_teams']) {
      if (m[k] is List) await _p.setStringList(k, [for (final x in m[k] as List) '$x']);
    }
    if (m['tab_start'] is num) await _p.setInt('tab_start', (m['tab_start'] as num).toInt());
    await _p.setInt('settings_t', t);
  }

  // ---- catégories choisies, chaînes masquées et playlists, par source (synchronisées avec le compte)
  static String _sp(String id) => id.isEmpty ? '' : '${id}_';
  static int selT(String id) => _p.getInt('${_sp(id)}sel_t') ?? 0;
  static Future<void> _touchSel() => _p.setInt('${pre}sel_t', DateTime.now().millisecondsSinceEpoch);
  /// null = cette source n'a pas encore de sélection
  static Map<String, dynamic>? selSnap(String id) {
    final p = _sp(id);
    if (_p.getStringList('${p}sel_${Kind.live.name}') == null && _p.getStringList('${p}sel_${Kind.vod.name}') == null && _p.getStringList('${p}sel_${Kind.series.name}') == null) return null;
    return {
      't': selT(id),
      for (final k in Kind.values) ...{
        'sel_${k.name}': _p.getStringList('${p}sel_${k.name}') ?? <String>[],
        'names_${k.name}': _p.getString('${p}names_${k.name}') ?? '{}',
      },
      'hid': _p.getStringList('${p}hid') ?? <String>[],
      'colls': _p.getString('${p}colls') ?? '{}',
    };
  }

  static Future<void> applySel(String id, Map<String, dynamic> m) async {
    final p = _sp(id);
    for (final k in Kind.values) {
      final l = m['sel_${k.name}'];
      if (l is List) await _p.setStringList('${p}sel_${k.name}', [for (final x in l) '$x']);
      final n = m['names_${k.name}'];
      if (n is String) await _p.setString('${p}names_${k.name}', n);
    }
    final h = m['hid'];
    if (h is List) await _p.setStringList('${p}hid', [for (final x in h) '$x']);
    final c = m['colls'];
    if (c is String && c != '{}') await _p.setString('${p}colls', c);
    await _p.setInt('${p}sel_t', (m['t'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch);
    await _p.remove('${p}cat_t');      // catalogue relu avec la sélection reçue
  }

  // ---- profils (noms seulement) : un nouvel appareil retrouve la liste
  static List<Map<String, String>> profilsSnap() => [for (final e in profiles().skip(1)) {'id': e.$1, 'name': e.$2}];
  static Future<bool> restoreProfiles(List<dynamic> incoming) async {
    if (profiles().length > 1 || incoming.isEmpty) return false;
    final l = profiles();
    for (final x in incoming) {
      if (x is Map && '${x['id']}'.isNotEmpty) l.add(('${x['id']}', '${x['name']}'));
    }
    await _saveProfs(l);
    return true;
  }

  static Future<void> _saveExtras(List<Map<String, dynamic>> l) => _sec.write(key: 'sources', value: jsonEncode(l));

  /// toutes les sources : (id, nom)
  static Future<List<(String, String)>> sources() async {
    final out = <(String, String)>[];
    try {
      if (await _sec.read(key: 'creds') != null) out.add(('', _p.getString('src_name') ?? 'Ma source'));
    } catch (_) {}
    for (final x in await _extras()) {
      out.add(('${x['id']}', '${x['name']}'));
    }
    return out;
  }

  /// la prochaine saisie d'identifiants crée une NOUVELLE source (au lieu de remplacer la source active)
  static void beginSource(String name) => _pending = name.trim().isEmpty ? 'Source' : name.trim();
  static void cancelSource() => _pending = null;

  static Future<void> setActive(String id) async {
    _active = id;
    await _p.setString('src_active', id);
    onSourceChanged?.call();
  }

  static Future<void> renameSource(String id, String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    if (id.isEmpty) {
      await _p.setString('src_name', n);
      return;
    }
    final l = await _extras();
    for (final x in l) {
      if (x['id'] == id) {
        x['name'] = n;
        x['t'] = DateTime.now().millisecondsSinceEpoch;
      }
    }
    await _saveExtras(l);
  }

  /// supprime une source et SES données (catalogue, sélection, favoris, reprise) ; les autres restent
  static Future<void> removeSource(String id) async {
    await _purge(id);
    if (id.isEmpty) {
      await _sec.delete(key: 'creds');
      await _p.remove('src_name');
    } else {
      await _saveExtras([for (final x in await _extras()) if (x['id'] != id) x]);
    }
    if (_active == id) {
      final left = await sources();
      await setActive(left.isEmpty ? '' : left.first.$1);
    }
  }

  static Future<void> _purge(String id) async {
    final p = id.isEmpty ? '' : '${id}_';
    for (final k in Kind.values) {
      await _p.remove('${p}sel_${k.name}');
      await _p.remove('${p}names_${k.name}');
    }
    for (final k in ['cat_t', 'prog', 'favs', 'favs_t', 'colls', 'hid']) {
      await _p.remove('$p$k');
    }
    if (kIsWeb) return;
    try {
      final sup = (await getApplicationSupportDirectory()).path;
      final d = Directory(id.isEmpty ? '$sup/cats' : '$sup/cats_$id');
      if (await d.exists()) await d.delete(recursive: true);
      for (final k in Kind.values) {
        for (final f in [File('$sup/${p}studios_${k.name}.json'), if (id.isEmpty) File('$sup/cat2_${k.name}.json')]) {
          if (await f.exists()) await f.delete();
        }
      }
    } catch (_) {}
  }

  /// prénom affiché dans « Bonjour … »
  static String get name => _prof.isEmpty ? _mainName : (profiles().firstWhere((e) => e.$1 == _prof, orElse: () => ('', '')).$2);
  /// profil d'origine : le nom du profil (ou l'ancien prénom synchronisé) ; « Moi » = pas encore personnalisé
  static String get _mainName {
    final n = _p.getString('name') ?? '';
    if (n.isNotEmpty) return n;
    final pn = _p.getString('prof_name') ?? '';
    return pn == 'Moi' ? '' : pn;
  }
  static Future<void> setName(String v) async {
    await _p.setString('name', v.trim());
    await _p.setInt('meta_t', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<Creds?> _legacy() async {
    try {
      final s = await _sec.read(key: 'creds');
      return s == null ? null : Creds.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;      // trousseau illisible (restauration d'appareil…) : on redemande les identifiants
    }
  }

  /// identifiants de la source active
  static Future<Creds?> creds() async {
    if (_active.isEmpty) return _legacy();
    for (final x in await _extras()) {
      if (x['id'] == _active) return Creds('${x['server']}', '${x['user']}', '${x['pass']}');
    }
    // source introuvable (supprimée) : retour à la source d'origine
    _active = '';
    await _p.setString('src_active', '');
    return _legacy();
  }

  static Future<void> saveCreds(Creds c) async {
    final name = _pending;
    if (name != null) {
      _pending = null;
      final id = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
      final l = await _extras();
      l.add({'id': id, 'name': name, 'server': c.server, 'user': c.user, 'pass': c.pass, 't': DateTime.now().millisecondsSinceEpoch});
      await _saveExtras(l);
      await setActive(id);
      return;
    }
    if (_active.isEmpty) {
      await _p.setInt('creds_t', DateTime.now().millisecondsSinceEpoch);
      return _sec.write(key: 'creds', value: jsonEncode(c.toJson()));
    }
    final l = await _extras();
    for (final x in l) {
      if (x['id'] == _active) {
        x['server'] = c.server;
        x['user'] = c.user;
        x['pass'] = c.pass;
        x['t'] = DateTime.now().millisecondsSinceEpoch;
      }
    }
    await _saveExtras(l);
  }

  static Future<void> clear() async {
    for (final x in await sources()) {
      await _purge(x.$1);
    }
    await _sec.delete(key: 'creds');
    await _sec.delete(key: 'sources');
    await _p.remove('src_name');
    _active = '';
    await _p.setString('src_active', '');
    onSourceChanged?.call();
  }

  /// tout effacer sur cet appareil (identifiants, réglages, reprise, caches, téléchargements)
  static Future<void> wipe() async {
    try {
      await _sec.deleteAll();
    } catch (_) {}
    await clearCatalog();
    _active = '';
    _prof = '';
    if (!kIsWeb) {
      try {
        final d = Directory('${(await getApplicationDocumentsDirectory()).path}/dl');
        if (await d.exists()) await d.delete(recursive: true);
      } catch (_) {}
    }
    await _p.clear();
  }

  /// sélection de catégories (par type) ; null = pas encore choisie
  static List<String>? selection(Kind k) => _p.getStringList('${pre}sel_${k.name}');
  static Future<void> saveSelection(Kind k, List<String> ids) async {
    await _p.setStringList('${pre}sel_${k.name}', ids);
    await _touchSel();
  }
  /// noms des catégories choisies (pour les filtres de l'écran) : id → nom
  static Map<String, String> catNames(Kind k) {
    final s = _p.getString('${pre}names_${k.name}');
    try {
      return s == null ? {} : (jsonDecode(s) as Map<String, dynamic>).map((a, b) => MapEntry(a, '$b'));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveCatNames(Kind k, Map<String, String> m) async {
    await _p.setString('${pre}names_${k.name}', jsonEncode(m));
    await _touchSel();
  }

  // ---- ma liste (favoris) : clés « vod:123 », « series:45 », « live:678 »
  /// change à chaque ajout / retrait de favori (les étoiles se redessinent toutes seules)
  static final favTick = ValueNotifier<int>(0);
  static Set<String> get favs => (_p.getStringList('${ppre}favs') ?? []).toSet();
  static bool isFav(String key) => favs.contains(key);
  static Future<void> toggleFav(String key) async {
    final s = favs;
    s.contains(key) ? s.remove(key) : s.add(key);
    // le cache des préférences est mis à jour tout de suite : l'accueil et les « + » se redessinent sans attendre l'écriture disque
    final a = _p.setStringList('${ppre}favs', s.toList());
    final b = _p.setInt('${ppre}favs_t', DateTime.now().millisecondsSinceEpoch);
    favTick.value++;
    await Future.wait([a, b]);
  }

  // ---- chaînes masquées (clé du groupe de chaîne), par source
  static Set<String> get hidden => (_p.getStringList('${pre}hid') ?? []).toSet();
  static Future<void> setHidden(Set<String> s) async {
    await _p.setStringList('${pre}hid', s.toList());
    await _touchSel();
  }

  // ---- synchronisation entre appareils (Supabase) : code personnel, dernières modifications
  static bool get syncAsked => _p.getBool('sync_asked') ?? false;
  static Future<void> setSyncAsked() => _p.setBool('sync_asked', true);
  static int get favsT => _p.getInt('${ppre}favs_t') ?? 0;
  static int get metaT => _p.getInt('meta_t') ?? 0;
  static Future<void> setFavs(List<String> l, int t) async {
    await _p.setStringList('${ppre}favs', l);
    await _p.setInt('${ppre}favs_t', t);
  }
  static Future<void> setMeta(String name, List<String> sport, int t) async {
    await _p.setString('name', name);
    await _p.setStringList('sport_keys', sport);
    await _p.setInt('meta_t', t);
  }
  static List<Prog> allProg() {
    try {
      return [for (final x in jsonDecode(_p.getString('${ppre}prog') ?? '[]') as List) Prog.fromJson(x as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }
  static Future<void> setAllProg(List<Prog> l) => _p.setString('${ppre}prog', jsonEncode([for (final x in l.take(40)) x.toJson()]));

  // ---- continuer à regarder
  static List<Prog> progress() {
    final s = _p.getString('${ppre}prog');
    if (s == null) return [];
    try {
      final l = [for (final x in jsonDecode(s) as List) Prog.fromJson(x as Map<String, dynamic>)];
      return l.where((p) => !p.hidden && p.pos > 20000 && (p.dur == 0 || p.pos < p.dur * 0.95)).toList()..sort((a, b) => b.t.compareTo(a.t));
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveProg(Prog p) async {
    final s = _p.getString('${ppre}prog');
    final l = <Prog>[];
    try {
      if (s != null) l.addAll([for (final x in jsonDecode(s) as List) Prog.fromJson(x as Map<String, dynamic>)]);
    } catch (_) {}
    l.removeWhere((x) => x.key == p.key);
    l.insert(0, p);
    await _p.setString('${ppre}prog', jsonEncode([for (final x in l.take(40)) x.toJson()]));
  }

  static Future<void> hideProg(String key) async {
    final s = _p.getString('${ppre}prog');
    if (s == null) return;
    final l = allProg();
    for (final x in l) {
      if (x.key == key) x.hidden = true;
    }
    await _p.setString('${ppre}prog', jsonEncode([for (final x in l) x.toJson()]));
  }

  // ---- réglages
  static bool get kid => _p.getBool('kid') ?? false;
  static String get kidPin => _p.getString('kid_pin') ?? '';
  static String _hashPin(String pin) => 'h:${base64Encode(DartSha256().hashSync(utf8.encode('minou-kid:$pin')).bytes)}';
  /// le code enfant n'est plus conservé en clair (les anciens codes en clair restent acceptés)
  static bool pinOk(String p) => kidPin == _hashPin(p) || kidPin == p;
  /// qualité par défaut : '4k' (quand elle existe) ou 'hd' (moins de données) ; reprend l'ancien réglage « Préférer la 4K »
  static String get quality {
    final q = str('pref_q');
    return q.isNotEmpty ? q : (flag('uhd') ? '4k' : 'hd');
  }

  /// dernière mise à jour complète du catalogue (ms)
  static int get catT => _p.getInt('${pre}cat_t') ?? 0;
  static Future<void> setCatT() => _p.setInt('${pre}cat_t', DateTime.now().millisecondsSinceEpoch);

  static Future<void> setKid(bool v, [String pin = '']) async {
    await _p.setBool('kid', v);
    if (pin.isNotEmpty) await _p.setString('kid_pin', _hashPin(pin));
  }
  /// essais ratés du code enfant et fin du blocage (survivent à un redémarrage de l'appli)
  static PinGuard get pinGuard => PinGuard(_p.getInt('kid_fails') ?? 0, _p.getInt('kid_lock') ?? 0);
  static Future<void> setPinGuard(PinGuard g) async {
    await _p.setInt('kid_fails', g.fails);
    await _p.setInt('kid_lock', g.lockUntil);
  }

  static List<String> get sportKeys => _p.getStringList('sport_keys') ?? const ['l1', 'top14', 'ucl', 'f1'];
  static Future<void> saveSportKeys(List<String> v) async {
    await _p.setStringList('sport_keys', v);
    await _p.setInt('meta_t', DateTime.now().millisecondsSinceEpoch);
  }
  static String str(String k) => _p.getString('s_$k') ?? '';
  static Future<void> setStr(String k, String v) async {
    await _p.setString('s_$k', v);
    if (_setStrKeys.contains(k)) await _p.setInt('settings_t', DateTime.now().millisecondsSinceEpoch);
  }

  /// collections perso : nom → clés « vod:1 », « series:2 »
  static Map<String, List<String>> get colls {
    try {
      return (jsonDecode(_p.getString('${ppre}colls') ?? '{}') as Map).map((k, v) => MapEntry('$k', [for (final e in v as List) '$e']));
    } catch (_) {
      return {};
    }
  }

  static Future<void> removeFromColl(String name, String key) async {
    final m = colls;
    m[name]?.remove(key);
    await saveColls(m);
  }

  static Future<void> deleteColl(String name) async {
    final m = colls..remove(name);
    await saveColls(m);
  }

  static Future<void> renameColl(String from, String to) async {
    final n = to.trim();
    final m = colls;
    if (n.isEmpty || n == from || m.containsKey(n) || !m.containsKey(from)) return;
    final v = m.remove(from)!;
    m[n] = v;
    await saveColls(m);
  }

  static Future<void> saveColls(Map<String, List<String>> m) async {
    final f = _p.setString('${ppre}colls', jsonEncode(m));
    favTick.value++;     // l'accueil affiche aussi les playlists
    await f;
    if (_prof.isEmpty) await _touchSel();
  }

  /// change quand la barre du bas ou l'écran d'accueil sont personnalisés : l'accueil se redessine tout de suite
  static final persoTick = ValueNotifier<int>(0);

  // ---- barre du bas : ordre des onglets, onglets cachés, onglet d'ouverture (0 Accueil, 1 Direct, 2 Films, 3 Séries, 4 Sport) — synchronisés
  static List<int> tabOrder() {
    final l = [for (final x in _p.getStringList('tab_order') ?? const <String>[]) if (int.tryParse(x) != null && int.parse(x) >= 0 && int.parse(x) <= 4) int.parse(x)];
    final out = l.toSet().toList();
    for (var i = 0; i <= 4; i++) {
      if (!out.contains(i)) out.add(i);
    }
    return out;
  }

  static Set<int> tabHidden() => {for (final x in _p.getStringList('tab_hid') ?? const <String>[]) if (int.tryParse(x) != null) int.parse(x)};
  /// 0..4 = cet onglet ; 9 = le dernier ouvert ; -1 = le premier de la barre
  static int tabStart() => _p.getInt('tab_start') ?? -1;
  static int get lastTab => _p.getInt('tab_last') ?? 0;
  static Future<void> setLastTab(int t) => _p.setInt('tab_last', t);

  /// onglets affichés, dans l'ordre choisi ; mode enfant : sans Direct ni Sport ; jamais vide
  static List<int> tabsVisible({bool kid = false}) {
    final hid = tabHidden();
    final l = [for (final t in tabOrder()) if (!hid.contains(t) && !(kid && (t == 1 || t == 4))) t];
    return l.isEmpty ? [0] : l;
  }

  static int initialTab({bool kid = false}) {
    final vis = tabsVisible(kid: kid), st = tabStart();
    if (st == 9) return vis.contains(lastTab) ? lastTab : vis.first;
    if (st >= 0 && vis.contains(st)) return st;
    return vis.first;
  }

  static Future<void> setTabs(List<int> order, Set<int> hidden, int start) async {
    await _p.setStringList('tab_order', [for (final t in order) '$t']);
    await _p.setStringList('tab_hid', [for (final t in hidden) '$t']);
    await _p.setInt('tab_start', start);
    await _p.setInt('settings_t', DateTime.now().millisecondsSinceEpoch);
    persoTick.value++;
  }

  // ---- écran d'accueil : sections affichées et leur ordre (synchronisés)
  static const homeIds = ['hero', 'continue', 'mylist', 'soon', 'playlists', 'downloads', 'top10', 'affiche', 'sport', 'chains', 'recoV', 'recoS', 'recent', 'recentS'];
  static List<String> homeOrder() {
    final l = [for (final x in _p.getStringList('home_order') ?? const <String>[]) if (homeIds.contains(x)) x].toSet().toList();
    for (final x in homeIds) {
      if (!l.contains(x)) l.add(x);
    }
    return l;
  }

  static Set<String> homeHidden() => (_p.getStringList('home_hid') ?? const <String>[]).toSet();
  static Future<void> setHome(List<String> order, Set<String> hidden) async {
    await _p.setStringList('home_order', order);
    await _p.setStringList('home_hid', hidden.toList());
    await _p.setInt('settings_t', DateTime.now().millisecondsSinceEpoch);
    persoTick.value++;
  }

  // ---- sport : équipes suivies (noms affichés par la source des matchs), synchronisées
  static List<String> get sportTeams => _p.getStringList('sport_teams') ?? const [];
  static Future<void> setSportTeams(List<String> v) async {
    await _p.setStringList('sport_teams', v);
    await _p.setInt('settings_t', DateTime.now().millisecondsSinceEpoch);
    persoTick.value++;
  }

  // ---- dernières recherches
  static List<String> recentSearches() => _p.getStringList('recent_q') ?? const [];
  static Future<void> addRecentSearch(String q) async {
    final t = q.trim();
    if (t.length < 2) return;
    final l = [t, for (final x in recentSearches()) if (x.toLowerCase() != t.toLowerCase()) x];
    await _p.setStringList('recent_q', l.take(8).toList());
  }

  static Future<void> clearRecentSearches() => _p.remove('recent_q');

  static bool flag(String k, [bool def = true]) => _p.getBool('f_$k') ?? def;
  static Future<void> setFlag(String k, bool v) async {
    await _p.setBool('f_$k', v);
    if (_setFlagKeys.contains(k)) await _p.setInt('settings_t', DateTime.now().millisecondsSinceEpoch);
  }

  static bool get hasSelection => Kind.values.any((k) => (selection(k) ?? []).isNotEmpty);

  static Future<Directory> _catDir() async => Directory('${(await getApplicationSupportDirectory()).path}/cats${_active.isEmpty ? '' : '_$_active'}');

  /// catalogue en cache, par catégorie : id → (date en ms, éléments), même ancien ; lu dans un isolat
  static Future<Map<String, (int, List<Item>)>> cachedCats(Kind k, List<String> ids) async {
    if (kIsWeb || ids.isEmpty) return {};
    try {
      return await compute(readCats, ((await _catDir()).path, k, ids));
    } catch (_) {
      return {};
    }
  }

  static Future<void> cacheCat(Kind k, String cid, String json) async {
    if (kIsWeb) return;
    try {
      final d = await _catDir();
      await d.create(recursive: true);
      await File('${d.path}/${k.name}_${catFile(cid)}.json').writeAsString(json, flush: true);
    } catch (_) {}
  }

  /// efface le catalogue en cache (listes et studios) ; les réglages restent
  static Future<void> clearCatalog() async {
    if (kIsWeb) return;
    try {
      final sup = (await getApplicationSupportDirectory()).path;
      final d = await _catDir();
      if (await d.exists()) await d.delete(recursive: true);
      for (final k in Kind.values) {
        for (final f in [File('$sup/cat2_${k.name}.json'), File('$sup/${pre}studios_${k.name}.json')]) {
          if (await f.exists()) await f.delete();
        }
      }
    } catch (_) {}
    await _p.remove('${pre}cat_t');
  }

  /// place occupée par le catalogue en cache (octets)
  static Future<int> catalogBytes() async {
    if (kIsWeb) return 0;
    return dirBytes(await _catDir());
  }

  /// cache des affiches et logos (cached_network_image : dossier temporaire « libCachedImageData »)
  static Future<int> imageBytes() async {
    if (kIsWeb) return 0;
    return dirBytes(Directory('${(await getTemporaryDirectory()).path}/${DefaultCacheManager.key}'));
  }
  static Future<void> clearImages() async {
    try {
      await DefaultCacheManager().emptyCache();
    } catch (_) {}
  }
}

/// taille d'un dossier (octets) ; 0 s'il n'existe pas
Future<int> dirBytes(Directory d) async {
  var n = 0;
  try {
    if (!await d.exists()) return 0;
    await for (final f in d.list(recursive: true, followLinks: false)) {
      if (f is File) n += await f.length();
    }
  } catch (_) {}
  return n;
}

/// « 1,2 Go », « 340 Mo »
String sizeLabel(int b) {
  if (b >= 1 << 30) return '${(b / (1 << 30)).toStringAsFixed(1).replaceAll('.', ',')} Go';
  if (b >= 1 << 20) return '${(b / (1 << 20)).round()} Mo';
  if (b >= 1 << 10) return '${(b / (1 << 10)).round()} Ko';
  return '$b o';
}

String catFile(String cid) {
  final s = cid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  if (s == cid) return s;
  var h = 0;     // noms de groupe (playlist M3U) : le suffixe évite que deux noms différents donnent le même fichier
  for (final u in cid.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return '${s}_$h';
}

/// lecture du cache (dans un isolat) : seulement les catégories demandées
Map<String, (int, List<Item>)> readCats((String, Kind, List<String>) a) {
  final (dir, k, ids) = a;
  final out = <String, (int, List<Item>)>{};
  for (final cid in ids) {
    final f = File('$dir/${k.name}_${catFile(cid)}.json');
    try {
      if (!f.existsSync()) continue;
      out[cid] = (f.lastModifiedSync().millisecondsSinceEpoch, [for (final x in jsonDecode(f.readAsStringSync()) as List) Item.fromJson(x as Map<String, dynamic>)]);
    } catch (_) {}
  }
  if (out.isEmpty) {
    // ancien cache (un seul fichier par type) : repris une fois, découpé par catégorie, avec sa date d'origine
    final old = File('${Directory(dir).parent.path}/cat2_${k.name}.json');
    if (!dir.endsWith('/cats')) return out;      // seule la source d'origine reprend l'ancien cache
    try {
      if (old.existsSync()) {
        final t = old.lastModifiedSync();
        final by = <String, List<Item>>{};
        for (final x in jsonDecode(old.readAsStringSync()) as List) {
          final i = Item.fromJson(x as Map<String, dynamic>);
          if (ids.contains(i.catId)) (by[i.catId] ??= []).add(i);
        }
        Directory(dir).createSync(recursive: true);
        for (final e in by.entries) {
          final f = File('$dir/${k.name}_${catFile(e.key)}.json')..writeAsStringSync(jsonEncode([for (final i in e.value) i.toJson()]));
          f.setLastModifiedSync(t);
          out[e.key] = (t.millisecondsSinceEpoch, e.value);
        }
        old.deleteSync();
      }
    } catch (_) {}
  }
  return out;
}

/// position de lecture d'un film ou d'un épisode
class Prog {
  final String kind;          // 'vod' ou 'ep'
  final int id, sid;          // sid : série (épisodes)
  final String ext, name, icon, sname;
  int pos, dur, t;
  bool hidden;
  Prog({required this.kind, required this.id, this.sid = 0, required this.ext, required this.name, required this.icon, this.sname = '', this.pos = 0, this.dur = 0, int? t, this.hidden = false}) : t = t ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
  String get key => '$kind:$id';
  Map<String, dynamic> toJson() => {'k': kind, 'id': id, 'sid': sid, 'e': ext, 'n': name, 'i': icon, 'sn': sname, 'p': pos, 'd': dur, 't': t, 'h': hidden};
  factory Prog.fromJson(Map<String, dynamic> j) => Prog(kind: j['k'] as String, id: j['id'] as int, sid: (j['sid'] as num?)?.toInt() ?? 0, ext: j['e'] as String, name: j['n'] as String, icon: j['i'] as String,
      sname: (j['sn'] as String?) ?? '', pos: (j['p'] as num).toInt(), dur: (j['d'] as num).toInt(), t: (j['t'] as num).toInt(), hidden: j['h'] == true);
}
