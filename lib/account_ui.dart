import 'perf.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
import 'intro.dart';
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
  bool _intro = true;      // premier écran : avantages du compte, puis choix (créer · se connecter · continuer sans compte)
  String? msg;
  late final PhoneEntry phone = PhoneEntry(const [('mail', 'E-mail', false), ('pw', 'Mot de passe', true)], (f) {
    mail.text = f['mail'] ?? '';
    pw.text = f['pw'] ?? '';
    if (mounted) go();
  });

  final code = Pairing.newCode();
  Timer? _poll;
  bool _polling = false;
  bool _linked = false;
  bool _ready = false;      // QR affiché seulement quand le serveur répond et que la clé est calculée
  bool _keyOk = false;

  @override
  void initState() {
    super.initState();
    if (Connect.tvNow) {
      phone.start(() {
        if (mounted) setState(() {});
      });
    }
    if (Connect.tvNow) {
      unawaited(Pairing.warm(code).then((_) => _keyOk = true).catchError((_) {}));
      _poll = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
      _tick();
    }
  }

  Future<void> _tick() async {
      if (_polling || busy) return;      // une requête lente ne doit pas en lancer une deuxième
      _polling = true;
      final m = await Pairing.poll(code);
      if (m == null) {
        _polling = false;
        if (mounted) setState(() => _ready = _ready || (Pairing.last.isEmpty && _keyOk));      // l'incident éventuel (Pairing.last) s'affiche
        return;
      }
      if (!mounted) return;
      setState(() => _linked = true);      // le téléphone a répondu : on le montre tout de suite
      var e = await Account.signIn('${m['e']}', '${m['p']}');
      if (e != null) {
        await Future<void>.delayed(const Duration(seconds: 2));
        e = await Account.signIn('${m['e']}', '${m['p']}');      // un 2e essai avant d'abandonner (coupure brève)
      }
      if (e != null) {
        // échec : on garde l'écoute (le paquet reste sur le serveur), un nouveau scan ou le prochain tour réessaie
        _polling = false;
        if (mounted) setState(() {
          _linked = false;
          msg = e;
        });
        return;
      }
      _poll?.cancel();
      unawaited(Pairing.clear(code));      // le paquet n'est effacé qu'une fois la connexion réussie
      if (m['c'] is Map) {
        final c = Creds.fromJson((m['c'] as Map).cast<String, dynamic>());
        if (c != null) await Store.saveCreds(c);
      }
      if (mounted) widget.onDone();
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
  Widget build(BuildContext context) => Stack(children: [
        _layout(),
        if (_linked)
          Positioned.fill(
            child: Container(
              color: const Color(0xE6000000),
              alignment: Alignment.center,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Spinner(),
                const SizedBox(height: 22),
                Text('Téléphone reconnu', style: T(30, w: 750)),
                const SizedBox(height: 8),
                Text('Connexion de ton compte et chargement de tes sources…', style: T(18, color: kMut)),
              ]),
            ),
          ),
      ]);

  List<Widget> _introForm() => [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Avec un compte MinouFlix', style: T(16, w: 750)),
            const SizedBox(height: 10),
            for (final t in const [
              'Ta liste et ta reprise sur tous tes appareils',
              'Réinstalle ou change d\'appareil sans rien refaire',
              'Connecte ta télé en scannant un code',
              'Identifiants IPTV chiffrés, illisibles par le serveur',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF30D158))),
                  const SizedBox(width: 9),
                  Expanded(child: Text(t, style: T(14, h: 1.3))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Text('Sans compte, tout marche aussi : seulement sur cet appareil.', style: T(13, color: kMut, h: 1.35)),
        const SizedBox(height: 14),
        PillButton(primary: true, height: 54, label: 'Créer mon compte', onTap: () => setState(() {
              _intro = false;
              create = true;
            })),
        const SizedBox(height: 10),
        PillButton(label: 'J\'ai déjà un compte', onTap: () => setState(() {
              _intro = false;
              create = false;
            })),
        const SizedBox(height: 10),
        PillButton(label: 'Continuer sans compte', onTap: () async {
          await Store.setFlag('noacct', true);
          if (mounted) widget.onDone();
        }),
      ];

  Widget _layout() => AuthLayout(
        step: 0,
        text: _intro ? 'Bienvenue sur MinouFlix.' : (create ? 'Crée ton compte pour retrouver ta liste et ta reprise partout.' : 'Connecte-toi à ton compte.'),
        side: !Connect.tvNow ? const [] : [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(18)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Déjà connecté sur ton téléphone ?', textAlign: TextAlign.center, style: T(18, w: 700)),
              const SizedBox(height: 4),
              Text('Scanne ce code : l\'appli s\'ouvre et connecte la télé.', textAlign: TextAlign.center, style: T(14, color: kMut, h: 1.3)),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: _ready ? QrImageView(data: 'minouflix://pair?c=$code', size: 150, padding: EdgeInsets.zero, backgroundColor: Colors.white) : const SizedBox(width: 150, height: 150, child: Center(child: SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFFF2D45)))))),
              const SizedBox(height: 10),
              Text(Pairing.show(code), style: T(24, w: 850, ls: 0.08)),
              Text('ou Réglages → Connecter une télé', style: T(13, color: kMut)),
              if (Pairing.last.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(Pairing.last, textAlign: TextAlign.center, style: T(13, color: const Color(0xFFFFB86B), h: 1.35))),
            ]),
          ),
        ],
        form: _intro ? _introForm() : [
          AppField(controller: mail, keyboardType: TextInputType.emailAddress, autocorrect: false, autofillHints: const [AutofillHints.email], decoration: InputDecoration(labelText: 'E-mail', filled: true, fillColor: const Color(0x1AFFFFFF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kEdge)))),
          const SizedBox(height: 14),
          AppField(controller: pw, obscureText: true, onSubmitted: (_) => go(), decoration: InputDecoration(labelText: 'Mot de passe', filled: true, fillColor: const Color(0x1AFFFFFF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kEdge)))),
          if (msg != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(msg!, style: T(14, color: msg!.startsWith('Compte créé') ? const Color(0xFF30D158) : const Color(0xFFFF6B7A)))),
          const SizedBox(height: 22),
          PillButton(primary: true, height: 54, label: busy ? 'Connexion…' : (create ? 'Créer mon compte' : 'Se connecter'), onTap: () {
            if (!busy) go();
          }),
          if (!create) ...[
            const SizedBox(height: 10),
            PillButton(label: 'Mot de passe oublié ?', onTap: () async {
              final ok = await Navigator.push<bool>(context, softRoute((_) => ResetPasswordScreen(mail: mail.text)));
              if (ok == true && mounted) widget.onDone();
            }),
          ],
          const SizedBox(height: 10),
          PillButton(label: create ? 'J\'ai déjà un compte' : 'Créer un compte', onTap: () => setState(() {
                create = !create;
                msg = null;
              })),
          const SizedBox(height: 10),
          PillButton(label: 'Continuer sans compte', onTap: () async {
            await Store.setFlag('noacct', true);
            if (mounted) widget.onDone();
          }),
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
    await Sync.run().timeout(const Duration(seconds: 15), onTimeout: () => false);
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) => DsBg(child: Scaffold(backgroundColor: Colors.transparent, 
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
                FilledButton(
                  onPressed: done,
                  style: Device.tv
                      ? ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.focused) ? Colors.white : Colors.transparent),
                          foregroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.focused) ? kBg : Colors.white),
                          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                        )
                      : null,
                  child: Padding(padding: const EdgeInsets.all(14), child: Text(widget.first ? 'Continuer' : 'Enregistrer'))),
                if (!widget.first && Account.signedIn) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Pour te déconnecter ou supprimer ton compte : Réglages › Déconnexion et suppression.', textAlign: TextAlign.center, style: T(13, color: kMut, h: 1.35))),
              ]),
            ),
          ),
        ),
      ));
}

