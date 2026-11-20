import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' hide Text;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'names.dart';
import 'store.dart';
import 'tmdb.dart';
import 'osk.dart';
import 'ui.dart';
import 'xtream.dart';

/// ---------- « Ce soir, on regarde quoi ? » : 3 idées selon l'heure et tes habitudes ----------
List<(Item, String)> tonight(Lib? vl, Lib? sl) {
  final seen = <String>{for (final p in Store.allProg()) p.kind == 'ep' ? 'series:${p.sid}' : 'vod:${p.id}'};
  final liked = {...Store.favs, ...seen};
  final cats = <String>{
    for (final l in [vl, sl])
      if (l != null) for (final i in l.rows) if (liked.contains('${i.kind.name}:${i.id}')) i.catId
  };
  final n = DateTime.now();
  final rnd = Random(n.year * 1000 + n.month * 40 + n.day * 4 + n.hour ~/ 6);
  Item? pick(List<Item> l) => l.isEmpty ? null : l[rnd.nextInt(min(l.length, 18))];
  List<Item> good(Lib? lib) => [
        if (lib != null)
          for (final i in lib.rows)
            if (i.icon.isNotEmpty && i.rating > 6.4 && i.rating < 9.5 && !seen.contains('${i.kind.name}:${i.id}')) i
      ];
  final fg = good(vl)..sort((a, b) => b.rating.compareTo(a.rating));
  final sg = good(sl)..sort((a, b) => b.rating.compareTo(a.rating));
  final out = <(Item, String)>[];
  void add(Item? i, String why) {
    if (i != null && !out.any((o) => o.$1.id == i.id && o.$1.kind == i.kind)) out.add((i, why));
  }
  final taste = fg.where((i) => cats.contains(i.catId)).toList();
  if (taste.isNotEmpty) {
    add(pick(taste), 'Dans vos goûts');
  } else {
    add(pick(fg), 'Très bien noté');
  }
  add(pick(fg.where((i) => i.isNew).toList()), 'Nouveauté');
  add(pick(sg), 'Série à suivre');
  add(pick(fg), 'Très bien noté');
  return out.take(3).toList();
}

String tonightTitle() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Ce matin, on regarde quoi ?' : (h < 18 ? 'Cet après-midi, on regarde quoi ?' : 'Ce soir, on regarde quoi ?');
}

/// ---------- calendrier : prochain épisode des séries suivies ----------
class Soon {
  final Item it;
  final DateTime date;
  final int season, ep;
  Soon(this.it, this.date, this.season, this.ep);
  String get when {
    final t = DateTime.now();
    final d0 = DateTime(t.year, t.month, t.day);
    final days = DateTime(date.year, date.month, date.day).difference(d0).inDays;
    if (days <= 0) return 'Aujourd\'hui';
    if (days == 1) return 'Demain';
    const j = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
    const m = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
    return '${j[date.weekday - 1]} ${date.day} ${m[date.month - 1]}';
  }
}

class Calendar {
  static final _c = <int, Future<Soon?>>{};

  static void reset() {
    _c.clear();
    _l = null;
    _sig = '';
  }

  static Future<List<Soon>>? _l;
  static String _sig = '';

  static Future<List<Soon>> of(Lib? sl) {
    if (sl == null) return Future.value([]);
    final sig = '${sl.rows.length}${Store.favs.where((k) => k.startsWith('series:')).join()}${Store.allProg().where((p) => p.kind == 'ep').map((p) => p.sid).toSet().join(',')}';
    if (sig != _sig || _l == null) {
      _sig = sig;
      _l = _build(sl);
    }
    return _l!;
  }

  static Future<List<Soon>> _build(Lib sl) async {
    final ids = <int>{
      for (final k in Store.favs) if (k.startsWith('series:')) int.tryParse(k.substring(7)) ?? 0,
      for (final p in Store.allProg()) if (p.kind == 'ep') p.sid,
    };
    final l = sl.rows.where((i) => ids.contains(i.id)).take(14).toList();
    final r = await Future.wait([for (final i in l) _c.putIfAbsent(i.id, () => _one(i))]);
    return r.whereType<Soon>().toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  static Future<Soon?> _one(Item i) async {
    try {
      final q = await Tmdb.raw('/search/tv', {'query': i.title, 'language': L.tmdb});
      final res = (q['results'] as List?) ?? const [];
      if (res.isEmpty) return null;
      final d = await Tmdb.raw('/tv/${res.first['id']}', {'language': L.tmdb});
      final n = d['next_episode_to_air'];
      if (n == null) return null;
      final dt = DateTime.tryParse('${n['air_date']}');
      if (dt == null) return null;
      return Soon(i, dt, (n['season_number'] as num?)?.toInt() ?? 0, (n['episode_number'] as num?)?.toInt() ?? 0);
    } catch (_) {
      return null;
    }
  }
}

class SoonCard extends StatelessWidget {
  final Soon s;
  final VoidCallback onTap;
  const SoonCard({super.key, required this.s, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 270,
        child: FocusCard(
          onTap: onTap,
          radius: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0xB8161B26), border: Border.all(color: const Color(0x1FFFFFFF), width: 0.8)),
            child: Row(children: [
              SizedBox(width: 56, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: AspectRatio(aspectRatio: 2 / 3, child: netImage(s.it.icon, s.it.title)))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(15, w: 700, h: 1.2)),
                  const SizedBox(height: 4),
                  Text('S${s.season}E${s.ep}', style: T(13, w: 600, color: kMut)),
                  const SizedBox(height: 6),
                  Text(s.when, style: T(13.5, w: 700, color: kAccent)),
                ]),
              ),
            ]),
          ),
        ),
      );
}

