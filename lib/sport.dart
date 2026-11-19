import 'store.dart';
import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:http/http.dart' as http;
import 'names.dart';
import 'osk.dart';
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
  // football
  League('seriea', 'Serie A', 'soccer/ita.1', false, Color(0xFF1E6FD9), _chFoot),
  League('bund', 'Bundesliga', 'soccer/ger.1', false, Color(0xFFD9342B), _chFoot),
  League('cdf', 'Coupe de France', 'soccer/fra.coupe_de_france', false, Color(0xFF2E7D6B), _chFoot),
  League('ecl', 'Ligue Conférence', 'soccer/uefa.europa.conf', false, Color(0xFF23A455), _chFoot),
  League('nl', 'Ligue des nations', 'soccer/uefa.nations', false, Color(0xFF3F51B5), _chFoot),
  League('euro', 'Euro', 'soccer/uefa.euro', false, Color(0xFF1565C0), _chFoot),
  League('wc', 'Coupe du monde', 'soccer/fifa.world', false, Color(0xFF8E1B3E), _chFoot),
  League('cwc', 'Coupe du monde des clubs', 'soccer/fifa.cwc', false, Color(0xFFB8860B), _chFoot),
  League('por', 'Liga Portugal', 'soccer/por.1', false, Color(0xFF2E8B57), _chFoot),
  League('ned', 'Eredivisie', 'soccer/ned.1', false, Color(0xFFE65100), _chFoot),
  // rugby
  League('six', 'Tournoi des Six Nations', 'rugby/180659', false, Color(0xFF7B1FA2), _chRugby),
  League('trc', 'Rugby Championship', 'rugby/244293', false, Color(0xFF00897B), _chRugby),
  League('rwc', 'Coupe du monde de rugby', 'rugby/164205', false, Color(0xFFAD1457), _chRugby),
  League('prem', 'Premiership', 'rugby/267979', false, Color(0xFF5E35B1), _chRugby),
  League('urc', 'United Rugby Championship', 'rugby/270557', false, Color(0xFF00838F), _chRugby),
  League('chal', 'Challenge Cup (rugby)', 'rugby/272073', false, Color(0xFF558B2F), _chRugby),
  // basketball, football américain, hockey
  League('nba', 'NBA', 'basketball/nba', false, Color(0xFFC8102E), _chUs),
  League('nfl', 'NFL', 'football/nfl', false, Color(0xFF013369), _chUs),
  League('nhl', 'NHL', 'hockey/nhl', false, Color(0xFF1D6FA5), _chUs),
];

const _chFoot = [r'^canal\+ foot$', r'^canal\+ sport$', r'^canal\+ live \d+$', r'^bein sports', r'^rmc sport'];
const _chRugby = [r'^canal\+ sport$', r'^canal\+ live \d+$', r'^bein sports', r'^france [23]$', r'^tf1$'];
const _chUs = [r'^bein sports', r'^rmc sport', r'^canal\+ sport$'];

/// sport d'une compétition (d'après la source des matchs) et ordre d'affichage
String sportName(League l) => switch (l.espn.split('/').first) {
      'soccer' => 'Football',
      'rugby' => 'Rugby',
      'basketball' => 'Basketball',
      'football' => 'Football américain',
      'hockey' => 'Hockey sur glace',
      'racing' => 'Formule 1',
      _ => 'Autres',
    };
const sportOrder = ['Football', 'Rugby', 'Basketball', 'Football américain', 'Hockey sur glace', 'Formule 1'];
IconData sportIcon(String sp) => switch (sp) {
      'Football' => Icons.sports_soccer,
      'Rugby' => Icons.sports_rugby,
      'Basketball' => Icons.sports_basketball,
      'Football américain' => Icons.sports_football,
      'Hockey sur glace' => Icons.sports_hockey,
      'Formule 1' => Icons.sports_motorsports,
      _ => Icons.sports,
    };

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

/// l'une des deux équipes est suivie (Réglages › Sport › Mes équipes)
bool followed(Ev e) {
  if (e.f1) return false;
  final t = {for (final x in Store.sportTeams) x.toLowerCase()};
  return t.contains(e.h.name.toLowerCase()) || t.contains(e.a.name.toLowerCase());
}

/// derniers matchs chargés (sert à proposer les équipes à suivre sans tout recharger)
List<Ev> lastEvents = const [];

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
  lastEvents = l;
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

