import 'store.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:http/http.dart' as http;
import 'names.dart';
import 'ui.dart';

/// Sport Center : matchs ESPN (public, sans clé), mêmes compétitions que l'appli web.
class League {
  final String k, n, espn;
  final bool def;
  final Color color;
  final List<String> ch;      // chaînes habituelles (motifs sur le nom normalisé)
  const League(this.k, this.n, this.espn, this.def, this.color, this.ch);
}

const leagues = [
  League('l1', 'Ligue 1', 'soccer/fra.1', true, Color(0xFF1552D8), [r'^ligue ?1\+', r'^bein sports 1$']),
  League('top14', 'Top 14', 'rugby/270559', true, Color(0xFFC0392B), [r'^canal\+ sport$', r'^canal\+$', r'^canal\+ sport 360$', r'^canal\+ live \d+$']),
  League('ucl', 'Ligue des champions', 'soccer/uefa.champions', true, Color(0xFF2A3BD6), [r'^canal\+ foot$', r'^canal\+$', r'^canal\+ sport$', r'^canal\+ live \d+$', r'^bein sports 1$']),
  League('el', 'Ligue Europa', 'soccer/uefa.europa', false, Color(0xFFD9641A), [r'^canal\+ foot$', r'^canal\+ sport$', r'^canal\+ live \d+$']),
  League('pl', 'Premier League', 'soccer/eng.1', false, Color(0xFF7C3AED), [r'^canal\+ premier league$', r'^canal\+ foot$', r'^canal\+ live \d+$']),
  League('liga', 'Liga', 'soccer/esp.1', false, Color(0xFFD92D3A), [r'^bein sports [123]$', r'^bein sports max']),
  League('l2', 'Ligue 2', 'soccer/fra.2', false, Color(0xFF0F8A7A), [r'^bein sports [12]$', r'^bein sports max']),
  League('f1', 'Formule 1', 'racing/f1', true, Color(0xFFE10600), [r'^canal\+ (formula|formule) ?1$', r'^canal\+ sport 360$', r'^canal\+ sport$', r'^canal\+$']),
  League('cc', 'Champions Cup (rugby)', 'rugby/271937', false, Color(0xFF0E8A55), [r'^bein sports [123]$', r'^france 2$']),
];

const _lgLogo = {'top14': 'asset:assets/clubs/lg-top14.webp', 'l1': 'asset:assets/clubs/lg-l1.png', 'ucl': 'https://a.espncdn.com/i/leaguelogos/soccer/500-dark/2.png', 'el': 'https://a.espncdn.com/i/leaguelogos/soccer/500-dark/2310.png', 'pl': 'https://a.espncdn.com/i/leaguelogos/soccer/500-dark/23.png', 'liga': 'https://a.espncdn.com/i/leaguelogos/soccer/500-dark/15.png', 'l2': 'https://a.espncdn.com/i/leaguelogos/soccer/500-dark/96.png', 'f1': 'https://a.espncdn.com/i/teamlogos/leagues/500/f1.png'};

String lgInit(String k) => k == 'top14' ? 'TOP 14' : k == 'cc' ? 'CC' : lgOf(k).n.split(RegExp(r'[ (]')).where((x) => x.length > 1).map((x) => x[0]).join().toUpperCase();

/// logo d'une compétition (ou ses initiales, comme l'appli web)
class LgIcon extends StatelessWidget {
  final String k;
  final double size;
  const LgIcon(this.k, {super.key, this.size = 20});
  @override
  Widget build(BuildContext context) {
    final u = _lgLogo[k];
    final fallback = Container(width: size, height: size, alignment: Alignment.center, child: Text(lgInit(k), textAlign: TextAlign.center, style: T(size * (k == 'top14' ? 0.34 : 0.42), w: 800, h: 1)));
    if (u == null) return fallback;
    Widget im = u.startsWith('asset:') ? Image.asset(u.substring(6), width: size, height: size, fit: BoxFit.contain) : CachedNetworkImage(imageUrl: u, width: size, height: size, fit: BoxFit.contain, errorWidget: (_, __, ___) => fallback);
    if (k == 'l1') im = ColorFiltered(colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn), child: im);
    return SizedBox(width: size, height: size, child: k == 'top14' ? ClipRRect(borderRadius: BorderRadius.circular(size * 0.22), child: im) : im);
  }
}

