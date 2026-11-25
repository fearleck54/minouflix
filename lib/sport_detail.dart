import 'dart:ui' show FontFeature;
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
  late final Future<Map<String, List<Widget>>> body = _load();
  String _tab = '';

  Widget _row(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FocusCard(radius: 14, focusScale: 1.0, onTap: () {}, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11), color: const Color(0x14FFFFFF), child: child)),
      );

  Widget _title(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 8), child: Text(t.toUpperCase(), style: T(12, w: 800, color: kMut, ls: 0.12)));

  static double? _num(Object? v) => double.tryParse('${v ?? ''}'.replaceAll('%', '').replaceAll(',', '.').trim());

  /// événement de la chronologie : à gauche pour l'équipe à domicile, à droite pour l'extérieur, teinté aux couleurs du club
  Widget _ev(bool away, String clock, String icon, String txt, bool goal, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: away ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: 0.88,
            child: FocusCard(
              radius: 14,
              focusScale: 1.0,
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(color: c.withOpacity(0.16), border: Border(left: away ? BorderSide.none : BorderSide(color: c, width: 4), right: away ? BorderSide(color: c, width: 4) : BorderSide.none)),
                child: Row(textDirection: away ? TextDirection.rtl : TextDirection.ltr, children: [
                  Text(clock, style: T(14, w: 800, color: kMut).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                  const SizedBox(width: 10),
                  Text(icon),
                  const SizedBox(width: 10),
                  Expanded(child: Text(txt, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: away ? TextAlign.right : TextAlign.left, style: T(14.5, w: goal ? 800 : 550))),
                ]),
              ),
            ),
          ),
        );

  /// statistique comparée : valeurs aux deux bouts, barre coupée en deux aux couleurs des clubs
  Widget _stat(String lab, String va, String vb, Color c1, Color c2) {
    final a = _num(va) ?? 0, b = _num(vb) ?? 0;
    final fa = a + b <= 0 ? 1 : (a / (a + b) * 100).round().clamp(1, 99), fb = a + b <= 0 ? 1 : 100 - (a / (a + b) * 100).round().clamp(1, 99);
    const tab = [FontFeature.tabularFigures()];
    return _row(Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        SizedBox(width: 74, child: Text(va, style: T(17, w: 850).copyWith(fontFeatures: tab))),
        Expanded(child: Text(lab, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(13.5, color: kMut))),
        SizedBox(width: 74, child: Text(vb, textAlign: TextAlign.right, style: T(17, w: 850).copyWith(fontFeatures: tab))),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(height: 6, child: Row(children: [Expanded(flex: fa, child: ColoredBox(color: c1)), const SizedBox(width: 3), Expanded(flex: fb, child: ColoredBox(color: c2))])),
      ),
    ]));
  }

  Future<Map<String, List<Widget>>> _load() async {
    final e = widget.e;
    final l = lgOf(e.lg);
    final parts = e.id.split(':');
    final id = parts.length > 1 ? parts[1] : '';
    final out = <Widget>[], stats = <Widget>[];
    final (c1, c2) = evColors(e);
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
          final away = e.a.name.toLowerCase();
          for (final k in keys.take(24)) {
            final goal = k['scoringPlay'] == true;
            final ty = '${k['type']?['type']}';
            final tn = '${k['team']?['displayName'] ?? ''}'.toLowerCase();
            final isAway = tn.isNotEmpty && tn == away;
            out.add(_ev(isAway, '${k['clock']?['displayValue'] ?? ''}', goal ? '⚽' : ty.contains('red') ? '🟥' : '🟨', '${k['shortText'] ?? k['text'] ?? k['type']?['text'] ?? ''}', goal, isAway ? c2 : c1));
          }
        }
        if (teams.length >= 2) {
          final a = (teams[0]['statistics'] as List? ?? []).cast<Map>(), b = (teams[1]['statistics'] as List? ?? []).cast<Map>();
          // l'ordre des équipes d'ESPN n'est pas toujours domicile / extérieur : on aligne sur le nom
          final swap = '${teams[0]['team']?['displayName'] ?? ''}'.toLowerCase() == e.a.name.toLowerCase();
          final l1 = swap ? b : a, l2 = swap ? a : b;
          for (var i = 0; i < l1.length && i < 16; i++) {
            final lab = '${l1[i]['label'] ?? l1[i]['name'] ?? ''}';
            final bv = l2.firstWhere((x) => x['name'] == l1[i]['name'], orElse: () => const {})['displayValue'] ?? '';
            stats.add(_stat(lab, '${l1[i]['displayValue'] ?? ''}', '$bv', c1, c2));
          }
        }
      }
    } catch (_) {}
    if (out.isEmpty && stats.isEmpty) out.add(Padding(padding: const EdgeInsets.all(24), child: Text('Détails indisponibles pour cet événement.', textAlign: TextAlign.center, style: T(15, color: kMut))));
    return {if (out.isNotEmpty) 'Résumé': out, if (stats.isNotEmpty) 'Statistiques': stats};
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final c0 = evColors(e);
    return DsBg(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: FutureBuilder<Map<String, List<Widget>>>(
          future: body,
          builder: (ctx, sn) {
            final m = sn.data;
            final tabs = m?.keys.toList() ?? const <String>[];
            final cur = tabs.contains(_tab) ? _tab : (tabs.isEmpty ? '' : tabs.first);
            return LargeTitle(
              title: e.f1 ? '${e.h.short} · ${e.a.short}' : '${e.h.short} – ${e.a.short}',
              onBack: () => Navigator.pop(ctx),
              children: [
                // en-tête : halos aux couleurs des deux clubs, score géant
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: RadialGradient(center: const Alignment(-1.0, 0), radius: 1.1, colors: [c0.$1.withOpacity(Perf.lite ? 0.16 : 0.34), Colors.transparent]),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: RadialGradient(center: const Alignment(1.0, 0), radius: 1.1, colors: [c0.$2.withOpacity(Perf.lite ? 0.14 : 0.30), Colors.transparent])),
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: EvScoreboard(e: e, crest: 72, scoreSize: 56)),
                  ),
                ),
                if (tabs.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                    child: Row(children: [
                      for (final t in tabs)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: FocusCard(
                            radius: 99,
                            onTap: () => setState(() => _tab = t),
                            child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), color: t == cur ? Colors.white : const Color(0x1FFFFFFF), child: Text(t, style: T(14, w: 750, color: t == cur ? kBg : kText))),
                          ),
                        ),
                    ]),
                  ),
                if (m == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: Spinner())) else ...?m[cur],
              ],
            );
          },
        ),
      ),
    );
  }
}
