import 'package:flutter/material.dart' hide Text;
import 'diag.dart';
import 'screens.dart';
import 'store.dart';
import 'osk.dart';
import 'ui.dart';

/// Réglages > Sources IPTV : ajouter, utiliser, renommer, supprimer (une seule source active à la fois)
class SourcesScreen extends StatefulWidget {
  final VoidCallback onSwitch;
  const SourcesScreen({super.key, required this.onSwitch});
  @override
  State<SourcesScreen> createState() => _SourcesState();
}

class _SourcesState extends State<SourcesScreen> {
  List<(String, String)> list = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Store.sources();
    if (mounted) setState(() => list = l);
  }

  /// retour à l'accueil, rechargé avec la source active
  void _done() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onSwitch();
  }

  Future<String?> _ask(String title, String hint, [String init = '']) {
    final c = TextEditingController(text: init);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kBg2,
        title: Text(title, style: T(18, w: 700)),
        content: AppField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words, onSubmitted: (v) => Navigator.pop(context, v), decoration: InputDecoration(hintText: hint)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _add() async {
    final n = await _ask('Nom de la source', 'Ex. : Salon, Famille…');
    if (n == null || !mounted) return;
    Store.beginSource(n);
    await Navigator.push(context, softRoute((_) => LoginScreen(adding: true, onDone: (_) => _done())));
    if (mounted) _load();     // retour sans validation : aucune source créée
  }

  Future<void> _menu(String id, String name) async {
    final active = id == Store.activeId;
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kBg2,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text(name, style: T(18, w: 750)))),
          if (!active) ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('Utiliser cette source'), onTap: () => Navigator.pop(context, 'use')),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Renommer'), onTap: () => Navigator.pop(context, 'name')),
          if (list.length > 1) ListTile(leading: const Icon(Icons.delete_outline, color: Color(0xFFFF6B7A)), title: const Text('Supprimer', style: TextStyle(color: Color(0xFFFF6B7A))), onTap: () => Navigator.pop(context, 'del')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (v == null || !mounted) return;
    if (v == 'use') {
      await Store.setActive(id);
      if (mounted) _done();
    } else if (v == 'name') {
      final n = await _ask('Renommer la source', 'Nom', name);
      if (n != null) {
        await Store.renameSource(id, n);
        _load();
      }
    } else if (v == 'del') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: kBg2,
          title: Text('Supprimer « $name » ?', style: T(18, w: 700)),
          content: const Text('Ses identifiants, son catalogue, sa liste et sa reprise sont effacés de cet appareil. Les autres sources ne changent pas.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer', style: TextStyle(color: Color(0xFFFF6B7A))))],
        ),
      );
      if (ok != true || !mounted) return;
      final wasActive = id == Store.activeId;
      await Store.removeSource(id);
      if (!mounted) return;
      wasActive ? _done() : _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 40), children: [
                Row(children: [
                  RoundButton(size: 44, onTap: () => Navigator.pop(context), child: const Ic('back', size: 20)),
                  const SizedBox(width: 14),
                  Text('Sources IPTV', style: T(26, w: 800, ls: -0.03)),
                ]),
                const SizedBox(height: 10),
                Text('Une seule source est utilisée à la fois. Chaque source garde son catalogue, sa liste et sa reprise.', style: T(14, color: kMut, h: 1.4)),
                const SizedBox(height: 18),
                for (final s in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: FocusCard(
                      radius: 18,
                      onTap: () => _menu(s.$1, s.$2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(18), border: Border.all(color: kEdge, width: 0.8)),
                        child: Row(children: [
                          const Icon(Icons.dns_rounded, color: kAccent),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(16.5, w: 650)), if (s.$1 == Store.activeId) Text('Source utilisée', style: T(13, color: kAccent))])),
                          Icon(s.$1 == Store.activeId ? Icons.check_circle : Icons.chevron_right_rounded, color: s.$1 == Store.activeId ? kAccent : kMut),
                        ]),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                PillButton(label: 'Ajouter une source', primary: true, height: 54, onTap: _add),
                const SizedBox(height: 10),
                PillButton(label: 'Tester la source utilisée', height: 54, onTap: () => testSource(context)),
              ]),
            ),
          ),
        ),
      );
}