/// carte de match COMPACTE (grille et rangée de l'accueil) : deux équipes, heure ou score, chaîne de couleur de la compétition ; équipes suivies en surbrillance, mode sans spoil
class SportCard extends StatelessWidget {
  final Ev e;
  final double? width;
  final VoidCallback onTap;
  final bool noDay;
  const SportCard({super.key, required this.e, required this.onTap, this.width, this.noDay = false});

  /// matchs terminés dont le score a été découvert en touchant la carte (mode sans spoil)
  static final revealed = <String>{};
  static final tick = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: tick,
        builder: (_, __, ___) {
          final l = lgOf(e.lg);
          final hide = Store.flag('sport_nospoil', false) && e.post && !e.f1 && !revealed.contains(e.id);
          final mine = followed(e);
          final w = e.post && !e.f1 && !hide ? (int.tryParse(e.h.score ?? '') ?? 0).compareTo(int.tryParse(e.a.score ?? '') ?? 0) : 0;
          final star = Store.sportTeams.map((x) => x.toLowerCase()).toSet();
          Widget row(Side s, bool lost) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(children: [
                  _logo(s.logo, s: 20),
                  const SizedBox(width: 9),
                  Expanded(child: Text(s.short, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(14, w: star.contains(s.name.toLowerCase()) ? 800 : 600, color: lost ? kMut : kText))),
                  if (star.contains(s.name.toLowerCase())) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFC857))),
                  if (!e.f1 && e.st != 'pre' && s.score != null && !hide) Padding(padding: const EdgeInsets.only(left: 8), child: Text(s.score!, style: T(14.5, w: 800, color: lost ? kMut : kText))),
                ]),
              );
          final when = whenLabel(e, day: !noDay);
          final right = e.live
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle)),
                  const SizedBox(height: 4),
                  Text('DIRECT', style: T(10, w: 800, ls: 0.04, color: const Color(0xFFFF7A80))),
                ])
              : e.post
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(hide ? Icons.visibility_off_rounded : Icons.check_rounded, size: 15, color: kMut),
                      const SizedBox(height: 3),
                      Text(hide ? 'Score\nmasqué' : 'Terminé', textAlign: TextAlign.center, style: T(10, w: 600, color: kMut, h: 1.15)),
                    ])
                  : Text(when.replaceFirst(' · ', '\n'), textAlign: TextAlign.center, style: T(12.5, w: 700, h: 1.25));
          return SizedBox(
            width: width,
            child: FocusCard(
              onTap: hide
                  ? () {
                      revealed.add(e.id);
                      tick.value++;
                    }
                  : onTap,
              radius: 14,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color.alphaBlend(l.color.withOpacity(mine ? 0.40 : 0.22), const Color(0xFF12151C)), const Color(0xFF12151C)]),
                  border: Border.all(color: e.live ? const Color(0xFFE5484D) : (mine ? const Color(0xFFFFC857).withOpacity(0.7) : l.color.withOpacity(0.38)), width: mine ? 1.2 : 0.8),
                ),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(width: 4, color: l.color),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(11, 8, 8, 8),
                        child: e.f1
                            ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text(e.h.short, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(14.5, w: 720)),
                                const SizedBox(height: 2),
                                Text(e.a.short + (e.post && e.a.score != null && e.a.score!.isNotEmpty ? '  ·  🏆 ${e.a.score}' : ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: T(12.5, w: 500, color: kMut)),
                              ])
                            : Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [row(e.h, w < 0), row(e.a, w > 0)]),
                      ),
                    ),
                    Container(
                      width: 62,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      color: const Color(0x14000000),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [LgIcon(e.lg, size: 15), const SizedBox(height: 4), Flexible(child: right)]),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      );
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
  'seriea': 'Football · Italie',
  'bund': 'Football · Allemagne',
  'cdf': 'Football · France',
  'ecl': 'Football · Europe',
  'nl': 'Football · Europe',
  'euro': 'Football · Europe',
  'wc': 'Football · Monde',
  'cwc': 'Football · Monde',
  'por': 'Football · Portugal',
  'ned': 'Football · Pays-Bas',
  'six': 'Rugby · Europe',
  'trc': 'Rugby · Hémisphère sud',
  'rwc': 'Rugby · Monde',
  'prem': 'Rugby · Angleterre',
  'urc': 'Rugby · Europe',
  'chal': 'Rugby · Europe',
  'nba': 'Basketball · États-Unis',
  'nfl': 'Football américain · États-Unis',
  'nhl': 'Hockey · Amérique du Nord',
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
  String sp = '';      // sport choisi (« Football »…), vide = tous
  String lg = '';      // compétition choisie, vide = toutes celles du sport
  bool mine = false;   // seulement mes équipes

  Future<void> _more(BuildContext ctx) async {
    final r = await appSheet<String>(
      context: ctx,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 6),
          ListTile(leading: const Icon(Icons.emoji_events_outlined), title: const Text('Championnats et sports'), subtitle: const Text('Foot, rugby, basket… rangés par sport'), onTap: () => Navigator.pop(ctx, 'lg')),
          ListTile(leading: const Icon(Icons.star_outline_rounded), title: const Text('Mes équipes'), subtitle: const Text('Leurs matchs passent en tête'), onTap: () => Navigator.pop(ctx, 'teams')),
          ListTile(leading: const Icon(Icons.tune_rounded), title: const Text('Réglages du Sport'), subtitle: const Text('Scores masqués, rangée de l\'accueil'), onTap: () => Navigator.pop(ctx, 'set')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!ctx.mounted) return;
    if (r == 'lg') {
      final keys = await manageLeagues(ctx);
      if (keys == null) return;
      final spn = {for (final k in keys) sportName(lgOf(k))};
      if (sp.isNotEmpty && !spn.contains(sp)) sp = '';
      if (lg.isNotEmpty && !keys.contains(lg)) lg = '';
      widget.onKeys(keys);
    } else if (r == 'teams') {
      await manageTeams(ctx, lastEvents);
      if (mounted) setState(() {});
    } else if (r == 'set') {
      await Navigator.push(ctx, softRoute((_) => SportSettings(onKeys: widget.onKeys)));
      if (mounted) setState(() {});
    }
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
        final sports = [for (final n in sportOrder) if (keys.any((k) => sportName(k) == n)) n];
        final hasTeams = Store.sportTeams.isNotEmpty;
        final inSport = keys.where((k) => sp.isEmpty || sportName(k) == sp).toList();
        final l = all.where((e) => (sp.isEmpty || sportName(lgOf(e.lg)) == sp) && (lg.isEmpty || e.lg == lg) && (!mine || followed(e))).toList();
        final live = l.where((e) => e.live).toList();
        final next = l.where((e) => !e.live && !e.post).toList();
        final hero = live.isNotEmpty ? live.first : (next.isNotEmpty ? next.first : null);
        final groups = <String, List<Ev>>{};
        for (final e in l.where((e) => !e.live)) {
          groups.putIfAbsent(dayTitle(e), () => []).add(e);
        }
        // dans une journée, les matchs de mes équipes d'abord
        for (final g in groups.values) {
          g.sort((a, b) => (followed(a) == followed(b)) ? a.ts.compareTo(b.ts) : (followed(a) ? -1 : 1));
        }
        final cw = wide ? 270.0 : 256.0;
        // 1re ligne : Tout · Mes équipes · sports · +
        final r1 = ['Tout', if (hasTeams) '★ Mes équipes', ...sports, '+'];
        int sel1() {
          if (mine) return 1;
          if (sp.isEmpty) return 0;
          return r1.indexOf(sp);
        }
        if (Device.tv) {
          Widget item(String label, IconData ic, bool on, VoidCallback f, {Color? tint}) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FocusCard(
                  radius: 14,
                  focusScale: 1.0,
                  onTap: f,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(color: on ? Colors.white.withOpacity(0.14) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Icon(ic, size: 24, color: tint ?? (on ? Colors.white : kMut)),
                      const SizedBox(width: 14),
                      Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(19, w: on ? 750 : 550, color: on ? Colors.white : kText))),
                    ]),
                  ),
                ),
              );
          void pick(String s, String g, bool m) => setState(() {
                sp = s;
                lg = g;
                mine = m;
              });
          final side = ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 40), children: [
            item('Tout', Icons.sports_rounded, sp.isEmpty && !mine, () => pick('', '', false)),
            if (hasTeams) item('Mes équipes', Icons.star_rounded, mine, () => pick('', '', true), tint: const Color(0xFFFFC857)),
            for (final n in sports) ...[
              item(n, sportIcon(n), sp == n && !mine, () => pick(n, '', false)),
              if (sp == n && !mine && inSport.length > 1) ...[
                Padding(padding: const EdgeInsets.only(left: 22), child: item('Toutes', Icons.chevron_right_rounded, lg.isEmpty, () => pick(n, '', false))),
                for (final k in inSport) Padding(padding: const EdgeInsets.only(left: 22), child: item(k.n, Icons.chevron_right_rounded, lg == k.k, () => pick(n, k.k, false), tint: k.color)),
              ],
            ],
            const SizedBox(height: 10),
            item('Réglages', Icons.tune_rounded, false, () => _more(context)),
          ]);
          Widget grid(List<Ev> evs) => Wrap(spacing: 14, runSpacing: 14, children: [for (final e in evs) SportCard(e: e, width: 300, onTap: () => widget.onOpen(e))]);
          final main = ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 60), children: [
            if (l.isEmpty) Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(mine ? 'Aucun match prévu pour tes équipes.' : 'Aucun match prévu ces prochains jours.', style: T(20, color: kMut)))),
            if (lg.isNotEmpty) LeagueBanner(l: lgOf(lg), matches: next.length),
            if (hero != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: SportHero(e: hero, onTap: () => widget.onOpen(hero))),
            if (live.length > 1) ...[
              Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 10), child: Text('🔴 En direct', style: T(24, w: 750))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: grid(live)),
            ],
            for (final g in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                child: Row(children: [Expanded(child: Text(g.key, style: T(24, w: 750, ls: -0.02))), Text('${g.value.length} match${g.value.length > 1 ? 's' : ''}', style: T(16, w: 500, color: kMut))]),
              ),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: grid(g.value)),
            ],
          ]);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(children: [SizedBox(width: 290, child: side), const SizedBox(width: 12), Expanded(child: main)]),
          );
        }
        return ListView(padding: EdgeInsets.only(top: wide ? 8 : top, bottom: wide ? 40 : 110), children: [
          Chips(
            labels: r1,
            leading: [null, if (hasTeams) const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFC857)), for (final n in sports) Icon(sportIcon(n), size: 18), const Icon(Icons.add, size: 18)],
            selected: sel1(),
            onSelect: (v) {
              final plus = r1.length - 1;
              if (v == plus) {
                _more(context);
              } else if (v == 0) {
                setState(() {
                  sp = '';
                  lg = '';
                  mine = false;
                });
              } else if (hasTeams && v == 1) {
                setState(() {
                  mine = true;
                  sp = '';
                  lg = '';
                });
              } else {
                setState(() {
                  mine = false;
                  sp = r1[v];
                  lg = '';
                });
              }
            },
          ),
          // 2e ligne : compétitions du sport choisi
          if (sp.isNotEmpty && inSport.length > 1)
            Chips(
              labels: ['Toutes', for (final k in inSport) k.n],
              leading: [null, for (final k in inSport) LgIcon(k.k, size: 18)],
              tints: [null, for (final k in inSport) k.color],
              selected: lg.isEmpty ? 0 : inSport.indexWhere((k) => k.k == lg) + 1,
              onSelect: (v) => setState(() => lg = v == 0 ? '' : inSport[v - 1].k),
            ),
          if (l.isEmpty) Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(mine ? 'Aucun match prévu pour tes équipes.' : 'Aucun match prévu ces prochains jours.', style: T(15, color: kMut)))),
          if (lg.isNotEmpty) LeagueBanner(l: lgOf(lg), matches: next.length),
          if (hero != null) SportHero(e: hero, onTap: () => widget.onOpen(hero)),
          if (live.length > 1) ...[
            const SectionTitle('🔴 En direct'),
            SizedBox(height: 78, child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: live.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, i) => SportCard(e: live[i], width: cw, onTap: () => widget.onOpen(live[i])))),
          ],
          for (final g in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Row(children: [Expanded(child: Text(g.key, style: T(19, w: 700, ls: -0.02))), Text('${g.value.length} match${g.value.length > 1 ? 's' : ''}', style: T(14, w: 500, color: kMut))]),
            ),
            SizedBox(height: 78, child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: g.value.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, i) => SportCard(e: g.value[i], width: cw, noDay: true, onTap: () => widget.onOpen(g.value[i])))),
          ],
        ]);
      },
    );
  }
}