League lgOf(String k) => leagues.firstWhere((l) => l.k == k);

/// compétitions connues seulement (une clé inconnue, venue d'une autre version par la synchro, ferait tout échouer)
List<String> knownLeagues(Iterable<String> keys) => [for (final k in keys) if (leagues.any((l) => l.k == k)) k];

const _f1Lab = {'FP1': 'Essais libres 1', 'FP2': 'Essais libres 2', 'FP3': 'Essais libres 3', 'Qual': 'Qualifications', 'Race': 'Course', 'SS': 'Qualif. sprint', 'SQ': 'Qualif. sprint', 'Sprint': 'Sprint', 'SR': 'Sprint'};

class Side {
  final String name, short, logo;
  final String? score;
  const Side(this.name, this.short, this.logo, this.score);
}

class Ev {
  final String id, lg, st, det, lieu;
  final int ts;
  final Side h, a;
  final bool f1;
  const Ev(this.id, this.lg, this.ts, this.st, this.det, this.h, this.a, this.lieu, this.f1);
  bool get live => st == 'in';
  bool get post => st == 'post';
}

String _clubLogo(String name, String logo) {
  if (logo.isNotEmpty && !logo.contains('/countries/')) return logo;
  final n = name.toLowerCase();
  for (final c in const ['perpignan', 'bayonne', 'vannes']) {
    if (n.contains(c)) return 'asset:assets/clubs/$c.png';
  }
  return logo.contains('/countries/') ? '' : logo;
}

String _d(DateTime t) => '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';

Future<dynamic> _json(String url) async {
  final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
  if (r.statusCode != 200) throw Exception('http ${r.statusCode}');
  return jsonDecode(utf8.decode(r.bodyBytes));
}

Future<List<Ev>> fetchLeague(League l) async {
  final out = <Ev>[];
  final now = DateTime.now().toUtc();
  try {
    if (l.k == 'f1') {
      for (final y in {now.year, if (now.month >= 11) now.year + 1}) {
        try {
          final d = await _json('https://site.api.espn.com/apis/site/v2/sports/${l.espn}/scoreboard?dates=$y');
          for (final e in (d['events'] as List? ?? [])) {
            for (final c in (e['competitions'] as List? ?? [])) {
              final ab = (c['type']?['abbreviation'] ?? '?') as String;
              final st = (c['status']?['type'] ?? {}) as Map;
              final gp = '${e['shortName'] ?? e['name'] ?? ''}'.replaceFirst(RegExp(r'^.*? (?=[A-ZÉ][^ ]+ (Grand Prix|GP)$)'), '').trim();
              final lab = _f1Lab[ab] ?? ab;
              final win = (c['competitors'] as List? ?? []).cast<Map>().where((x) => x['winner'] == true).toList();
              out.add(Ev('f1:${e['id']}:$ab', 'f1', DateTime.parse('${c['date']}').millisecondsSinceEpoch ~/ 1000, '${st['state'] ?? 'pre'}', '${st['shortDetail'] ?? ''}',
                  Side('${e['name'] ?? gp}', gp, '', null), Side(lab, lab, '', st['state'] == 'post' && win.isNotEmpty ? '${win.first['athlete']?['shortName'] ?? ''}' : null),
                  '${e['circuit']?['fullName'] ?? ''}', true));
            }
          }
        } catch (_) {}
      }
    } else {
      // l'API n'accepte qu'un jour à la fois : hier jusqu'à +14 jours, puis plus loin si rien n'est prévu (pause du championnat)
      Future<void> scan(int from, int to) async {
        final days = await Future.wait([
          for (var i = from; i <= to; i++)
            _json('https://site.api.espn.com/apis/site/v2/sports/${l.espn}/scoreboard?dates=${_d(now.add(Duration(days: i)))}').then<dynamic>((v) => v).catchError((_) => null),
        ]);
        for (final d in days) {
          if (d == null) continue;
          for (final e in (d['events'] as List? ?? [])) {
            try {
              final c = (e['competitions'] as List).first as Map;
              final st = ((c['status'] ?? e['status'])?['type'] ?? {}) as Map;
              final t = <String, Side>{};
              for (final x in (c['competitors'] as List).cast<Map>()) {
                final tm = (x['team'] ?? {}) as Map;
                final nm = '${tm['displayName'] ?? tm['name'] ?? '?'}';
                final lg0 = tm['logos'];
                final logo = '${tm['logo'] ?? (lg0 is List && lg0.isNotEmpty ? lg0[0]['href'] : '')}';
                t['${x['homeAway'] ?? (t.containsKey('home') ? 'away' : 'home')}'] = Side(nm, '${tm['shortDisplayName'] ?? nm}', _clubLogo(nm, logo), x['score'] == null ? null : '${x['score']}');
              }
              out.add(Ev('${l.k}:${e['id']}', l.k, DateTime.parse('${e['date']}').millisecondsSinceEpoch ~/ 1000, '${st['state'] ?? 'pre'}', '${st['shortDetail'] ?? ''}',
                  t['home'] ?? const Side('?', '?', '', null), t['away'] ?? const Side('?', '?', '', null), '${c['venue']?['fullName'] ?? ''}', false));
            } catch (_) {}
          }
        }
      }

      await scan(-1, 14);
      final nowS = now.millisecondsSinceEpoch ~/ 1000;
      if (!out.any((e) => e.st != 'post' && e.ts > nowS - 10800)) await scan(15, 70);
    }
  } catch (_) {}
  return out;
}

