import 'package:flutter/material.dart' hide Text;
import 'diag.dart';
import 'xtream.dart';
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
      builder: (_) => AppDialog(
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
    final v = await appSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text(name, style: T(18, w: 750)))),
          if (!active) ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('Utiliser cette source'), onTap: () => Navigator.pop(context, 'use')),
          ListTile(leading: const Icon(Icons.tune_rounded), title: const Text('Modifier la source'), subtitle: const Text('Adresse, identifiant, mot de passe'), onTap: () => Navigator.pop(context, 'edit')),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Renommer'), onTap: () => Navigator.pop(context, 'name')),
          if (list.length > 1) ListTile(leading: const Icon(Icons.delete_outline, color: Color(0xFFFF6B7A)), title: const Text('Supprimer', style: TextStyle(color: Color(0xFFFF6B7A))), onTap: () => Navigator.pop(context, 'del')),
          const SizedBox(height: 8),
        ]),
      ));
    if (v == null || !mounted) return;
    if (v == 'use') {
      await Store.setActive(id);
      if (mounted) _done();
    } else if (v == 'edit') {
      final c = await Store.credsOf(id);
      if (c == null || !mounted) return;
      final ok = await Navigator.push<bool>(context, softRoute((_) => SourceEditScreen(id: id, name: name, creds: c)));
      if (ok == true && mounted) id == Store.activeId ? _done() : _load();
    } else if (v == 'name') {
      final n = await _ask('Renommer la source', 'Nom', name);
      if (n != null) {
        await Store.renameSource(id, n);
        _load();
      }
    } else if (v == 'del') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AppDialog(
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


/// Modifier une source en place : on teste les nouvelles valeurs chez le fournisseur avant d'enregistrer ; la sélection de catégories, la liste et la reprise sont gardées
class SourceEditScreen extends StatefulWidget {
  final String id, name;
  final Creds creds;
  const SourceEditScreen({super.key, required this.id, required this.name, required this.creds});
  @override
  State<SourceEditScreen> createState() => _SourceEditState();
}

class _SourceEditState extends State<SourceEditScreen> {
  late final name = TextEditingController(text: widget.name);
  late final server = TextEditingController(text: widget.creds.server);
  late final user = TextEditingController(text: widget.creds.isM3u ? '' : widget.creds.user);
  late final pass = TextEditingController(text: widget.creds.pass);
  bool busy = false, hide = true;
  String? error;
  bool get m3u => widget.creds.isM3u;

  Creds get _creds => m3u ? Creds.m3u(server.text.trim()) : Creds(server.text.trim(), user.text.trim(), pass.text);

  Future<void> _save({bool force = false}) async {
    if (busy) return;
    if (server.text.trim().isEmpty || (!m3u && (user.text.trim().isEmpty || pass.text.isEmpty))) {
      setState(() => error = m3u ? 'Renseigne l\'adresse de la playlist.' : 'Renseigne l\'adresse du serveur, l\'identifiant et le mot de passe.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final c = _creds;
    if (!force) {
      try {
        await Xtream(c).authenticate();
      } catch (e) {
        if (mounted) {
          setState(() {
            busy = false;
            error = '$e'.replaceFirst('XtreamError: ', '');
          });
        }
        return;
      }
    }
    await Store.updateSource(widget.id, name.text, c);
    if (mounted) Navigator.pop(context, true);
  }

  Widget _field(String label, TextEditingController c, {bool secret = false, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppField(
          controller: c,
          obscureText: secret && hide,
          autocorrect: false,
          keyboardType: type,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: const Color(0x3D767680),
            contentPadding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
            border: UnderlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kAccent, width: 1.2)),
            suffixIcon: secret ? IconButton(icon: Icon(hide ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: kMut), onPressed: () => setState(() => hide = !hide)) : null,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 40), children: [
                Row(children: [
                  RoundButton(size: 44, onTap: () => Navigator.pop(context, false), child: const Ic('back', size: 20)),
                  const SizedBox(width: 14),
                  Expanded(child: Text('Modifier la source', style: T(26, w: 800, ls: -0.03))),
                ]),
                const SizedBox(height: 10),
                Text('Tes catégories choisies, ta liste et ta reprise sont gardées. Les nouvelles valeurs sont testées avant d\'être enregistrées.', style: T(14, color: kMut, h: 1.4)),
                const SizedBox(height: 20),
                _field('Nom de la source', name),
                _field(m3u ? 'Adresse de la playlist (http://…)' : 'Adresse du serveur (http://…)', server, type: TextInputType.url),
                if (!m3u) ...[_field('Identifiant', user), _field('Mot de passe', pass, secret: true)],
                if (error != null) ...[
                  Padding(padding: const EdgeInsets.only(top: 2, bottom: 10), child: Text(error!, style: T(14, color: const Color(0xFFFF6B7A), h: 1.4))),
                  PillButton(label: 'Enregistrer quand même', height: 50, onTap: () => _save(force: true)),
                  const SizedBox(height: 10),
                ],
                PillButton(label: busy ? 'Test en cours…' : 'Tester et enregistrer', primary: true, height: 54, onTap: _save),
              ]),
            ),
          ),
        ),
      );
}