/// ---------- playlists perso (anciennement « collections ») ----------
Future<void> collectionSheet(BuildContext context, String key) async {
  await appSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CollSheet(itemKey: key));
}

class _CollSheet extends StatefulWidget {
  final String itemKey;
  const _CollSheet({required this.itemKey});
  @override
  State<_CollSheet> createState() => _CollSheetState();
}

class _CollSheetState extends State<_CollSheet> {
  late Map<String, List<String>> m = Store.colls;
  final c = TextEditingController();

  Future<void> _toggle(String name, bool on) async {
    final l = m.putIfAbsent(name, () => []);
    on ? (l.contains(widget.itemKey) ? null : l.add(widget.itemKey)) : l.remove(widget.itemKey);
    await Store.saveColls(m);
    setState(() {});
  }

  Future<void> _new() async {
    final n = c.text.trim();
    if (n.isEmpty) return;
    c.clear();
    await _toggle(n, true);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ajouter à…', style: T(20, w: 750)),
          const SizedBox(height: 6),
          // Ma liste : le titre apparaît aussi sur l'accueil, avec les playlists
          ListTile(
            autofocus: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Store.isFav(widget.itemKey) ? CupertinoIcons.bookmark_fill : CupertinoIcons.bookmark),
            title: Text('Ma liste', style: T(16, w: 650)),
            onTap: () async {
              await Store.toggleFav(widget.itemKey);
              if (mounted) setState(() {});
            },
            trailing: ExcludeFocus(child: IgnorePointer(child: Switch(value: Store.isFav(widget.itemKey), onChanged: (_) {}))),
          ),
          const Divider(height: 18, color: Color(0x1FFFFFFF)),
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('PLAYLISTS', style: T(12, w: 700, ls: 0.09, color: kMut))),
          for (final e in m.entries)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: e.value.contains(widget.itemKey),
              onChanged: (v) => _toggle(e.key, v == true),
              title: Text(e.key, style: T(16, w: 600)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          AppField(controller: c, onSubmitted: (_) => _new(), decoration: InputDecoration(hintText: 'Nouvelle playlist (Soirée Marvel…)', suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _new))),
        ]),
      );
}

/// page d'une playlist : titres, mode « Modifier » pour en retirer, renommer ou supprimer la playlist
class PlaylistScreen extends StatefulWidget {
  final String name;
  final List<Item> all;
  final void Function(Item) onOpen;
  const PlaylistScreen({super.key, required this.name, required this.all, required this.onOpen});
  @override
  State<PlaylistScreen> createState() => _PlaylistState();
}

class _PlaylistState extends State<PlaylistScreen> {
  late String name = widget.name;
  bool edit = false;