/// ---------- page de chargement : logo, message et barre d'avancement ----------
class LoadingScreen extends StatelessWidget {
  final String status;
  const LoadingScreen({super.key, this.status = 'Chargement du catalogue…'});

  @override
  Widget build(BuildContext context) => BrandIntro(status: status);
}


/// ---------- mot de passe oublié : e-mail → code à 6 chiffres → nouveau mot de passe ----------
class ResetPasswordScreen extends StatefulWidget {
  final String mail;
  const ResetPasswordScreen({super.key, this.mail = ''});
  @override
  State<ResetPasswordScreen> createState() => _ResetState();
}

class _ResetState extends State<ResetPasswordScreen> {
  late final mail = TextEditingController(text: widget.mail);
  final code = TextEditingController(), pw = TextEditingController();
  bool sent = false, busy = false;
  String? msg;

  InputDecoration _dec(String l) => InputDecoration(labelText: l, filled: true, fillColor: const Color(0x1AFFFFFF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none));

  Future<void> _send() async {
    if (busy) return;
    if (!mail.text.contains('@')) {
      setState(() => msg = 'Saisis ton adresse e-mail.');
      return;
    }
    setState(() {
      busy = true;
      msg = null;
    });
    final e = await Account.sendReset(mail.text);
    if (!mounted) return;
    setState(() {
      busy = false;
      sent = e == null;
      msg = e;
    });
  }

