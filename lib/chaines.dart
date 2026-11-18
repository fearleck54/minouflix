import 'package:flutter/material.dart' hide Text;
import 'names.dart';
import 'store.dart';
import 'ui.dart';

/// appui long sur une chaîne : favori ou masquer (les chaînes masquées disparaissent des listes, Réglages permet de les réafficher)
Future<void> chanMenu(BuildContext context, Chan c, VoidCallback changed) async {
  final fav = Store.isFav('live:${c.best.item.id}');
  final r = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: kBg2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 6), child: Align(alignment: Alignment.centerLeft, child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(17, w: 700)))),
        ListTile(autofocus: true, leading: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded), title: Text(fav ? 'Retirer des favoris' : 'Ajouter aux favoris'), onTap: () => Navigator.pop(context, 'fav')),
        ListTile(leading: const Icon(Icons.visibility_off_rounded), title: const Text('Masquer cette chaîne'), subtitle: const Text('Réglages › Chaînes masquées pour la réafficher'), onTap: () => Navigator.pop(context, 'hide')),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (r == 'fav') {
    await Store.toggleFav('live:${c.best.item.id}');
  } else if (r == 'hide') {
    await Store.setHidden({...Store.hidden, c.key});
    changed();
  }
}