/// matchs en cours ou à venir (15 jours) + derniers résultats (24 h)
Future<List<Ev>> fetchSport(Iterable<String> keys) async {
  final all = await Future.wait([for (final k in knownLeagues(keys)) fetchLeague(lgOf(k))]);
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final l = [for (final x in all) ...x].where((e) => e.live || (e.ts > now - 86400 && e.ts < now + 75 * 86400)).toList();
  l.sort((a, b) {
    if (a.live != b.live) return a.live ? -1 : 1;
    return a.ts.compareTo(b.ts);
  });
  return l;
}

const _jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];

String whenLabel(Ev e, {bool day = true}) {
  final t = DateTime.fromMillisecondsSinceEpoch(e.ts * 1000);
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (!day) return hm;
  final n = DateTime.now();
  final d0 = DateTime(n.year, n.month, n.day), d1 = DateTime(t.year, t.month, t.day);
  final diff = d1.difference(d0).inDays;
  final dn = diff == 0 ? 'Aujourd\'hui' : diff == 1 ? 'Demain' : diff == -1 ? 'Hier' : '${_jours[t.weekday - 1]} ${t.day}';
  return '$dn · $hm';
}

Widget _logo(String u, {double s = 26}) {
  if (u.isEmpty) return SizedBox(width: s, height: s);
  if (u.startsWith('asset:')) return Image.asset(u.substring(6), width: s, height: s, fit: BoxFit.contain);
  return netLogo(u, s);
}

/// carte de match (grille et rangée de l'accueil)
class SportCard extends StatelessWidget {
  final Ev e;
  final double? width;
  final VoidCallback onTap;
  final bool noDay;
  const SportCard({super.key, required this.e, required this.onTap, this.width, this.noDay = false});

