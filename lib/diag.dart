import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'journal.dart';
import 'perf.dart';
import 'connect.dart';
import 'auth.dart';
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
            ? const SizedBox(height: 60, child: Center(child: Spinner()))
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
  out.add((true, 'Appareil : ${Device.tv ? 'télé (reçoit les commandes)' : 'téléphone ou tablette'}.'));
  out.add((Account.signedIn, Account.signedIn ? 'Compte MinouFlix : connecté (${Account.email}).' : 'Compte MinouFlix : non connecté (la télécommande et la synchro en ont besoin).'));
  if (Account.signedIn) out.add((Connect.canSend, Connect.canSend ? 'Télécommande : prête.' : 'Télécommande : indisponible (clé du compte absente) : déconnecte puis reconnecte le compte.'));
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
      final cats = await Store.cachedCats(k, Store.selection(k)!);
      final have = cats.length;
      if (k == Kind.live) {
        // rattrapage (archive) : utile pour revoir un but depuis la chaîne du match
        final all = [for (final e in cats.values) ...e.$2];
        final arch = all.where((i) => i.arch > 0).toList();
        final sp = RegExp(r'sport|bein|eurosport|dazn|ligue|foot|rmc|canal\+', caseSensitive: false);
        final sa = arch.where((i) => sp.hasMatch(i.name)).toList();
        final days = arch.isEmpty ? 0 : arch.map((i) => i.arch).reduce((a, b) => a > b ? a : b);
        out.add((true, 'Rattrapage : ${arch.length}/${all.length} chaînes (jusqu\'à $days j), dont ${sa.length} de sport/foot' + (sa.isEmpty ? '.' : ' : ' + sa.take(6).map((i) => '${i.name} ${i.arch} j').join(', ') + '.')));
      }
      out.add((have == n, '${k == Kind.live ? 'Direct' : k == Kind.vod ? 'Films' : 'Séries'} : $have/$n catégories chargées${have == n ? '' : ' (le reste se charge en arrière-plan)'}.'));
    }
  } catch (e) {
    Journal.add('Test de la source', e);
    final m = '$e'.replaceFirst('XtreamError: ', '');
    out.add((false, m));
    out.addAll(await _raw(c));
    out.add((false, m.contains('refusés') ? 'Vérifie l\'identifiant, le mot de passe et l\'adresse du serveur dans Sources IPTV.' : 'Vérifie ta connexion Internet ; si elle marche, le fournisseur est peut-être en panne ou t\'a bloqué (trop de requêtes).'));
  }
  return out;
}

/// test « à la main » (connexion brute, sans le client HTTP de l'appli) : dit si le blocage est avant ou après l'envoi de la demande
Future<List<(bool, String)>> _raw(Creds c) async {
  final out = <(bool, String)>[];
  try {
    final u = Uri.parse(c.base);
    final tls = u.scheme == 'https';
    final port = u.hasPort ? u.port : (tls ? 443 : 80);
    final t0 = DateTime.now();
    final addrs = await InternetAddress.lookup(u.host).timeout(const Duration(seconds: 8));
    out.add((true, 'Adresse du serveur trouvée (${addrs.map((a) => a.type == InternetAddressType.IPv6 ? 'IPv6' : 'IPv4').toSet().join(' + ')}).'));
    for (final ua in ['VLC/3.0.20 LibVLC/3.0.20', 'Dart']) {
      final t1 = DateTime.now();
      Socket? so;
      try {
        so = tls ? await SecureSocket.connect(u.host, port, timeout: const Duration(seconds: 8)) : await Socket.connect(u.host, port, timeout: const Duration(seconds: 8));
        final ms = DateTime.now().difference(t1).inMilliseconds;
        so.write('GET /player_api.php?username=${Uri.encodeQueryComponent(c.user)}&password=${Uri.encodeQueryComponent(c.pass)} HTTP/1.1\r\nHost: ${u.host}\r\nUser-Agent: $ua\r\nAccept: */*\r\nConnection: close\r\n\r\n');
        await so.flush();
        final buf = <int>[];
        await so.timeout(const Duration(seconds: 10), onTimeout: (sink) => sink.close()).forEach((d) {
          if (buf.length < 600) buf.addAll(d);
        });
        final first = utf8.decode(buf, allowMalformed: true).split('\r\n').first;
        out.add((buf.isNotEmpty, buf.isEmpty ? 'Connexion brute ($ua) : connectée en $ms ms, puis fermée par le serveur sans réponse.' : 'Connexion brute ($ua) : $ms ms, réponse « ${first.length > 40 ? first.substring(0, 40) : first} ».'));
      } catch (e) {
        out.add((false, 'Connexion brute ($ua) : ${e.runtimeType}.'));
      } finally {
        so?.destroy();
      }
    }
    Journal.add('Test brut du fournisseur : ${out.map((e) => e.$2).join(' | ')} (${DateTime.now().difference(t0).inMilliseconds} ms)');
  } catch (e) {
    out.add((false, 'Test brut impossible : ${e.runtimeType}.'));
  }
  return out;
}
