import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'journal.dart';
import 'store.dart';
import 'ui.dart';
import 'xtream.dart';

/// « Tester ma source » : joint le fournisseur, vérifie l'abonnement et dit en clair ce qui ne va pas
Future<void> testSource(BuildContext context) async {
  final c = await Store.creds();
  if (c == null || !context.mounted) return;
  final fut = _lines(c);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AppDialog(
      backgroundColor: kBg2,
      title: Text('Test de la source', style: T(18, w: 700)),
      content: FutureBuilder<List<(bool, String)>>(
        future: fut,
        builder: (_, s) => !s.hasData
            ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
            : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final l in s.data!)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(l.$1 ? Icons.check_circle_rounded : Icons.error_rounded, size: 20, color: l.$1 ? const Color(0xFF30D158) : const Color(0xFFFF6B7A)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.$2, style: T(14.5, h: 1.35))),
                  ])),
              ]),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final l = await fut;
            final j = await Journal.read();
            await Clipboard.setData(ClipboardData(text: 'Diagnostic MinouFlix\n${[for (final x in l) '${x.$1 ? 'OK' : 'PROBLÈME'} : ${x.$2}'].join('\n')}\n\nJournal :\n$j'));
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Diagnostic copié : colle-le dans un message.')));
          },
          child: const Text('Copier le diagnostic'),
        ),
        TextButton(autofocus: true, onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
      ],
    ),
  );
}

Future<List<(bool, String)>> _lines(Creds c) async {
  final out = <(bool, String)>[];
  final x = Xtream(c);
  final t0 = DateTime.now();
  try {
    final m = await x.authenticate();
    final ms = DateTime.now().difference(t0).inMilliseconds;
    out.add((true, 'Le fournisseur répond en ${ms < 1000 ? '$ms ms' : '${(ms / 1000).toStringAsFixed(1)} s'}.'));
    final st = x.info['status'] ?? '';
    out.add((st.isEmpty || st.toLowerCase() == 'active', st.isEmpty || st.toLowerCase() == 'active' ? 'Compte actif : $m.' : 'Le compte est « $st » : contacte ton fournisseur.'));
    final mx = int.tryParse(x.info['max'] ?? ''), ac = int.tryParse(x.info['active'] ?? '');
    if (mx != null) out.add((ac == null || ac < mx, ac == null ? 'Jusqu\'à $mx écrans en même temps.' : '$ac écran(s) en cours sur $mx autorisé(s)${ac >= mx ? ' : ferme la lecture sur un autre appareil' : ''}.'));
    for (final k in Kind.values) {
      final n = (Store.selection(k) ?? []).length;
      if (n == 0) continue;
      final have = (await Store.cachedCats(k, Store.selection(k)!)).length;
      out.add((have == n, '${k == Kind.live ? 'Direct' : k == Kind.vod ? 'Films' : 'Séries'} : $have/$n catégories chargées${have == n ? '' : ' (le reste se charge en arrière-plan)'}.'));
    }
  } catch (e) {
    Journal.add('Test de la source', e);
    final m = '$e'.replaceFirst('XtreamError: ', '');
    out.add((false, m));
    out.add((false, m.contains('refusés') ? 'Vérifie l\'identifiant, le mot de passe et l\'adresse du serveur dans Sources IPTV.' : 'Vérifie ta connexion Internet ; si elle marche, le fournisseur est peut-être en panne ou t\'a bloqué (trop de requêtes).'));
  }
  return out;
}
