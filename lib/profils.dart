import 'package:flutter/material.dart' hide Text;
import 'account_ui.dart';
import 'auth.dart';
import 'store.dart';
import 'osk.dart';
import 'ui.dart';

/// Réglages > Profils : une liste, une reprise de lecture, des playlists et un prénom par personne (le catalogue reste commun)
class ProfilsScreen extends StatefulWidget {
  final VoidCallback onSwitch;
  const ProfilsScreen({super.key, required this.onSwitch});
  @override
  State<ProfilsScreen> createState() => _ProfilsState();
}

class _ProfilsState extends State<ProfilsScreen> {
  void _done() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onSwitch();
  }

  Future<String?> _ask(String title, String hint, [String init = '']) {
    final c = TextEditingController(text: init);
    return showDialog<String>(
      context: context,
      builder: (_) => AppDialog(
        backgroundColor: kBg2,
        title: Text(title, style: T(18, w: 700)),
        content: AppField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words, onSubmitted: (v) => Navigator.pop(context, v), decoration: InputDecoration(hintText: hint)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _add() async {
    final n = await _ask('Prénom du profil', 'Ex. : Estelle, Léo…');
    if (n == null || n.trim().isEmpty || !mounted) return;
    await Store.addProfile(n);
    if (mounted) _done();
  }

  Future<void> _menu(String id, String name) async {
    final v = await appSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text(name, style: T(18, w: 750)))),
          if (id != Store.profId) ListTile(autofocus: true, leading: const Icon(Icons.check_circle_outline), title: const Text('Utiliser ce profil'), onTap: () => Navigator.pop(context, 'use')),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Renommer'), onTap: () => Navigator.pop(context, 'name')),
          if (id.isNotEmpty) ListTile(leading: const Icon(Icons.delete_outline, color: Color(0xFFFF6B7A)), title: const Text('Supprimer', style: TextStyle(color: Color(0xFFFF6B7A))), onTap: () => Navigator.pop(context, 'del')),
          const SizedBox(height: 8),
        ]),
      ));
    if (v == null || !mounted) return;
    if (v == 'use') {
      await Store.setProfile(id);
      if (mounted) _done();
    } else if (v == 'name') {
      final n = await _ask('Renommer le profil', 'Prénom', name);
      if (n != null) {
        await Store.renameProfile(id, n);
        if (mounted) setState(() {});
      }
    } else if (v == 'del') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AppDialog(
          backgroundColor: kBg2,
          title: Text('Supprimer « $name » ?', style: T(18, w: 700)),
          content: const Text('Sa liste, sa reprise de lecture et ses playlists sont effacées de cet appareil. Le catalogue et les autres profils ne changent pas.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Color(0xFFFF6B7A))))],
        ),
      );
      if (ok != true || !mounted) return;
      final was = id == Store.profId;
      await Store.removeProfile(id);
      if (!mounted) return;
      was ? _done() : setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = Store.profiles();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 40), children: [
              Row(children: [
                RoundButton(size: 44, onTap: () => Navigator.pop(context), child: const Ic('back', size: 20)),
                const SizedBox(width: 14),
                Text('Profil et compte', style: T(26, w: 800, ls: -0.03)),
              ]),
              const SizedBox(height: 14),
              // compte : e-mail et synchronisation, au même endroit que les profils
              FocusCard(
                radius: 18,
                onTap: () async {
                  await Navigator.push(context, softRoute((ctx) => SyncChoiceScreen(first: false, onDone: () => Navigator.pop(ctx))));
                  if (mounted) setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(18), border: Border.all(color: kEdge, width: 0.8)),
                  child: Row(children: [
                    const Icon(Icons.cloud_rounded, color: kAccent),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Compte et synchronisation', style: T(16.5, w: 650)),
                      Text(Account.expired ? 'Session expirée : reconnecte-toi' : (Account.signedIn ? Account.email : 'Non connecté'), maxLines: 1, overflow: TextOverflow.ellipsis, style: T(13, color: Account.expired ? const Color(0xFFFF6B7A) : kMut)),
                    ])),
                    const Icon(Icons.chevron_right_rounded, color: kMut),
                  ]),
                ),
              ),
              const SizedBox(height: 22),
              Text('PROFILS', style: T(12, w: 700, ls: 0.09, color: kMut)),
              const SizedBox(height: 8),
              Text(Store.kid ? 'Mode enfant actif : quitte-le d\'abord (code PIN) pour changer de profil.' : 'Chaque profil a sa liste, sa reprise de lecture, ses playlists et son prénom. Le catalogue est commun. La synchronisation du compte ne concerne que le profil d\'origine.', style: T(14, color: Store.kid ? const Color(0xFFFFB86B) : kMut, h: 1.4)),
              const SizedBox(height: 18),
              for (final p in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FocusCard(
                    radius: 18,
                    onTap: Store.kid ? () {} : () => _menu(p.$1, p.$2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(18), border: Border.all(color: kEdge, width: 0.8)),
                      child: Row(children: [
                        const Icon(Icons.account_circle_rounded, color: kAccent),
                        const SizedBox(width: 14),
                        Expanded(child: Text(p.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(16.5, w: 650))),
                        Icon(p.$1 == Store.profId ? Icons.check_circle : Icons.chevron_right_rounded, color: p.$1 == Store.profId ? kAccent : kMut),
                      ]),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (!Store.kid) PillButton(label: 'Ajouter un profil', primary: true, height: 54, onTap: _add),
            ]),
          ),
        ),
      ),
    );
  }
}