  @override
  Widget build(BuildContext context) {
    final l = lgOf(e.lg);
    final w = e.post && !e.f1 ? (int.tryParse(e.h.score ?? '') ?? 0).compareTo(int.tryParse(e.a.score ?? '') ?? 0) : 0;
    Widget row(Side s, bool lost) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            _logo(s.logo, s: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(s.short, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(14.5, w: 620, color: lost ? kMut : kText))),
            if (!e.f1 && e.st != 'pre' && s.score != null) Text(s.score!, style: T(15, w: 800, color: lost ? kMut : kText)),
          ]),
        );
    final when = whenLabel(e, day: !noDay);
    return SizedBox(
      width: width,
      child: FocusCard(
        onTap: onTap,
        radius: 16,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            // fond teinté aux couleurs de la compétition, motif du sport et logo en filigrane : chaque ligue a sa tuile
            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color.alphaBlend(l.color.withOpacity(0.28), const Color(0xFF12151C)), const Color(0xFF12151C)]),
            border: Border.all(color: e.live ? const Color(0xFFE5484D) : l.color.withOpacity(0.38), width: 0.8),
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: l.color),
              Expanded(
                child: Stack(children: [
                  Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Motif(l)))),
                  if (!Perf.lite) Positioned(right: -8, bottom: -12, child: IgnorePointer(child: Opacity(opacity: 0.14, child: LgIcon(e.lg, size: 76)))),
                  Padding(
                  padding: const EdgeInsets.fromLTRB(13, 10, 14, 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      LgIcon(e.lg, size: 15),
                      const SizedBox(width: 6),
                      Expanded(child: Text(l.n, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(11.5, w: 700, color: Color.lerp(l.color, Colors.white, 0.6)!))),
                      if (e.live)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text('EN DIRECT', style: T(10.5, w: 750, ls: 0.04, color: const Color(0xFFFF7A80))),
                        ])
                      else if (e.post)
                        Text('Terminé', style: T(11.5, w: 600, color: kMut))
                      else
                        Text(when, style: T(13, w: 700)),
                    ]),
                    const SizedBox(height: 7),
                    if (e.f1) ...[
                      Text(e.h.short, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(15.5, w: 720)),
                      const SizedBox(height: 2),
                      Text(e.a.short + (e.post && e.a.score != null && e.a.score!.isNotEmpty ? '  ·  🏆 ${e.a.score}' : ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: T(13, w: 500, color: kMut)),
                    ] else ...[
                      row(e.h, w < 0),
                      row(e.a, w > 0),
                    ],
                    if (e.lieu.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(e.lieu, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(11.5, w: 450, color: const Color(0xFF6F7889))),
                    ],
                  ]),
                ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// motif discret selon le sport : ligne et rond de touche (foot), lignes du terrain (rugby), damier (course)
class _Motif extends CustomPainter {
  final League l;
  const _Motif(this.l);
  @override
  void paint(Canvas c, Size s) {
    final sport = l.espn.split('/').first;
    final line = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    if (sport == 'soccer') {
      c.drawCircle(Offset(s.width * 0.8, s.height * 0.5), s.height * 0.42, line);
      c.drawLine(Offset(s.width * 0.8, 0), Offset(s.width * 0.8, s.height), line);
    } else if (sport == 'rugby') {
      for (var i = 0; i < 4; i++) {
        final x = s.width * (0.55 + i * 0.13);
        c.drawLine(Offset(x, 0), Offset(x, s.height), line);
      }
    } else if (sport == 'racing') {
      final f = Paint()..color = Colors.white.withOpacity(0.05);
      final cell = s.height / 4;
      for (var r = 0; r < 4; r++) {
        for (var q = 0; q < 5; q++) {
          if ((r + q).isEven) c.drawRect(Rect.fromLTWH(s.width - cell * 5 + q * cell, r * cell, cell, cell), f);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Motif old) => old.l.k != l.k;
}

const _jfull = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

String dayTitle(Ev e) {
  final t = DateTime.fromMillisecondsSinceEpoch(e.ts * 1000);
  final n = DateTime.now();
  final diff = DateTime(t.year, t.month, t.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  if (diff == 0) return 'Aujourd\'hui';
  if (diff == 1) return 'Demain';
  return '${_jfull[t.weekday - 1]} ${t.day} ${_mois[t.month - 1]}';
}

/// grande carte du prochain match / du match en cours
class SportHero extends StatelessWidget {
  final Ev e;
  final VoidCallback onTap;
  const SportHero({super.key, required this.e, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = lgOf(e.lg);
    Widget side(Side s) => Column(mainAxisSize: MainAxisSize.min, children: [_logo(s.logo, s: 56), const SizedBox(height: 8), Text(s.short, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(15, w: 750))]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: FocusCard(
        onTap: onTap,
        radius: 22,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: e.live ? const Color(0xFFE5484D) : l.color.withOpacity(0.55), width: 1),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.alphaBlend(l.color.withOpacity(0.46), const Color(0xFF0F1218)), const Color(0xFF0F1218)]),
            boxShadow: Perf.lite ? null : [BoxShadow(color: l.color.withOpacity(0.28), blurRadius: 28, spreadRadius: -10, offset: const Offset(0, 14))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(children: [
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Motif(l)))),
            if (!Perf.lite) Positioned(right: -18, bottom: -22, child: IgnorePointer(child: Opacity(opacity: 0.12, child: LgIcon(e.lg, size: 150)))),
            Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: e.live ? const Color(0xFFE5484D) : const Color(0x33000000), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x26FFFFFF), width: 0.6)),
                child: Text(e.live ? 'En direct${e.det.isNotEmpty ? ' · ${e.det}' : ''}' : whenLabel(e).toLowerCase(), style: T(13, w: 650)),
              ),
            ),
            const SizedBox(height: 10),
            if (e.f1)
              Column(children: [Text(e.h.short.toUpperCase(), textAlign: TextAlign.center, style: T(30, w: 850, ls: -0.02)), const SizedBox(height: 6), Text(e.a.short, style: T(16, w: 600)), if (e.lieu.isNotEmpty) Text(e.lieu, style: T(13, color: kMut))])
            else
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: side(e.h)),
                Padding(padding: const EdgeInsets.only(top: 18), child: e.live ? Text('${e.h.score ?? 0} - ${e.a.score ?? 0}', style: T(30, w: 850)) : Text('VS', style: T(18, w: 700, color: kMut))),
                Expanded(child: side(e.a)),
              ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [LgIcon(e.lg, size: 16), const SizedBox(width: 6), Text(l.n, style: T(13, w: 650, color: Color.lerp(l.color, Colors.white, 0.7)!))]),
          ]),
          ]),
        ),
      ),
    );
  }
}

