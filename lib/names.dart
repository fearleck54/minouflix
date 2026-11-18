import 'xtream.dart';

/// Même logique que le module web MinouFlix (appli.py) : noms nettoyés, regroupement des qualités, thèmes, plateformes.

const _acc = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ñ': 'n', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};
const _small = {'ʜ': 'h', 'ᴅ': 'd', 'ꜱ': 's', 'ᴜ': 'u', 'ғ': 'f', 'ᴋ': 'k', 'ᵁ': 'U', 'ᴴ': 'H', 'ᴰ': 'D', 'ᶠ': 'F', 'ᴷ': 'K', 'ˢ': 'S', '⁴': '4', 'ᴿ': 'R', 'ᴮ': 'B', 'ᴱ': 'E', 'ᴬ': 'A', 'ᴸ': 'L', 'ᴹ': 'M', 'ᴺ': 'N', 'ᵀ': 'T', 'ⱽ': 'V', 'ᵂ': 'W', 'ᴼ': 'O', 'ᴾ': 'P', 'ᴵ': 'I', 'ᴳ': 'G'};

/// minuscules sans accents ni ponctuation (le + est gardé : canal+)
String norm(String s) {
  final b = StringBuffer();
  for (final ch in plain(s).toLowerCase().split('')) {
    b.write(_acc[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9+]+'), ' ').trim();
}

String plain(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_small[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _strip(String s, String chars) {
  var a = 0, z = s.length;
  while (a < z && chars.contains(s[a])) {
    a++;
  }
  while (z > a && chars.contains(s[z - 1])) {
    z--;
  }
  return s.substring(a, z);
}

String catLabel(String name) {
  final p = plain(name);
  final r = _strip(p.replaceFirst(RegExp(r'^\W*[A-Z]{2,3}\W+'), ''), ' ✪|');
  return r.isEmpty ? p : r;
}

String pretty(String n) => n.isEmpty ? n : n[0].toUpperCase() + n.substring(1).toLowerCase();

// ---------------------------------------------------------------- Direct
const liveThemes = [
  ('tnt', 'TNT', r'tnt|chaines francaises'),
  ('sport', 'Sport', r'bein|canal\+ (sport|live)|rmc sport|eurosport|ligue \+|mysports|equidia|^sport$|dazn'),
  ('events', 'Événements sport', r'ppv|event|evenment|roland|fff tv|nba prime|dazn (laliga|serie a|super league|ligue|live)|lequipe live'),
  ('cinema', 'Cinéma & séries', r'cine|box office|hbo|netflix|sony|disney'),
  ('infos', 'Infos', r'info'),
  ('jeunesse', 'Jeunesse', r'jeunesse|kids'),
  ('decouverte', 'Découverte', r'decouverte|docu'),
  ('musique', 'Musique', r'musi'),
  ('bouquets', 'Bouquets', r'moloto|my tf1|rmc channel|pluto'),
  ('outremer', 'Outre-mer & Belgique', r'caribbean|reunion|french'),
  ('delay', 'Décalé', r'delay'),
  ('autres', 'Autres', r''),
];

// l'ordre de détection : événements d'abord (comme le module)
const _detect = ['events', 'sport', 'tnt', 'cinema', 'infos', 'jeunesse', 'decouverte', 'musique', 'bouquets', 'outremer', 'delay', 'autres'];

String liveThemeOf(String catName) {
  final n = norm(catLabel(catName));
  for (final k in _detect) {
    final t = liveThemes.firstWhere((e) => e.$1 == k);
    if (RegExp(t.$3).hasMatch(n)) return k;
  }
  return 'autres';
}

String liveThemeName(String k) => liveThemes.firstWhere((e) => e.$1 == k).$2;

const _qual = [(r'4k|uhd|ultra', 4, '4K'), (r'fhd|full hd', 3, 'FHD'), (r'hevc|h265', 2, 'HEVC'), (r'hd', 2, 'HD'), (r'sd', 1, 'SD')];

/// une chaîne et ses variantes de qualité
class Chan {
  final String name, key, icon, theme, catId, epgId;
  final List<ChanV> v;
  Chan(this.name, this.key, this.icon, this.theme, this.catId, this.v, [this.epgId = '']);
  ChanV get best => v.first;
  bool has(String q) => v.any((x) => x.label.startsWith(q));
  bool get is4k => has('4K');
}

class ChanV {
  final Item item;
  final String label;
  final int rank;
  ChanV(this.item, this.label, this.rank);
}

(String, String, int, String) splitChannel(String name) {
  var s = plain(name).replaceFirst(RegExp(r'^\s*[|\[(]?\s*[A-Za-z]{2,3}\s*[|\])]+\s*'), '');
  var rank = 2;
  var lab = '';
  for (final q in _qual) {
    final m = RegExp('(?<![a-z0-9])(${q.$1})(?![a-z0-9])', caseSensitive: false).firstMatch(s);
    if (m != null) {
      rank = q.$2;
      lab = q.$3;
      s = '${s.substring(0, m.start)} ${s.substring(m.end)}';
      break;
    }
  }
  s = s.replaceAll(RegExp(r'(?<![a-z0-9])(4k|uhd|fhd|hd|sd|hevc|fr)(?![a-z0-9])\.?', caseSensitive: false), ' ');
  final backup = RegExp(r'\s[Bb]\s*$').hasMatch(s);
  s = s.replaceFirst(RegExp(r'\s[Bb]\s*$'), '');
  s = _strip(s.replaceAll(RegExp(r'\s+'), ' ').trim(), ' -|.:');
  final m = RegExp(r'^ligue\s*1?\s*\+\s*(\d+)?$', caseSensitive: false).firstMatch(s);
  if (m != null) s = 'Ligue 1+ ${m.group(1) ?? 1}';
  final key = norm(s).replaceAll('+', 'plus').replaceAll(RegExp(r'[^a-z0-9]'), '');
  return (s, key, rank, (lab.isEmpty ? 'HD' : lab) + (backup ? ' · secours' : ''));
}

/// regroupe les variantes d'une même chaîne
List<Chan> groupChannels(List<Item> items, Map<String, String> catNames) {
  final groups = <String, Chan>{}, order = <Chan>[];
  final themes = <String, String>{};
  for (final it in items) {
    if (RegExp(r'no event', caseSensitive: false).hasMatch(it.name)) continue;
    final th = themes.putIfAbsent(it.catId, () => liveThemeOf(catNames[it.catId] ?? ''));
    final (disp, key, rank, lab) = splitChannel(it.name);
    if (key.isEmpty) continue;
    final k = '$th|$key';
    var g = groups[k];
    if (g == null) {
      g = Chan(disp, key, it.icon, th, it.catId, []);
      groups[k] = g;
      order.add(g);
    }
    g.v.add(ChanV(it, lab, rank));
  }
  final out = <Chan>[];
  for (final g in order) {
    g.v.sort((a, b) {
      final s = (a.label.contains('secours') ? 1 : 0) - (b.label.contains('secours') ? 1 : 0);
      return s != 0 ? s : b.rank - a.rank;
    });
    final icon = g.icon.isNotEmpty ? g.icon : g.v.map((x) => x.item.icon).firstWhere((i) => i.isNotEmpty, orElse: () => '');
    out.add(Chan(g.name, g.key, icon, g.theme, g.catId, g.v, g.v.map((x) => x.item.epg).firstWhere((e) => e.isNotEmpty, orElse: () => '')));
  }
  return out;
}

const tntOrder = ['tf1', 'france 2', 'france 3', 'canal+', 'france 5', 'm6', 'arte', 'lcp', 'w9', 'tmc', 'tfx', 'gulli', 'bfm tv', 'cnews', 'lci', 'france info', 'c star', 't18', 'novo19', 'tf1 series', 'l equipe', '6ter', 'rmc story', 'rmc decouverte', 'cherie 25', 'paris premiere', 'france 4'];

List<Chan> tntSort(List<Chan> l) {
  int r(Chan c) {
    final i = tntOrder.indexOf(norm(c.name).replaceFirst(RegExp(r' (films|tv)$'), ''));
    return i < 0 ? 99 : i;
  }

  final idx = {for (var i = 0; i < l.length; i++) l[i]: i};
  return [...l]..sort((a, b) => r(a) != r(b) ? r(a) - r(b) : idx[a]! - idx[b]!);
}

// ---------------------------------------------------------------- films & séries
class Parsed {
  final String title, year, q, key;
  const Parsed(this.title, this.year, this.q, this.key);
}

final _titleTag = RegExp(r'(?:_[a-z]{2,3}|\s+(?:sd|hd|fhd|uhd|4k|multi|vf|vo|vost|vostfr|fr)|\s*\((?:vost|vostfr|multi|4k|uhd|vf|vo|s|ss|off)\)|\s*\((?:19|20)\d\d\))\s*$', caseSensitive: false);

Parsed parseTitle(String raw, Kind kind) {
  var s = plain(raw), y = '', q = '', tag = '';
  if (kind == Kind.vod) {
    final m = RegExp(r'^\s*(?:[A-Z]{2}\s*[-|:]\s*)?(?:(4[Kk]|uhd|UHD|FHD|HD)[\s\-|:]+)?').firstMatch(s);
    if (m != null && m.end > 0 && m.end < s.length) {
      q = (m.group(1) ?? '').toLowerCase() == '4k' || (m.group(1) ?? '').toLowerCase() == 'uhd' ? '4K' : '';
      s = s.substring(m.end);
    }
    final m2 = RegExp(r'[\s\-(]+((?:19|20)\d\d)\)?\s*((?:VOST\w*|MULTI|VF\w*|FR)\s*)*$').firstMatch(s);
    if (m2 != null && m2.start > 0) {
      y = m2.group(1)!;
      final g0 = m2.group(0)!;
      final t = _strip(g0.substring(g0.indexOf(y) + 4).trim(), ' )');
      s = s.substring(0, m2.start) + (t.isNotEmpty ? ' $t' : '');
    }
    s = _strip(s, ' -');
  } else if (kind == Kind.series) {
    final m = RegExp(r'\(((?:19|20)\d\d)\)').firstMatch(s);
    if (m != null) {
      y = m.group(1)!;
      s = s.substring(0, m.start) + s.substring(m.end);
    }
    final m2 = RegExp(r'[\s\-]+(multi|vostfr|vost|vf|fr)\s*$', caseSensitive: false).firstMatch(s);
    if (m2 != null) {
      tag = m2.group(1)!.toUpperCase();
      s = s.substring(0, m2.start);
    }
    s = _strip(s.replaceAll(RegExp(r'\s+'), ' ').trim(), ' -');
  }
  for (var i = 0; i < 6; i++) {
    final u = s.replaceFirst(_titleTag, '');
    if (u == s || u.isEmpty) break;
    s = u;
  }
  s = s.replaceFirst(RegExp(r'^(?:fr|vf|vo)\s*[-:]\s+', caseSensitive: false), '').trim();
  final key = norm(s.replaceFirst(RegExp(r'\s*\(fr\)\s*$', caseSensitive: false), '').replaceAll("'", '').replaceAll('’', '').replaceAll('`', ''));
  return Parsed(s, y, q, key);
}

/// un titre par (titre + année) et par catégorie ; trié du plus récent au plus ancien
List<Item> dedupeItems(List<Item> l) {
  final years = <String, Set<String>>{};
  for (final i in l) {
    if (i.year.isNotEmpty) years.putIfAbsent(i.p.key, () => {}).add(i.year);
  }
  const qrank = {'4K': 1, 'FHD': 4, 'HD': 3, 'SD': 1};
  final best = <String, Item>{};
  for (final i in l) {
    final ys = years[i.p.key];
    final k = '${i.p.key}|${i.year.isNotEmpty ? i.year : (ys != null && ys.length == 1 ? ys.first : '')}|${i.catId}';
    final b = best[k];
    if (b == null) {
      best[k] = i;
      continue;
    }
    int sc(Item x) => (x.icon.isNotEmpty ? 1000000 : 0) + (qrank[x.quality] ?? 2) * 100000 + (x.added ~/ 10000);
    if (sc(i) > sc(b)) best[k] = i;
  }
  return best.values.toList()..sort((a, b) => b.added.compareTo(a.added));
}

/// un seul exemplaire par titre (toutes catégories)
List<Item> uniqueTitles(Iterable<Item> l) {
  final seen = <String>{};
  return [for (final i in l) if (seen.add('${i.p.key}|${i.year}')) i];
}

const _genreRx = r'action|aventure|animation|anime|manga|comedie|humour|drame|horreur|epouvante|thriller|policier|crime|enquete|suspense|romance|romantique|science|fantas|fiction|\bsf\b|guerre|western|famil|enfant|jeunesse|kids|documentaire|\bdoc\b|musique|musical|concert|histoire|histori|biograph|sport|spectacle|theatre|divers|classique|ancien|erotique|adulte|emotion|mystere';

String vodCatKind(String label) {
  final n = norm(label);
  if (RegExp(r'original|netflix|disney|apple|prime|paramount|canal|tf1|hbo|amazon|ziggo|starz|marvel|ocs').hasMatch(n)) return 'studio';
  if (RegExp(r'(19|20)\d\d|recent|top|ultra|4k|saga').hasMatch(n)) return 'selection';
  // un « genre » est un vrai genre de cinéma ; « Afrique », « Maghreb »… vont dans « Autres »
  return RegExp(_genreRx).hasMatch(n) ? 'genre' : 'autre';
}

const platforms = [
  ('canal', 'MyCANAL', r'canal'),
  ('netflix', 'Netflix', r'netflix'),
  ('disney', 'Disney+', r'disney'),
  ('prime', 'Prime Video', r'prime|amazon'),
  ('apple', 'Apple TV+', r'apple'),
  ('tf1', 'TF1+', r'tf1'),
  ('paramount', 'Paramount+', r'paramount'),
  ('hbo', 'HBO Max', r'hbo|ocs'),
  ('starz', 'Starz Play', r'starz'),
];

/// logos publics TMDB des plateformes (mêmes que l'appli web)
const platLogos = {
  'netflix': '/rK1KljqmbvO9HQa1PBFLILWah72.png',
  'prime': '/gMZdpavHmxFNnLpMHwVxfqeux2g.png',
  'apple': '/9icYBfYFcwgCbky5VdGUIKJ4C5i.png',
  'disney': '/5eZ872CghnHFLB1j8grszbrx0dx.png',
  'canal': '/gliWKhLJVdm7QwL1braBCRko5dx.png',
  'tf1': '/j5w5U61YwOM6Adiaa5zuEVqrpP8.png',
  'paramount': '/pkx3klJlwW5JdtaulvDx6hDNtch.png',
};

String? platOf(String n) {
  final s = n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+ ]'), '');
  for (final p in platforms) {
    if (RegExp(p.$3).hasMatch(s)) return p.$1;
  }
  return null;
}

const selThemes = [
  ('uhd', '4K Ultra HD', r'uhd|4k'),
  ('top', 'Top IMDb', r'top|imdb'),
  ('saga', 'Sagas', r'saga'),
  ('cam', 'Au cinéma (qualité caméra)', r'\bcam\b'),
  ('an', 'Par année', r'(19|20)\d\d'),
];

String? selThemeOf(String n) {
  final s = n.toLowerCase();
  for (final t in selThemes) {
    if (RegExp(t.$3).hasMatch(s)) return t.$1;
  }
  return null;
}

int yearOfCat(String n) {
  final m = RegExp(r'(?:19|20)\d\d').firstMatch(n);
  return m == null ? 0 : int.parse(m.group(0)!);
}

const _gicons = [
  (r'action|guerre|western', 'flame'),
  (r'animation|anime|manga', 'palette'),
  (r'aventure|voyage', 'map'),
  (r'comedie|humour', 'laugh'),
  (r'horreur|epouvante', 'skull'),
  (r'romance|romantique', 'heart'),
  (r'science|fantas|fiction|sf', 'rocket'),
  (r'thriller|policier|crime|enquete|suspense', 'eye'),
  (r'drame', 'mask'),
  (r'famil|enfant|jeunesse|kids', 'fam'),
  (r'documentaire|doc', 'doc'),
  (r'musique|musical|concert', 'music'),
  (r'histoire|histori|biograph', 'hist'),
];

String genreIcon(String n) {
  final k = norm(n);
  for (final g in _gicons) {
    if (RegExp(g.$1).hasMatch(k)) return g.$2;
  }
  return 'film';
}

int genreHue(String n) => n.runes.fold(7, (x, c) => (x * 31 + c) % 360);

/// catégorie d'une bibliothèque
class CatInfo {
  final String id, label, kind;
  CatInfo(this.id, this.label, this.kind);
}

/// bibliothèque films ou séries prête à afficher
class Lib {
  final Kind kind;
  final List<Item> rows;                // dédoublonnées, récentes d'abord
  final Map<String, CatInfo> cats;
  Lib(this.kind, List<Item> items, Map<String, String> names)
      : cats = {for (final e in names.entries) e.key: CatInfo(e.key, catLabel(e.value), vodCatKind(catLabel(e.value)))},
        rows = dedupeItems(items);

  List<Item> inCats(Iterable<String> ids) {
    final s = ids.toSet();
    return rows.where((r) => s.contains(r.catId)).toList();
  }

  List<CatInfo> ofKind(String k) => cats.values.where((c) => c.kind == k && rows.any((r) => r.catId == c.id)).toList();

  Map<String, List<Item>>? _idx;

  /// retrouve un titre (nom TMDB) dans la bibliothèque ; l'année peut différer d'un an
  Item? byTitle(String t, {String year = ''}) {
    _idx ??= () {
      final m = <String, List<Item>>{};
      for (final r in rows) {
        (m[norm(r.title)] ??= []).add(r);
      }
      return m;
    }();
    final l = _idx![norm(t)];
    if (l == null) return null;
    for (final r in l) {
      if (year.isEmpty || r.year.isEmpty || (int.tryParse(r.year) != null && int.tryParse(year) != null && (int.parse(r.year) - int.parse(year)).abs() <= 1)) return r;
    }
    return null;
  }

  // calculés une fois (la bibliothèque ne change pas) : l'accueil les relit à chaque reconstruction
  late final List<Item> recent = uniqueTitles(rows.where((r) => r.icon.isNotEmpty)).take(14).toList();
  late final List<Item> top = (uniqueTitles(rows.where((r) => r.icon.isNotEmpty && r.rating >= 7.5 && r.rating < 9.5).toList()..sort((a, b) => b.rating.compareTo(a.rating)))).take(16).toList();
}