/// championnats et sports, rangés par sport (Football : Ligue 1, Ligue des champions… ; Rugby : Top 14, Champions Cup…) ; null si rien n'a changé
Future<List<String>?> manageLeagues(BuildContext ctx) async {
  final sel = {...knownLeagues(Store.sportKeys)};
  final open = <String>{for (final k in sel) sportName(lgOf(k))};
  await appSheet<void>(
    context: ctx,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * 0.78,
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 4), child: Align(alignment: Alignment.centerLeft, child: Text('Championnats et sports', style: T(20, w: 750)))),
            Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Déplie un sport et coche ses compétitions.', style: T(13, color: kMut)))),
            Expanded(
              child: ListView(children: [
                for (final sp in [...sportOrder, 'Autres'])
                  if (leagues.any((l) => sportName(l) == sp)) ...[
                    ListTile(
                      leading: Icon(sportIcon(sp), color: kAccent),
                      title: Text(sp, style: T(16.5, w: 700)),
                      subtitle: Text('${leagues.where((l) => sportName(l) == sp && sel.contains(l.k)).length} sur ${leagues.where((l) => sportName(l) == sp).length} choisies'),
                      trailing: Icon(open.contains(sp) ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: kMut),
                      onTap: () => set(() => open.contains(sp) ? open.remove(sp) : open.add(sp)),
                    ),
                    if (open.contains(sp))
                      for (final l in leagues.where((l) => sportName(l) == sp))
                        CheckboxListTile(
                          value: sel.contains(l.k),
                          activeColor: Colors.white,
                          checkColor: Colors.black,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.only(left: 40, right: 16),
                          title: Row(children: [LgIcon(l.k, size: 22), const SizedBox(width: 10), Expanded(child: Text(l.n, style: T(15.5, w: 600)))]),
                          onChanged: (v) => set(() => v == true ? sel.add(l.k) : sel.remove(l.k)),
                        ),
                  ],
              ]),
            ),
          ]),
        ),
      ),
    ),
  );
  // l'ordre suit les sports puis la liste des compétitions
  final keys = [for (final l in leagues) if (sel.contains(l.k)) l.k]
    ..sort((a, b) {
      final sa = sportOrder.indexOf(sportName(lgOf(a))), sb = sportOrder.indexOf(sportName(lgOf(b)));
      return sa != sb ? sa.compareTo(sb) : leagues.indexWhere((l) => l.k == a).compareTo(leagues.indexWhere((l) => l.k == b));
    });
  if (keys.isEmpty || keys.join() == Store.sportKeys.join()) return null;
  return keys;
}

