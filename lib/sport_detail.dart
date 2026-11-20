import 'package:flutter/material.dart' hide Text;
import 'sport.dart';
import 'ui.dart';

/// événement terminé : statistiques et temps forts d'un match, classement d'une course, résultats d'une soirée de combats
class EvDetailScreen extends StatefulWidget {
  final Ev e;
  const EvDetailScreen({super.key, required this.e});
  @override
  State<EvDetailScreen> createState() => _EvDetailState();
}

class _EvDetailState extends State<EvDetailScreen> {
  late final Future<List<Widget>> body = _load();

  Widget _row(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FocusCard(radius: 14, focusScale: 1.0, onTap: () {}, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), color: const Color(0x14FFFFFF), child: child)),
      );

  Widget _title(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 8), child: Text(t.toUpperCase(), style: T(12, w: 800, color: kMut, ls: 0.12)));

  Future<List<Widget>> _load() async {
    final e = widget.e;
    final l = lgOf(e.lg);
    final parts = e.id.split(':');
    final id = parts.length > 1 ? parts[1] : '';
    final out = <Widget>[];
    try {
      if (e.f1) {
        final y = DateTime.fromMillisecondsSinceEpoch(e.ts * 1000).year;
        final d = await espnJson('https://site.api.espn.com/apis/site/v2/sports/${l.espn}/scoreboard?dates=$y');
        final ev = (d['events'] as List).cast<Map>().firstWhere((x) => '${x['id']}' == id);
        final c = (ev['competitions'] as List).cast<Map>().firstWhere((x) => '${x['type']?['abbreviation']}' == (parts.length > 2 ? parts[2] : 'Race'));
        final cs = ((c['competitors'] as List?) ?? []).cast<Map>().toList()..sort((a, b) => ((a['order'] as num?) ?? 99).compareTo((b['order'] as num?) ?? 99));
        out.add(_title('Classement'));
        for (final x in cs) {
          final a = (x['athlete'] ?? {}) as Map;
          out.add(_row(Row(children: [
            SizedBox(width: 34, child: Text('${x['order'] ?? ''}', style: T(16, w: 800, color: x['order'] == 1 ? const Color(0xFFFFC857) : kMut))),
            evLogo('${(a['flag'] ?? {})['href'] ?? ''}', s: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('${a['displayName'] ?? a['fullName'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T(15.5, w: x['order'] == 1 ? 800 : 600))),
          ])));
        }
      } else if (e.lg == 'ufc') {
        final y = DateTime.fromMillisecondsSinceEpoch(e.ts * 1000).year;
        final d = await espnJson('https://site.api.espn.com/apis/site/v2/sports/${l.espn}/scoreboard?dates=$y');
        final ev = (d['events'] as List).cast<Map>().firstWhere((x) => '${x['id']}' == id);
        out.add(_title('Résultats de la soirée'));
        for (final c in (ev['competitions'] as List).cast<Map>().reversed) {
          final fs = ((c['competitors'] as List?) ?? []).cast<Map>();
          if (fs.length < 2) continue;
          String nm(Map x) => '${((x['athlete'] ?? {}) as Map)['displayName'] ?? '?'}';
          final cat = '${c['type']?['abbreviation'] ?? ''}';
          out.add(_row(Row(children: [
            Expanded(child: Text(nm(fs[0]) + (fs[0]['winner'] == true ? '  ✓' : ''), style: T(14.5, w: fs[0]['winner'] == true ? 800 : 500, color: fs[0]['winner'] == true ? kText : kMut))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(cat, textAlign: TextAlign.center, style: T(11, color: kMut))),
            Expanded(child: Text((fs[1]['winner'] == true ? '✓  ' : '') + nm(fs[1]), textAlign: TextAlign.right, style: T(14.5, w: fs[1]['winner'] == true ? 800 : 500, color: fs[1]['winner'] == true ? kText : kMut))),
          ])));
        }
      } else {
        final d = await espnJson('https://site.api.espn.com/apis/site/v2/sports/${l.espn}/summary?event=$id');
        final teams = ((d['boxscore']?['teams'] as List?) ?? []).cast<Map>();
        final keys = ((d['keyEvents'] as List?) ?? []).cast<Map>().where((k) => k['scoringPlay'] == true || '${k['type']?['type']}'.contains('card')).toList();
        if (keys.isNotEmpty) {
          out.add(_title('Temps forts'));
          for (final k in keys.take(20)) {
            final goal = k['scoringPlay'] == true;
            out.add(_row(Row(children: [
              SizedBox(width: 56, child: Text('${k['clock']?['displayValue'] ?? ''}', style: T(14, w: 700, color: kMut))),
              Text(goal ? '⚽ ' : '${k['type']?['type']}'.contains('red') ? '🟥 ' : '🟨 '),
              Expanded(child: Text('${k['shortText'] ?? k['text'] ?? k['type']?['text'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: T(14.5, w: goal ? 700 : 500))),
            ])));
          }
        }
        if (teams.length >= 2) {
          out.add(_title('Statistiques'));
          final a = (teams[0]['statistics'] as List? ?? []).cast<Map>(), b = (teams[1]['statistics'] as List? ?? []).cast<Map>();
          for (var i = 0; i < a.length && i < 16; i++) {
            final lab = '${a[i]['label'] ?? a[i]['name'] ?? ''}';
            final bv = b.firstWhere((x) => x['name'] == a[i]['name'], orElse: () => const {})['displayValue'] ?? '';
            out.add(_row(Row(children: [
              SizedBox(width: 70, child: Text('${a[i]['displayValue'] ?? ''}', style: T(16, w: 800))),
              Expanded(child: Text(lab, textAlign: TextAlign.center, style: T(13.5, color: kMut))),
              SizedBox(width: 70, child: Text('$bv', textAlign: TextAlign.right, style: T(16, w: 800))),
            ])));
          }
        }
      }
    } catch (_) {}
    if (out.isEmpty) out.add(Padding(padding: const EdgeInsets.all(24), child: Text('Détails indisponibles pour cet événement.', textAlign: TextAlign.center, style: T(15, color: kMut))));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    return DsBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FutureBuilder<List<Widget>>(
          future: body,
          builder: (ctx, sn) => LargeTitle(
            title: e.f1 ? '${e.h.short} · ${e.a.short}' : '${e.h.short} – ${e.a.short}',
            onBack: () => Navigator.pop(ctx),
            children: [
              Padding(padding: const EdgeInsets.only(bottom: 4), child: EvScoreboard(e: e, crest: 64, scoreSize: 44)),
              if (!sn.hasData) const Padding(padding: EdgeInsets.all(40), child: Center(child: Spinner())) else ...sn.data!,
            ],
          ),
        ),
      ),
    );
  }
}