const _lgSub = {
  'l1': 'Football · France',
  'l2': 'Football · France',
  'top14': 'Rugby · France',
  'cc': 'Rugby · Europe',
  'ucl': 'Football · Europe',
  'el': 'Football · Europe',
  'pl': 'Football · Angleterre',
  'liga': 'Football · Espagne',
  'f1': 'Course · Monde',
};

/// bandeau de la compétition choisie : couleurs, motif du sport, grand logo
class LeagueBanner extends StatelessWidget {
  final League l;
  final int matches;
  const LeagueBanner({super.key, required this.l, required this.matches});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
        child: Container(
          height: 104,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color.alphaBlend(l.color.withOpacity(0.62), const Color(0xFF0F1218)), Color.alphaBlend(l.color.withOpacity(0.14), const Color(0xFF0F1218))]),
            border: Border.all(color: l.color.withOpacity(0.6), width: 1),
          ),
          child: Stack(children: [
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _Motif(l)))),
            if (!Perf.lite) Positioned(right: -10, top: -14, bottom: -14, child: IgnorePointer(child: Opacity(opacity: 0.2, child: LgIcon(l.k, size: 132)))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                Container(width: 58, height: 58, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x26FFFFFF), width: 0.8)), child: LgIcon(l.k, size: 38)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.n, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(24, w: 850, ls: -0.03)),
                    const SizedBox(height: 3),
                    Text('${_lgSub[l.k] ?? ''}${matches > 0 ? ' · $matches match${matches > 1 ? 's' : ''} à venir' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T(13.5, w: 550, color: const Color(0xCCFFFFFF))),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      );
}

/// onglet Sport
class SportTab extends StatefulWidget {
  final Future<List<Ev>> future;
  final void Function(Ev) onOpen;
  final void Function(List<String>) onKeys;
  const SportTab({super.key, required this.future, required this.onOpen, required this.onKeys});
  @override
  State<SportTab> createState() => _SportTabState();
}

class _SportTabState extends State<SportTab> {
  String lg = '';