/// équipes suivies : on coche celles qu'on veut parmi les équipes des matchs chargés (recherche possible)
Future<void> manageTeams(BuildContext ctx, List<Ev> events) async {
  final byLg = <String, Map<String, Side>>{};
  for (final e in events) {
    if (e.f1) continue;
    for (final s in [e.h, e.a]) {
      if (s.name == '?' || s.name.isEmpty) continue;
      byLg.putIfAbsent(e.lg, () => {})[s.name] = s;
    }
  }
  final mine = {...Store.sportTeams};
  final qc = TextEditingController();
  var q = '';
  await appSheet<void>(
    context: ctx,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        final groups = [
          for (final k in knownLeagues(Store.sportKeys))
            if (byLg[k] != null) (lgOf(k), (byLg[k]!.values.where((s) => q.isEmpty || s.name.toLowerCase().contains(q)).toList()..sort((a, b) => a.name.compareTo(b.name)))),
        ];
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(c).height * 0.8,
            child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 4), child: Align(alignment: Alignment.centerLeft, child: Text('Mes équipes', style: T(20, w: 750)))),
              Padding(padding: const EdgeInsets.fromLTRB(22, 0, 22, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Leurs matchs passent en tête, avec une étoile.', style: T(13, color: kMut)))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0x3D767680), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.search_rounded, size: 18, color: kMut),
                    const SizedBox(width: 8),
                    Expanded(child: AppField(controller: qc, onChanged: (v) => set(() => q = v.toLowerCase().trim()), style: T(16, w: 500), decoration: InputDecoration(hintText: 'Rechercher une équipe', hintStyle: T(16, color: kMut), border: InputBorder.none, isDense: true, filled: false, contentPadding: EdgeInsets.zero))),
                  ]),
                ),
              ),
              Expanded(
                child: groups.isEmpty
                    ? Center(child: Text('Les équipes apparaissent quand les matchs sont chargés.', style: T(14, color: kMut)))
                    : ListView(children: [
                        for (final g in groups)
                          if (g.$2.isNotEmpty) ...[
                            Padding(padding: const EdgeInsets.fromLTRB(22, 14, 22, 4), child: Row(children: [LgIcon(g.$1.k, size: 18), const SizedBox(width: 8), Text(g.$1.n, style: T(13, w: 700, color: kMut))])),
                            for (final t in g.$2)
                              CheckboxListTile(
                                value: mine.contains(t.name),
                                activeColor: const Color(0xFFFFC857),
                                checkColor: Colors.black,
                                controlAffinity: ListTileControlAffinity.trailing,
                                secondary: _logo(t.logo, s: 26),
                                title: Text(t.name, style: T(15.5, w: 600)),
                                onChanged: (v) {
                                  set(() => v == true ? mine.add(t.name) : mine.remove(t.name));
                                  Store.setSportTeams(mine.toList());
                                },
                              ),
                          ],
                      ]),
              ),
            ]),
          ),
        );
      },
    ),
  );
}