  Future<void> _apply() async {
    if (busy) return;
    if (code.text.trim().length < 6 || pw.text.length < 6) {
      setState(() => msg = 'Code à 6 chiffres et nouveau mot de passe (6 caractères minimum).');
      return;
    }
    setState(() {
      busy = true;
      msg = null;
    });
    final e = await Account.resetWithCode(mail.text, code.text, pw.text);
    if (!mounted) return;
    if (e == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      busy = false;
      msg = e;
    });
  }

  @override
  Widget build(BuildContext context) => DsBg(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: const Text('Mot de passe oublié'), backgroundColor: Colors.transparent),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
                  Text(sent ? 'Un code à 6 chiffres vient d\'être envoyé à ${mail.text.trim()}. Saisis-le avec ton nouveau mot de passe.' : 'Saisis l\'e-mail de ton compte : tu recevras un code pour choisir un nouveau mot de passe.', style: T(15, color: kMut, h: 1.35)),
                  const SizedBox(height: 16),
                  AppField(controller: mail, keyboardType: TextInputType.emailAddress, autocorrect: false, autofillHints: const [AutofillHints.email], decoration: _dec('E-mail'), onSubmitted: (_) => sent ? null : _send()),
                  if (sent) ...[
                    const SizedBox(height: 14),
                    AppField(controller: code, keyboardType: TextInputType.number, decoration: _dec('Code reçu par e-mail')),
                    const SizedBox(height: 14),
                    AppField(controller: pw, obscureText: true, decoration: _dec('Nouveau mot de passe'), onSubmitted: (_) => _apply()),
                  ],
                  if (msg != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(msg!, style: T(14, color: const Color(0xFFFF6B7A)))),
                  const SizedBox(height: 22),
                  PillButton(primary: true, height: 54, label: busy ? 'Un instant…' : (sent ? 'Changer le mot de passe' : 'Envoyer le code'), onTap: () => sent ? _apply() : _send()),
                  if (sent) ...[
                    const SizedBox(height: 10),
                    PillButton(label: 'Renvoyer un code', onTap: _send),
                  ],
                  const SizedBox(height: 14),
                  Text('Tes sources IPTV sont chiffrées avec ton mot de passe : après un changement de mot de passe, il faudra peut-être les ressaisir une fois.', style: T(12.5, color: kMut, h: 1.35)),
                ]),
              ),
            ),
          ),
        ),
      );
}