  Future<void> _manage(BuildContext ctx) async {
    final keys = await manageLeagues(ctx);
    if (keys == null) return;
    if (lg.isNotEmpty && !keys.contains(lg)) lg = '';
    widget.onKeys(keys);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 64;
    final wide = isWide(context);
    return FutureBuilder<List<Ev>>(
      future: widget.future,
      builder: (_, snap) {
        if (!snap.hasData) return const SkeletonPage(rows: true);
        final all = snap.data!;
        final keys = [for (final k in knownLeagues(Store.sportKeys)) lgOf(k)];
        final l = lg.isEmpty ? all : all.where((e) => e.lg == lg).toList();
        final live = l.where((e) => e.live).toList();
        final next = l.where((e) => !e.live && !e.post).toList();
        final hero = live.isNotEmpty ? live.first : (next.isNotEmpty ? next.first : null);
        final groups = <String, List<Ev>>{};
        for (final e in l.where((e) => !e.live)) {
          groups.putIfAbsent(dayTitle(e), () => []).add(e);
        }
        final cw = wide ? 270.0 : 256.0;
        return ListView(padding: EdgeInsets.only(top: wide ? 8 : top, bottom: wide ? 40 : 110), children: [
          Chips(
            labels: ['Tout', ...keys.map((k) => k.n), '+'],
            leading: [null, for (final k in keys) LgIcon(k.k, size: 20), const Icon(Icons.add, size: 18)],
            tints: [null, for (final k in keys) k.color, null],
            selected: lg.isEmpty ? 0 : keys.indexWhere((k) => k.k == lg) + 1,
            onSelect: (v) {
              if (v == keys.length + 1) {
                _manage(context);
              } else {
                setState(() => lg = v == 0 ? '' : keys[v - 1].k);
              }
            },
          ),
          if (l.isEmpty) Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('Aucun match prévu ces prochains jours.', style: T(15, color: kMut)))),
          if (lg.isNotEmpty) LeagueBanner(l: lgOf(lg), matches: next.length),
          if (hero != null) SportHero(e: hero, onTap: () => widget.onOpen(hero)),
          if (live.length > 1) ...[
            const SectionTitle('🔴 En direct'),
            SizedBox(height: 124, child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: live.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, i) => SportCard(e: live[i], width: cw, noDay: true, onTap: () => widget.onOpen(live[i])))),
          ],
          for (final g in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Row(children: [Expanded(child: Text(g.key, style: T(19, w: 700, ls: -0.02))), Text('${g.value.length} match${g.value.length > 1 ? 's' : ''}', style: T(14, w: 500, color: kMut))]),
            ),
            SizedBox(height: 124, child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: g.value.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, i) => SportCard(e: g.value[i], width: cw, noDay: true, onTap: () => widget.onOpen(g.value[i])))),
          ],
        ]);
      },
    );
  }
}

/// ajouter / retirer des championnats et les réordonner (appui long + glisser) ; null si rien n'a changé
Future<List<String>?> manageLeagues(BuildContext ctx) async {
  final sel = [...knownLeagues(Store.sportKeys)];
  final order = [...sel, for (final l in leagues) if (!sel.contains(l.k)) l.k];
  await showModalBottomSheet<void>(
    context: ctx,
    backgroundColor: const Color(0xFF12151C),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (c) => StatefulBuilder(
      builder: (c, set) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * 0.72,
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 4), child: Align(alignment: Alignment.centerLeft, child: Text('Mes sports', style: T(20, w: 750)))),
            Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Coche pour afficher, glisse pour changer l\'ordre.', style: T(13, color: kMut)))),
            Expanded(
              child: ReorderableListView(
                onReorder: (a, b) => set(() {
                  if (b > a) b--;
                  order.insert(b, order.removeAt(a));
                }),
                children: [
                  for (final k in order)
                    CheckboxListTile(
                      key: ValueKey(k),
                      value: sel.contains(k),
                      activeColor: Colors.white,
                      checkColor: Colors.black,
                      controlAffinity: ListTileControlAffinity.leading,
                      secondary: const Icon(Icons.drag_handle, color: kMut),
                      title: Row(children: [LgIcon(k, size: 22), const SizedBox(width: 10), Expanded(child: Text(lgOf(k).n, style: T(16, w: 600)))]),
                      onChanged: (v) => set(() => v == true ? sel.add(k) : sel.remove(k)),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    ),
  );
  final keys = [for (final k in order) if (sel.contains(k)) k];
  if (keys.isEmpty || keys.join() == Store.sportKeys.join()) return null;
  return keys;
}
