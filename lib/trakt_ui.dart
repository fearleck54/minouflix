import 'package:flutter/material.dart';
import 'trakt.dart';

/// Réglages › Trakt : lier ou délier le compte (code à saisir sur trakt.tv/activate)
Future<void> traktSheet(BuildContext context, VoidCallback changed) async {
  if (Trakt.linked) {
    final off = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Trakt'),
        content: const Text('Compte lié. Les titres vus sont envoyés à Trakt et ta liste « à voir » apparaît sur l\'accueil.'),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(c, false), child: const Text('Fermer')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Délier')),
        ],
      ),
    );
    if (off == true) {
      await Trakt.unlink();
      changed();
    }
    return;
  }
  final d = await Trakt.start();
  if (!context.mounted) return;
  if (d == null) {
    await showDialog(context: context, builder: (c) => AlertDialog(title: const Text('Trakt'), content: const Text('Trakt est injoignable pour le moment. Réessaie dans un instant.'), actions: [TextButton(autofocus: true, onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
    return;
  }
  var stop = false;
  final ok = Trakt.wait(d, () => stop);
  ok.then((v) {
    if (v && context.mounted) Navigator.of(context, rootNavigator: true).maybePop(true);
  });
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Lier Trakt'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sur un téléphone ou un ordinateur, ouvre :\n${d['verification_url']}'),
        const SizedBox(height: 14),
        const Text('et saisis le code :'),
        const SizedBox(height: 6),
        Text('${d['user_code']}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 4)),
        const SizedBox(height: 10),
        const Text('Cette fenêtre se ferme toute seule une fois le compte lié.', style: TextStyle(color: Colors.white54)),
      ]),
      actions: [TextButton(autofocus: true, onPressed: () => Navigator.pop(c, false), child: const Text('Annuler'))],
    ),
  );
  stop = true;
  if (r == true || Trakt.linked) changed();
}