  Future<String?> _ask(String title, String init) {
    final c = TextEditingController(text: init);
    return showDialog<String>(
      context: context,
      builder: (_) => AppDialog(
        backgroundColor: kBg2,
        title: Text(title, style: T(18, w: 700)),
        content: AppField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences, onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _remove(Item it) async {
    await Store.removeFromColl(name, '${it.kind.name}:${it.id}');
    if (mounted) setState(() {});
  }

  Future<void> _menu() async {
    final r = await appSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          ListTile(autofocus: true, leading: const Icon(CupertinoIcons.pencil), title: const Text('Renommer la playlist'), onTap: () => Navigator.pop(context, 'name')),
          ListTile(leading: const Icon(CupertinoIcons.trash, color: Color(0xFFFF6B7A)), title: const Text('Supprimer la playlist', style: TextStyle(color: Color(0xFFFF6B7A))), onTap: () => Navigator.pop(context, 'del')),
          const SizedBox(height: 8),
        ]),
      ));
    if (!mounted || r == null) return;
    if (r == 'name') {
      final n = await _ask('Nom de la playlist', name);
      if (n != null && n.trim().isNotEmpty && n.trim() != name) {
        await Store.renameColl(name, n);
        if (mounted) setState(() => name = n.trim());
      }
    } else if (r == 'del') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AppDialog(
          backgroundColor: kBg2,
          title: Text('Supprimer « $name » ?', style: T(18, w: 700)),
          content: const Text('Seule la playlist est supprimée : les films et séries restent dans ton catalogue.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Color(0xFFFF6B7A))))],
        ),
      );
      if (ok == true) {
        await Store.deleteColl(name);
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = Store.colls[name] ?? const <String>[];
    final items = [for (final r in widget.all) if (keys.contains('${r.kind.name}:${r.id}')) r];
    final w = isWide(context) ? 170.0 : 118.0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(22, w: 750, ls: -0.03)),
        actions: [
          if (items.isNotEmpty) TextButton(onPressed: () => setState(() => edit = !edit), child: Text(edit ? 'Terminé' : 'Modifier')),
          IconButton(tooltip: 'Plus', icon: const Icon(CupertinoIcons.ellipsis), onPressed: _menu),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(icon: Icons.playlist_add_rounded, title: 'Playlist vide', sub: 'Sur la fiche d\'un film ou d\'une série, « + » puis coche cette playlist. Tu peux aussi la supprimer avec « ⋯ ».')
          : CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(edit ? 'Touche un titre pour le retirer de la playlist.' : '${items.length} titre${items.length > 1 ? 's' : ''} · appui long sur un titre pour le retirer', style: T(13, color: edit ? kAccent : kMut)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: w + 14, mainAxisExtent: w * 1.5 + 52, mainAxisSpacing: 12, crossAxisSpacing: 12),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Poster(
                      item: items[i],
                      width: w,
                      badge: edit ? Container(width: 30, height: 30, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE5484D)), child: const Icon(CupertinoIcons.minus, size: 18, color: Colors.white)) : null,
                      onTap: () => edit ? _remove(items[i]) : widget.onOpen(items[i]),
                      onLong: () => _remove(items[i]),
                    ),
                    childCount: items.length,
                  ),
                ),
              ),
            ]),
    );
  }
}

/// ---------- films téléchargés (lecture hors ligne) ----------
class Dl {
  final String key, name, icon, path;
  Dl(this.key, this.name, this.icon, this.path);
  Map<String, dynamic> toJson() => {'k': key, 'n': name, 'i': icon, 'p': path};
}

class Downloads {
  static final progress = ValueNotifier<Map<String, double>>({});
  static final _cl = <String, http.Client>{};

  static String _dir = '';

  /// dossier actuel des téléchargements : sur iOS, le chemin de l'appli change à chaque mise à jour
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      _dir = '${(await getApplicationDocumentsDirectory()).path}/dl';
    } catch (_) {}
  }

  static String _here(String p) => File(p).existsSync() || _dir.isEmpty ? p : '$_dir/${p.split('/').last}';

  static List<Dl> all() {
    try {
      return [for (final x in jsonDecode(Store.str('dls').isEmpty ? '[]' : Store.str('dls')) as List) Dl('${x['k']}', '${x['n']}', '${x['i']}', _here('${x['p']}'))].where((d) => File(d.path).existsSync()).toList();
    } catch (_) {
      return [];
    }
  }

  static Dl? get(String key) => all().where((d) => d.key == key).firstOrNull;

  /// taille du fichier (octets)
  static int bytes(Dl d) {
    try {
      return File(d.path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  static void _set(String key, double? v) {
    final m = {...progress.value};
    v == null ? m.remove(key) : m[key] = v;
    progress.value = m;
  }

  static Future<void> start(String key, String url, String name, String icon, String ext) async {
    if (progress.value.containsKey(key)) return;
    _set(key, 0);
    File? f;
    IOSink? sink;
    try {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/dl');
      await dir.create(recursive: true);
      f = File('${dir.path}/${key.replaceAll(':', '_')}.${ext.isEmpty ? 'mp4' : ext}');
      final c = http.Client();
      _cl[key] = c;
      final r = await c.send(http.Request('GET', Uri.parse(url))).timeout(const Duration(seconds: 30));
      if (r.statusCode != 200) throw Exception('http ${r.statusCode}');
      final total = r.contentLength ?? 0;
      var got = 0;
      var last = 0.0;
      final out = sink = f.openWrite();
      await for (final b in r.stream) {
        out.add(b);
        got += b.length;
        if (total > 0 && got / total - last > 0.01) {
          last = got / total;
          _set(key, last);
        }
      }
      await out.close();
      sink = null;
      final l = [...all().where((d) => d.key != key), Dl(key, name, icon, f.path)];
      await Store.setStr('dls', jsonEncode([for (final d in l) d.toJson()]));
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        await f?.delete();
      } catch (_) {}
    } finally {
      _cl.remove(key)?.close();
      _set(key, null);
    }
  }

  static void cancel(String key) => _cl[key]?.close();

  static Future<void> remove(String key) async {
    final l = all();
    for (final d in l.where((d) => d.key == key)) {
      try {
        await File(d.path).delete();
      } catch (_) {}
    }
    await Store.setStr('dls', jsonEncode([for (final d in l.where((d) => d.key != key)) d.toJson()]));
    _set(key, null);
  }
}