/// Réglages › Personnaliser › Sport
class SportSettings extends StatefulWidget {
  final void Function(List<String>)? onKeys;
  const SportSettings({super.key, this.onKeys});
  @override
  State<SportSettings> createState() => _SportSettingsState();
}

class _SportSettingsState extends State<SportSettings> {
  Widget _card(List<Widget> rows) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: kEdge, width: 0.8)),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: 18, color: kEdge), rows[i]],
            ]),
          ),
        ),
      );

  Widget _row(String t, String sub, {Widget? trailing, required VoidCallback onTap}) => FocusCard(
        onTap: onTap,
        radius: 0,
        focusScale: 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 16, 12),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: T(16.5, w: 600)), if (sub.isNotEmpty) Text(sub, style: T(12.5, color: kMut, h: 1.3))])),
            if (trailing != null) trailing,
          ]),
        ),
      );

  Widget _head(String t) => Padding(padding: const EdgeInsets.fromLTRB(26, 22, 22, 8), child: Text(t.toUpperCase(), style: T(12, w: 700, ls: 0.09, color: kMut)));
  Widget _sw(bool v) => ExcludeFocus(child: IgnorePointer(child: Switch(value: v, activeColor: Colors.white, activeTrackColor: const Color(0xFF30D158), onChanged: (_) {})));
  Widget _check(bool on) => on ? const Icon(Icons.check_rounded, color: kAccent) : const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    final spoil = Store.flag('sport_nospoil', false);
    final hs = Store.str('home_sport'), hn = int.tryParse(Store.str('home_sport_n')) ?? 10;
    return Scaffold(
      body: LargeTitle(
        title: 'Sport',
        onBack: () => Navigator.pop(context),
        children: [
          _head('Contenu'),
          _card([
            _row('Championnats et sports', '${Store.sportKeys.length} suivis, rangés par sport', trailing: const Icon(Icons.chevron_right_rounded, color: kMut), onTap: () async {
              final keys = await manageLeagues(context);
              if (keys != null) {
                widget.onKeys != null ? widget.onKeys!(keys) : await Store.saveSportKeys(keys);
                Store.persoTick.value++;
              }
              if (mounted) setState(() {});
            }),
            _row('Mes équipes', Store.sportTeams.isEmpty ? 'Aucune équipe suivie' : '${Store.sportTeams.length} suivie${Store.sportTeams.length > 1 ? 's' : ''}', trailing: const Icon(Icons.chevron_right_rounded, color: kMut), onTap: () async {
              await manageTeams(context, lastEvents);
              if (mounted) setState(() {});
            }),
          ]),
          _head('Scores'),
          _card([
            _row('Masquer les scores', 'Les matchs terminés s\'affichent sans score ; touche la carte pour le voir', trailing: _sw(spoil), onTap: () async {
              await Store.setFlag('sport_nospoil', !spoil);
              SportCard.tick.value++;
              if (mounted) setState(() {});
            }),
          ]),
          _head('Rangée Sport de l\'accueil'),
          _card([
            _row('Tous mes championnats', '', trailing: _check(hs != 'mine'), onTap: () async {
              await Store.setStr('home_sport', 'all');
              Store.persoTick.value++;
              if (mounted) setState(() {});
            }),
            _row('Mes équipes seulement', '', trailing: _check(hs == 'mine'), onTap: () async {
              await Store.setStr('home_sport', 'mine');
              Store.persoTick.value++;
              if (mounted) setState(() {});
            }),
          ]),
          const SizedBox(height: 12),
          _card([
            for (final n in const [4, 6, 10])
              _row('$n matchs au maximum', '', trailing: _check(hn == n), onTap: () async {
                await Store.setStr('home_sport_n', '$n');
                Store.persoTick.value++;
                if (mounted) setState(() {});
              }),
          ]),
        ],
      ),
    );
  }
}
