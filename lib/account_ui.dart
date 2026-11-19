import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'auth.dart';
import 'connect.dart';
import 'store.dart';
import 'sync.dart';
import 'pairing.dart';
import 'phone_entry.dart';
import 'xtream.dart';
import 'osk.dart';
import 'ui.dart';

/// ---------- connexion / création de compte ----------
class AuthScreen extends StatefulWidget {
  final VoidCallback onDone;
  const AuthScreen({super.key, required this.onDone});
  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  final mail = TextEditingController(), pw = TextEditingController();
  bool create = true, busy = false;
  String? msg;
  late final PhoneEntry phone = PhoneEntry(const [('mail', 'E-mail', false), ('pw', 'Mot de passe', true)], (f) {
    mail.text = f['mail'] ?? '';
    pw.text = f['pw'] ?? '';
    if (mounted) go();
  });

  final code = Pairing.newCode();
  Timer? _poll;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    if (Connect.tvNow) {
      phone.start(() {
        if (mounted) setState(() {});
      });
    }
    if (Connect.tvNow) _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_polling || busy) return;      // une requête lente ne doit pas en lancer une deuxième
      _polling = true;
      final m = await Pairing.poll(code);
      _polling = false;
      if (m == null && mounted) setState(() {});      // l'incident éventuel (Pairing.last) s'affiche
      if (m == null || !mounted) return;
      _poll?.cancel();
      final e = await Account.signIn('${m['e']}', '${m['p']}');
      if (e != null) {
        if (mounted) setState(() => msg = e);
        return;
      }
      if (m['c'] is Map) {
        final c = Creds.fromJson((m['c'] as Map).cast<String, dynamic>());
        if (c != null) await Store.saveCreds(c);
      }
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    phone.stop();
    super.dispose();
  }

  Future<void> go() async {
    if (busy) return;
    if (mail.text.trim().isEmpty || pw.text.length < 6) {
      setState(() => msg = 'E-mail et mot de passe (6 caractères minimum).');
      return;
    }
    setState(() {
      busy = true;
      msg = null;
    });
    final e = create ? await Account.signUp(mail.text, pw.text) : await Account.signIn(mail.text, pw.text);
    if (!mounted) return;
    if (e == null) {
      widget.onDone();
      return;
    }
    setState(() {
      busy = false;
      msg = e == 'confirm' ? 'Compte créé. Confirme ton e-mail (lien reçu), puis connecte-toi.' : e;
      if (e == 'confirm') create = false;
    });
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
        step: 0,
        text: create ? 'Crée ton compte pour retrouver ta liste et ta reprise partout.' : 'Connecte-toi à ton compte.',
        side: !Connect.tvNow ? const [] : [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Déjà connecté sur ton téléphone ?', style: T(14, color: kMut)),
              const SizedBox(height: 4),
              Text(Pairing.show(code), style: T(32, w: 850, ls: 0.1)),
              const SizedBox(height: 4),
              Text('Sur le téléphone : Réglages → Connecter une télé, puis saisis ce code.', style: T(13, color: kMut)),
              if (Pairing.last.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(Pairing.last, style: T(13, color: const Color(0xFFFFB86B), h: 1.35))),
            ]),
          ),
          if (phone.url != null) phone.card(qr: AuthLayout.wide(context) ? 150 : 110),
        ],
        form: [
          AppField(controller: mail, keyboardType: TextInputType.emailAddress, autocorrect: false, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder())),
          const SizedBox(height: 14),
          AppField(controller: pw, obscureText: true, onSubmitted: (_) => go(), decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder())),
          if (msg != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(msg!, style: T(14, color: msg!.startsWith('Compte créé') ? const Color(0xFF30D158) : const Color(0xFFFF6B7A)))),
          const SizedBox(height: 22),
          FilledButton(onPressed: busy ? null : go, child: Padding(padding: const EdgeInsets.all(14), child: busy ? const SizedBox(height: 18, width: 18, child: Spinner(strokeWidth: 2)) : Text(create ? 'Créer mon compte' : 'Se connecter'))),
          const SizedBox(height: 10),
          TextButton(onPressed: () => setState(() {
                create = !create;
                msg = null;
              }), child: Text(create ? 'J\'ai déjà un compte' : 'Créer un compte')),
          TextButton(onPressed: () async {
            await Store.setFlag('noacct', true);
            if (mounted) widget.onDone();
          }, child: Text('Continuer sans compte', style: T(14, color: kMut))),
        ],
      );
}

/// ---------- choix des informations synchronisées ----------
class SyncChoiceScreen extends StatefulWidget {
  final VoidCallback onDone;
  final bool first;
  const SyncChoiceScreen({super.key, required this.onDone, this.first = true});
  @override
  State<SyncChoiceScreen> createState() => _SyncChoiceState();
}

class _SyncChoiceState extends State<SyncChoiceScreen> {
  Future<void> done() async {
    await Store.setSyncAsked();
    unawaited(Sync.run());
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.first ? null : AppBar(title: const Text('Compte et synchronisation'), backgroundColor: Colors.transparent),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
                if (widget.first) ...[Text('Que veux-tu synchroniser ?', style: T(26, w: 800, ls: -0.03)), const SizedBox(height: 6)],
                Text(Account.signedIn ? 'Compte : ${Account.email}' : 'Pas de compte : rien n\'est synchronisé.', style: T(14, color: kMut)),
                const SizedBox(height: 14),
                if (!Account.signedIn && !widget.first)
                  FilledButton(
                    onPressed: () async {
                      await Navigator.push(context, softRoute((_) => AuthScreen(onDone: () => Navigator.pop(context))));
                      if (mounted) setState(() {});
                    },
                    child: const Padding(padding: EdgeInsets.all(14), child: Text('Se connecter / créer un compte')),
                  ),
                if (Account.signedIn)
                  for (final o in Sync.opts)
                    SwitchListTile(
                      value: Sync.opt(o.$1),
                      activeColor: Colors.white,
                      activeTrackColor: const Color(0xFF30D158),
                      title: Text(o.$2, style: T(16, w: 650)),
                      subtitle: Text(o.$3, style: T(13, color: kMut)),
                      onChanged: (v) async {
                        await Store.setFlag('sync_${o.$1}', v);
                        setState(() {});
                      },
                    ),
                const SizedBox(height: 18),
                FilledButton(onPressed: done, child: Padding(padding: const EdgeInsets.all(14), child: Text(widget.first ? 'Continuer' : 'Enregistrer'))),
                if (!widget.first && Account.signedIn) TextButton(onPressed: () async {
                      await Account.signOut();
                      if (context.mounted) Navigator.of(context).pop();
                    }, child: const Text('Se déconnecter du compte')),
              ]),
            ),
          ),
        ),
      );
}

/// ---------- page de chargement : logo, message et barre d'avancement ----------
class LoadingScreen extends StatelessWidget {
  final String status;
  const LoadingScreen({super.key, this.status = 'Chargement du catalogue…'});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 34, height: 34, child: Spinner(strokeWidth: 3, color: Colors.white70)),
              const SizedBox(height: 22),
              Text(status, textAlign: TextAlign.center, style: T(16, w: 600, color: kMut, h: 1.4)),
            ]),
          ),
        ),
      );
}
