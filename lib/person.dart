import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'l10n.dart';
import 'keys.dart' show kTmdbKey;
import 'names.dart';
import 'screens.dart' show kCatalog;
import 'tmdb.dart';
import 'ui.dart';
import 'xtream.dart';

/// fiche d'un acteur : sa photo, puis ses films et ses séries présents dans le catalogue (sans clavier ni recherche)
class PersonScreen extends StatefulWidget {
  final String name, role, photo;
  final int id;
  final void Function(Item) onOpen;
  const PersonScreen({super.key, required this.name, required this.role, required this.photo, required this.id, required this.onOpen});
  @override
  State<PersonScreen> createState() => _PersonState();
}

class _PersonState extends State<PersonScreen> {
  List<Item>? films, series;
  bool done = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = <Item>[], s = <Item>[];
    try {
      if (kTmdbKey.isNotEmpty) {
        var id = widget.id;
        if (id == 0) {
          final r = await Tmdb.raw('/search/person', {'query': widget.name, 'language': L.tmdb});
          final res = r is Map ? r['results'] as List? : null;
          if (res != null && res.isNotEmpty) id = ((res.first as Map)['id'] as num).toInt();
        }
        if (id != 0) {
          final c = await Tmdb.raw('/person/$id/combined_credits', {'language': L.tmdb});
          // titres du catalogue, du plus populaire au moins populaire
          final all = <Map>[
            for (final k in ['cast', 'crew']) for (final e in (c is Map ? c[k] as List? ?? const [] : const [])) if (e is Map) e
          ]..sort((a, b) => ((b['popularity'] as num?) ?? 0).compareTo((a['popularity'] as num?) ?? 0));
          final byName = <String, Item>{};
          for (final i in kCatalog()) {
            byName.putIfAbsent(norm(i.title), () => i);
          }
          final seen = <String>{};
          for (final e in all) {
            for (final fld in ['title', 'original_title', 'name', 'original_name']) {
              final v = '${e[fld] ?? ''}';
              final it = v.isEmpty ? null : byName[norm(v)];
              if (it != null && seen.add('${it.kind.name}:${it.id}')) (it.kind == Kind.series ? s : f).add(it);
            }
          }
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      films = uniqueTitles(f);
      series = uniqueTitles(s);
      done = true;
    });
    if (Device.tv) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? FocusScope.of(context).nextFocus() : null);
  }

  @override
  Widget build(BuildContext context) {
    final pw = Device.tv ? 150.0 : 128.0, ph = pw * 1.5 + 44;
    Widget rail(String t, List<Item> l) => Rail(title: t, height: ph, count: l.length, moreLabel: '', builder: (_, i) => Poster(item: l[i], width: pw, onTap: () => widget.onOpen(l[i])));
    final none = done && (films?.isEmpty ?? true) && (series?.isEmpty ?? true);
    return DsBg(child: Scaffold(backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(cacheExtent: Device.tv ? 1800 : null, padding: const EdgeInsets.only(bottom: 60), children: [
          Padding(
            padding: EdgeInsets.fromLTRB(Device.tv ? 48 : 16, 16, 16, 18),
            child: Row(children: [
              if (!Device.tv) ...[RoundButton(size: 44, label: 'Retour', onTap: () => Navigator.pop(context), child: const Ic('back', size: 20)), const SizedBox(width: 14)],
              ClipOval(child: SizedBox(width: 96, height: 96, child: widget.photo.isEmpty ? Container(color: kBg3) : netImage(tmImg(widget.photo, 'w185'), ''))),
              const SizedBox(width: 20),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(Device.tv ? 34 : 26, w: 800, ls: -0.02)),
                  if (widget.role.isNotEmpty) Text('Rôle : ${widget.role}', maxLines: 1, overflow: TextOverflow.ellipsis, style: T(15, color: kMut)),
                ]),
              ),
            ]),
          ),
          if (!done) const Padding(padding: EdgeInsets.all(48), child: Center(child: Spinner())),
          if (films != null) rail('Films', films!),
          if (series != null) rail('Séries', series!),
          if (none) Padding(padding: const EdgeInsets.all(40), child: Text('Aucun film ni série de cet acteur dans ton catalogue.', style: T(17, color: kMut))),
        ]),
      ),
    ));
  }
}
