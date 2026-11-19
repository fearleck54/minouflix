import 'package:flutter/material.dart' hide Text;
import 'epg.dart';
import 'names.dart';
import 'sport.dart';
import 'store.dart';
import 'ui.dart';

/// une chaîne proposée pour un match, avec la raison (programme du guide ou chaîne habituelle de la compétition)
class WatchPick {
  final Chan c;
  final String why;
  final int score;
  const WatchPick(this.c, this.why, this.score);
}

Set<String> _tokens(Side s) {
  final out = <String>{};
  for (final t in [s.short, s.name]) {
    for (final w in norm(t).split(RegExp(r'[^a-z0-9]+'))) {
      if (w.length >= 4 && !const {'football', 'club', 'stade', 'rugby', 'sporting', 'olympique', 'association'}.contains(w)) out.add(w);
    }
  }
  return out;
}

final _progCache = <String, (DateTime, List<List<Object>>)>{};      // guide déjà lu pendant les 10 dernières minutes

Future<List<List<Object>>> _progs(Chan c) async {
  final hit = _progCache[c.key];
  if (hit != null && DateTime.now().difference(hit.$1) < const Duration(minutes: 10)) return hit.$2;
  List<List<Object>> out = [...Epg.programs(c.epgId)];      // guide déjà en mémoire : instantané
  final x = Epg.src;
  if (out.isEmpty && x != null) {
    try {
      out = await x.shortEpg(c.v.first.item.id).timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
  _progCache[c.key] = (DateTime.now(), out);
  return out;
}

/// Où voir ce match ? Pour chaque chaîne candidate (habituelles de la compétition + chaînes de sport), on lit son guide et on cherche les deux équipes
/// dans le titre du programme à l'heure du match : c'est la preuve la plus sûre. Sans preuve, on propose les chaînes habituelles de la compétition.
Future<List<WatchPick>> whereToWatch(Ev e, List<Chan> chans) async {
  final l = lgOf(e.lg);
  final pats = [for (final p in l.ch) RegExp(p)];
  final base = <Chan>[];
  for (final p in pats) {
    for (final c in chans) {
      if (p.hasMatch(norm(c.name)) && !base.contains(c)) base.add(c);
    }
  }
  final extra = [for (final c in chans) if (c.theme == 'sport' && !base.contains(c)) c].take(24).toList();
  final th = _tokens(e.h), ta = _tokens(e.a);
  final lgw = norm(l.n).split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 3 && !const {'ligue', 'cup', 'coupe', 'des', 'de'}.contains(w)).toSet();
  final fav = Store.str('lgch_${e.lg}');
  final out = <WatchPick>[];
  final deadline = DateTime.now().add(const Duration(seconds: 8));      // jamais plus de 8 s d'attente
  // lots : d'abord la chaîne choisie la dernière fois, puis les chaînes habituelles de la compétition, puis le reste du sport
  final favC = [for (final c in base) if (c.key == fav) c, for (final c in chans) if (c.key == fav && !base.contains(c)) c];
  final lots = <List<Chan>>[
    if (favC.isNotEmpty) favC,
    for (var i = 0; i < base.length; i += 8) [for (final c in base.skip(i).take(8)) if (!favC.contains(c)) c],
    for (var i = 0; i < extra.length; i += 8) extra.skip(i).take(8).toList(),
  ].where((x) => x.isNotEmpty).toList();
  for (final chunk in lots) {
    final res = await Future.wait([for (final c in chunk) _progs(c)]);
    for (var j = 0; j < chunk.length; j++) {
      var best = 0;
      var why = '';
      for (final p in res[j]) {
        final st = p[0] as int, en = p[1] as int, title = '${p[2]}';
        if (en < e.ts - 600 || st > e.ts + 7200) continue;      // pas à l'heure du match
        final n = norm(title);
        final hh = th.any(n.contains), aa = ta.any(n.contains);
        var sc = hh && aa ? 5 : (hh || aa ? 3 : 0);
        if (sc == 0 && lgw.any(n.contains)) sc = 1;
        if (sc > 0 && st <= e.ts + 900 && en > e.ts) sc += 1;
        if (sc > best) {
          best = sc;
          final t = DateTime.fromMillisecondsSinceEpoch(st * 1000);
          why = '$title · ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        }
      }
      final habit = base.contains(chunk[j]);
      if (best > 0 || habit) out.add(WatchPick(chunk[j], best > 0 ? why : 'Chaîne habituelle de ${l.n}', best));
    }
    if (out.any((p) => p.score >= 5) || DateTime.now().isAfter(deadline)) break;      // preuve sûre ou temps écoulé
  }
  out.sort((a, b) {
    final r = b.score.compareTo(a.score);
    if (r != 0) return r;
    final fa = a.c.key == fav ? 0 : 1, fb = b.c.key == fav ? 0 : 1;
    if (fa != fb) return fa.compareTo(fb);
    return base.indexOf(a.c).compareTo(base.indexOf(b.c));
  });
  return out.take(8).toList();
}

/// feuille « Où le voir » : la chaîne la plus probable en tête ; le choix est retenu pour cette compétition
Future<Chan?> showWatchSheet(BuildContext context, Ev e, List<WatchPick> picks) => appSheet<Chan>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 12, 8, 12), children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 2), child: Text('Où le voir ?', style: T(19, w: 750))),
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text('${e.h.short} – ${e.a.short}', style: T(14, color: kMut))),
          for (var i = 0; i < picks.length; i++)
            ListTile(
              autofocus: i == 0,
              leading: SizedBox(width: 44, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: AspectRatio(aspectRatio: 1, child: netImage(picks[i].c.icon, picks[i].c.name, fit: BoxFit.contain, w: 120)))),
              title: Row(children: [
                Flexible(child: Text(picks[i].c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(15.5, w: 650))),
                if (picks[i].score >= 5) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0x3330D158), borderRadius: BorderRadius.circular(99)), child: Text('Au guide', style: T(11, w: 700, color: const Color(0xFF30D158)))),
              ]),
              subtitle: Text(picks[i].why, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                Store.setStr('lgch_${e.lg}', picks[i].c.key);
                Navigator.pop(ctx, picks[i].c);
              },
            ),
        ]),
      ),
    );
