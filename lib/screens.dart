import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb, ValueListenable;
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSlidingSegmentedControl;
import 'package:flutter/material.dart' hide Text;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'about.dart';
import 'epg.dart';
import 'extras.dart';
import 'journal.dart';
import 'perf_log.dart';
import 'names.dart';
import 'tmdb.dart';
import 'sport.dart';
import 'rights.dart';
import 'sport_detail.dart';
import 'trailer.dart';
import 'nouveautes.dart';
import 'version.dart';
import 'keys.dart' show kTmdbKey;
import 'subs.dart';
import 'perso.dart';
import 'ouvoir.dart';
import 'store.dart';
import 'account_ui.dart';
import 'sync.dart';
import 'auth.dart';
import 'pairing.dart';
import 'phone_entry.dart';
import 'chaines.dart';
import 'connect.dart';
import 'diag.dart';
import 'profils.dart';
import 'voice.dart';
import 'sources.dart';
import 'pin_guard.dart';
import 'osk.dart';
import 'trakt.dart';
import 'onb_prefs.dart';
import 'choice.dart';
import 'onboarding.dart';
import 'trakt_ui.dart';
import 'person.dart';
import 'ui.dart';
import 'xtream.dart';

/// ---------- 1. identifiants ----------
class LoginScreen extends StatefulWidget {
  final void Function(Creds) onDone;
  final bool adding;      // ajout d'une source depuis les réglages (Annuler possible, prénom inchangé)
  const LoginScreen({super.key, required this.onDone, this.adding = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final server = TextEditingController(), user = TextEditingController(), pass = TextEditingController(), prenom = TextEditingController();
  bool busy = false;
  bool m3u = false;      // source « playlist M3U » au lieu d'un abonnement Xtream (identifiant + mot de passe)
  String? error;
  late final PhoneEntry phone = PhoneEntry(const [('prenom', 'Nom du profil', false), ('server', 'Adresse du serveur (http://…)', false), ('user', 'Identifiant', false), ('pass', 'Mot de passe', true)], (f) {
    server.text = f['server'] ?? '';
    user.text = f['user'] ?? '';
    pass.text = f['pass'] ?? '';
    if ((f['prenom'] ?? '').isNotEmpty) prenom.text = f['prenom']!;
    if (mounted) go();
  });

  @override
  void initState() {
    super.initState();
    if (Connect.tvNow) {     // saisie depuis le téléphone (QR) : utile seulement sur une télé sans clavier
      phone.start(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    phone.stop();
    if (widget.adding) Store.cancelSource();     // abandon : aucune source créée
    super.dispose();
  }

  Future<void> go() async {
    if (busy) return;     // double appui, ou formulaire reçu du téléphone pendant un essai
    if (m3u ? server.text.trim().isEmpty : (server.text.trim().isEmpty || user.text.trim().isEmpty || pass.text.isEmpty)) {
      setState(() => error = m3u ? 'Renseigne l\'adresse de la playlist.' : 'Renseigne l\'adresse du serveur, l\'identifiant et le mot de passe.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final c = m3u ? Creds.m3u(server.text.trim()) : Creds(server.text, user.text.trim(), pass.text);
    try {
      await Xtream(c).authenticate();
      await Store.saveCreds(c);
      if (prenom.text.trim().isNotEmpty) await Store.renameProfile('', prenom.text);
      widget.onDone(c);
    } on XtreamError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Adresse du serveur invalide ou connexion impossible.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = <Widget>[
      if (!widget.adding) ...[
        AppField(controller: prenom, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: 'Nom du profil (pour « Bonjour … »)', border: const OutlineInputBorder(), isDense: Device.tv, contentPadding: Device.tv ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10) : null)),
        SizedBox(height: Device.tv ? 8 : 14),
      ],
      SegmentedButton<bool>(
        segments: const [ButtonSegment(value: false, label: Text('Identifiants')), ButtonSegment(value: true, label: Text('Playlist M3U'))],
        selected: {m3u},
        onSelectionChanged: (v) => setState(() => m3u = v.first),
      ),
      SizedBox(height: Device.tv ? 8 : 14),
      AppField(controller: server, keyboardType: TextInputType.url, autocorrect: false, onSubmitted: (_) => m3u ? go() : null, decoration: InputDecoration(labelText: m3u ? 'Adresse de la playlist (http://….m3u)' : 'Adresse du serveur (http://…)', border: const OutlineInputBorder(), isDense: Device.tv, contentPadding: Device.tv ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10) : null)),
      if (!m3u) ...[
        SizedBox(height: Device.tv ? 8 : 14),
        AppField(controller: user, autocorrect: false, decoration: InputDecoration(labelText: 'Identifiant', border: const OutlineInputBorder(), isDense: Device.tv, contentPadding: Device.tv ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10) : null)),
        SizedBox(height: Device.tv ? 8 : 14),
        AppField(controller: pass, obscureText: true, autocorrect: false, onSubmitted: (_) => go(), decoration: InputDecoration(labelText: 'Mot de passe', border: const OutlineInputBorder(), isDense: Device.tv, contentPadding: Device.tv ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10) : null)),
      ],
      if (error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(error!, style: const TextStyle(color: Color(0xFFFF6B7A)))),
      SizedBox(height: Device.tv ? 10 : 22),
      FilledButton(onPressed: busy ? null : go, child: Padding(padding: EdgeInsets.all(Device.tv ? 8 : 14), child: busy ? const SizedBox(height: 18, width: 18, child: Spinner(strokeWidth: 2)) : const Text('Se connecter'))),
    ];
    const intro = 'Connecte ton abonnement. Les identifiants restent chiffrés sur cet appareil.';
    if (!widget.adding) {
      // premier lancement : sur télé, formulaire à gauche et connexion par le téléphone (QR) à droite
      return AuthLayout(step: 1, text: intro, side: [if (phone.url != null) phone.card(qr: AuthLayout.wide(context) ? 170 : 110)], form: form);
    }
    return DsBg(child: Scaffold(backgroundColor: Colors.transparent, 
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(28), children: [
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_ios_new, size: 16), label: const Text('Annuler'))),
              Text('Nouvelle source', style: T(40, w: 850, ls: -0.04)),
              const SizedBox(height: 10),
              const Text(intro, style: TextStyle(color: Colors.white60)),
              if (phone.url != null) ...[const SizedBox(height: 16), phone.card()],
              const SizedBox(height: 24),
              ...form,
            ]),
          ),
        ),
      ),
    ));
  }
}

/// ---------- 2. choix des catégories (seules celles cochées sont téléchargées) ----------
class CategoriesScreen extends StatefulWidget {
  final Creds creds;
  final VoidCallback onDone;
  final VoidCallback? onCancel;     // changement depuis les réglages : Retour garde l'ancienne sélection
  final VoidCallback? onEditSource;     // première connexion : revenir corriger l'adresse ou les identifiants
  const CategoriesScreen({super.key, required this.creds, required this.onDone, this.onCancel, this.onEditSource});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final cats = <Kind, List<Cat>>{};
  final picked = <Kind, Set<String>>{for (final k in Kind.values) k: <String>{}};
  String? error;
  String filter = '';
  int ki = 0;
  bool saving = false;
  bool slow = false;      // le fournisseur met du temps : on le dit au lieu de tourner en silence
  Timer? _slowT;

  @override
  void initState() {
    super.initState();
    _slowT = Timer(const Duration(seconds: 10), () {
      if (mounted && cats.length < 3 && error == null) setState(() => slow = true);
    });
    load();
  }

  Future<void> load() async {
    if (error != null) setState(() => error = null);
    final x = Xtream(widget.creds);
    try {
      for (final k in Kind.values) {
        if (cats.containsKey(k)) continue;
        final l = await x.categories(k);
        cats[k] = l;
        // sélection actuelle si elle existe, sinon pré-cochage resserré (français, sans VOSTFR, vieilles années, décalé…)
        final cur = Store.selection(k);
        picked[k] = cur != null && cur.isNotEmpty ? {for (final c in l) if (cur.contains(c.id)) c.id} : {for (final c in l) if (suggested(k, c.name)) c.id};
        if (mounted) setState(() {});
      }
      // on commence par le type que l'utilisateur a mis en premier au parcours de configuration
      const tk = {'live': Kind.live, 'sport': Kind.live, 'films': Kind.vod, 'series': Kind.series};
      final first = OnbPrefs.tastes.map((x) => tk[x]).whereType<Kind>().firstOrNull;
      if (first != null) ki = Kind.values.indexOf(first);
      // goûts du parcours de configuration trop restrictifs pour ce fournisseur (rien de coché) : retour à la règle d'origine
      if (OnbPrefs.active && picked.values.fold<int>(0, (a, s) => a + s.length) == 0) {
        OnbPrefs.ignore = true;
        for (final k in Kind.values) {
          picked[k] = {for (final c in cats[k] ?? const <Cat>[]) if (suggested(k, c.name)) c.id};
        }
        OnbPrefs.ignore = false;
      }
      // première connexion : on ne fait pas choisir, les catégories suggérées sont prises (modifiables ensuite dans Réglages › Catégories)
      if (mounted && widget.onEditSource != null && OnbPrefs.tastes.isEmpty && picked.values.fold<int>(0, (a, s) => a + s.length) > 0) await save();
    } catch (e) {
      if (mounted) setState(() => error = e is XtreamError ? e.message : 'Connexion impossible : vérifie ta connexion Internet.');
    }
  }

  Future<void> save() async {
    if (saving) return;
    saving = true;
    for (final k in Kind.values) {
      await Store.saveSelection(k, picked[k]!.toList());
      await Store.saveCatNames(k, {for (final c in cats[k]!) if (picked[k]!.contains(c.id)) c.id: c.name});
    }
    widget.onDone();
  }

  Future<void> _filter() async {
    final c = TextEditingController(text: filter);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: kBg2,
        title: Text('Filtrer les catégories', style: T(18, w: 700)),
        content: AppField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v), decoration: InputDecoration(hintText: kStore ? 'Ex. : sport, documentaire…' : 'Ex. : sport, netflix…')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Effacer')), TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK'))],
      ),
    );
    if (v != null && mounted) setState(() => filter = v.toLowerCase().trim());
  }

  // ---- regroupement par pays / préfixe du fournisseur (« |FR| », « FR - ») : la liste devient courte et repliable
  final _fc = TextEditingController();
  final Set<String> _open = {};
  static const _pays = {
    'FR': 'France', 'BE': 'Belgique', 'CH': 'Suisse', 'CA': 'Canada', 'LU': 'Luxembourg', 'EN': 'Anglais', 'UK': 'Royaume-Uni', 'GB': 'Royaume-Uni', 'US': 'États-Unis',
    'DE': 'Allemagne', 'ES': 'Espagne', 'IT': 'Italie', 'PT': 'Portugal', 'NL': 'Pays-Bas', 'AR': 'Arabe', 'TR': 'Turquie', 'PL': 'Pologne', 'RO': 'Roumanie', 'PPV': 'Événements payants',
    'SPORT': 'Sport', 'SPORTS': 'Sport', 'KIDS': 'Jeunesse', 'XXX': 'Adulte', 'VOD': 'Films',
  };

  /// (préfixe, nom lisible) : « |FR| ✪ TNT HD » → (« FR », « TNT HD »)
  (String, String) _split(String name) {
    var n = name.trim(), tag = '';
    final m = RegExp(r'^\|\s*([A-Za-z0-9+ ]{1,8}?)\s*\|\s*(.*)$').firstMatch(n) ?? RegExp(r'^([A-Z]{2,4})\s*[-:·]\s+(.+)$').firstMatch(n);
    if (m != null) {
      tag = m.group(1)!.trim().toUpperCase();
      n = m.group(2)!.trim();
    }
    n = n.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '').trim();     // symboles décoratifs en tête (✪, ★…)
    return (tag, n.isEmpty ? name.trim() : n);
  }

  String _tagLabel(String tag) => tag.isEmpty ? 'Autres' : (_pays[tag] ?? tag);

  List<_Grp> _groups(List<Cat> shown) {
    final map = <String, _Grp>{};
    for (final c in shown) {
      final s = _split(c.name);
      (map[s.$1] ??= _Grp(s.$1)).items.add((c, s.$2));
    }
    final l = map.values.toList()
      ..sort((a, b) {
        int rank(_Grp g) => g.tag == 'FR' ? 0 : g.tag.isEmpty ? 3 : 1;
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : _tagLabel(a.tag).compareTo(_tagLabel(b.tag));
      });
    return l;
  }

  @override
  void dispose() {
    _fc.dispose();
    _slowT?.cancel();
    super.dispose();
  }

  void _toggle(Kind k, Iterable<String> ids, bool on) => setState(() => on ? picked[k]!.addAll(ids) : picked[k]!.removeAll(ids));

  @override
  Widget build(BuildContext context) {
    final total = picked.values.fold<int>(0, (a, s) => a + s.length);
    final ready = cats.length >= 3;
    final k = Kind.values[ki];
    final shown = ready ? cats[k]!.where((c) => filter.isEmpty || c.name.toLowerCase().contains(filter)).toList() : <Cat>[];
    final pad = MediaQuery.paddingOf(context);
    final tv = Device.tv;
    final searching = filter.isNotEmpty;
    return PopScope(
      canPop: widget.onCancel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onCancel?.call();
      },
      child: Scaffold(
        body: error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(error!, textAlign: TextAlign.center, style: T(16, color: kMut, h: 1.4)),
                    const SizedBox(height: 18),
                    PillButton(label: 'Réessayer', primary: true, onTap: load),
                    if (widget.onEditSource != null) ...[const SizedBox(height: 10), PillButton(label: 'Modifier la connexion', onTap: widget.onEditSource!)],
                    if (widget.onCancel != null) ...[const SizedBox(height: 10), PillButton(label: 'Annuler', onTap: widget.onCancel!)],
                  ]),
                ),
              )
            : !ready
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Spinner(),
                      const SizedBox(height: 16),
                      Text('Lecture des catégories… ${cats.length}/3', style: T(14, color: kMut)),
                      if (slow) ...[
                        const SizedBox(height: 10),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('Le fournisseur met du temps à répondre. Sans réponse dans quelques secondes, tu pourras réessayer ou vérifier la source.', textAlign: TextAlign.center, style: T(13, color: kMut, h: 1.4))),
                      ],
                      if (widget.onCancel == null) ...[const SizedBox(height: 18), const Steps(2)],
                    ]),
                  )
                : Stack(children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: FocusTraversalGroup(
                          policy: ReadingOrderTraversalPolicy(),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(20 + pad.left, pad.top + 10, 20 + pad.right, 0),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if (widget.onCancel == null) const Padding(padding: EdgeInsets.only(bottom: 10), child: Steps(2)),
                                Row(children: [
                                  if (widget.onCancel != null) ...[RoundButton(size: 44, label: 'Retour', onTap: widget.onCancel, child: const Ic('back', size: 20)), const SizedBox(width: 12)],
                                  Expanded(child: Text('Catégories', style: T(34, w: 800, ls: -0.04))),
                                  // télé : « Charger » tout en haut, sans avoir à descendre toute la liste à la télécommande
                                  PillButton(label: total == 0 ? 'Charger' : 'Charger ($total)', icon: 'play', primary: true, height: 48, onTap: total == 0 ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coche au moins une catégorie.'))) : save),
                                ]),
                                const SizedBox(height: 4),
                                Text(OnbPrefs.tastes.isNotEmpty ? 'On a coché ce qui correspond à tes choix. Touche une carte pour la cocher ou la décocher.' : 'Seules les catégories cochées sont téléchargées. Tu pourras les changer dans Réglages.', style: T(14, color: kMut, h: 1.35)),
                                const SizedBox(height: 14),
                                // type : Direct / Films / Séries (nombre de catégories cochées)
                                if (tv)
                                  Wrap(spacing: 10, runSpacing: 10, children: [
                                    for (var i = 0; i < Kind.values.length; i++)
                                      _CatChip(label: '${Kind.values[i].label} · ${picked[Kind.values[i]]!.length}', on: i == ki, onTap: () => setState(() => ki = i)),
                                  ])
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    child: CupertinoSlidingSegmentedControl<int>(
                                      groupValue: ki,
                                      backgroundColor: const Color(0x3D767680),
                                      thumbColor: const Color(0xFF5B6475),
                                      children: {
                                        for (var i = 0; i < Kind.values.length; i++)
                                          i: Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: Text('${Kind.values[i].label} ${picked[Kind.values[i]]!.length}')),
                                      },
                                      onValueChanged: (v) => setState(() => ki = v ?? ki),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                // recherche
                                if (tv)
                                  Wrap(spacing: 10, runSpacing: 10, children: [_CatChip(label: searching ? 'Filtre : $filter' : 'Filtrer', onTap: _filter)])
                                else
                                  Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(color: const Color(0x3D767680), borderRadius: BorderRadius.circular(13)),
                                    child: Row(children: [
                                      const Ic('search', size: 18, color: kMut),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: AppField(
                                          controller: _fc,
                                          style: T(16.5, w: 500),
                                          onChanged: (v) => setState(() => filter = v.toLowerCase().trim()),
                                          decoration: InputDecoration(hintText: 'Rechercher une catégorie', hintStyle: T(16.5, color: kMut), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isDense: true, filled: false, contentPadding: EdgeInsets.zero),
                                        ),
                                      ),
                                      if (searching) GestureDetector(onTap: () => setState(() { _fc.clear(); filter = ''; }), child: const Icon(Icons.cancel_rounded, size: 20, color: kMut)),
                                    ]),
                                  ),
                                const SizedBox(height: 10),
                                // actions rapides sur ce qui est affiché
                                SizedBox(
                                  height: 38,
                                  child: ListView(scrollDirection: Axis.horizontal, children: [
                                    _CatMini(label: 'Suggestion', icon: Icons.auto_awesome_rounded, onTap: () => setState(() => picked[k] = {for (final c in cats[k]!) if (suggested(k, c.name)) c.id})),
                                    _CatMini(label: searching ? 'Tout (${shown.length})' : 'Tout', icon: CupertinoIcons.checkmark_circle, onTap: () => _toggle(k, shown.map((c) => c.id), true)),
                                    _CatMini(label: searching ? 'Aucun (${shown.length})' : 'Aucun', icon: CupertinoIcons.circle, onTap: () => _toggle(k, shown.map((c) => c.id), false)),
                                  ]),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: shown.isEmpty
                                  ? Center(child: Text(searching ? 'Aucune catégorie ne correspond.' : 'Aucune catégorie chez le fournisseur.', style: T(15, color: kMut)))
                                  : _list(k, shown, pad, searching),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
      ),
    );
  }

  /// grille de cartes à cocher (comme le choix de langue) : les catégories pré-cochées d'abord, puis les autres
  Widget _list(Kind k, List<Cat> shown, EdgeInsets pad, bool searching) {
    final tint = k == Kind.live ? const [Color(0xFFFF9F43), Color(0xFFE5484D)] : k == Kind.vod ? const [Color(0xFFFF5E62), Color(0xFFB4235A)] : const [Color(0xFF8E6CFF), Color(0xFF4B2FD1)];
    final on = shown.where((c) => picked[k]!.contains(c.id)).toList();
    final off = shown.where((c) => !picked[k]!.contains(c.id)).toList();
    final tv = Device.tv;
    SliverGrid grid(List<Cat> l, {bool first = false}) => SliverGrid(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: tv ? 240 : 210, mainAxisExtent: 74, mainAxisSpacing: 10, crossAxisSpacing: 10),
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final c = l[i];
              final sp = _split(c.name);
              return _CatTile(
                key: ValueKey('${k.name}${c.id}'),
                label: sp.$2,
                tag: sp.$1.isEmpty ? '' : _tagLabel(sp.$1),
                on: picked[k]!.contains(c.id),
                a: tint[0],
                b: tint[1],
                autofocus: tv && first && i == 0,
                onTap: () => _toggle(k, [c.id], !picked[k]!.contains(c.id)),
              );
            },
            childCount: l.length,
          ),
        );
    Widget head(String t) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 8), child: Text(t, style: T(13, w: 700, color: kMut, ls: 0.06))));
    return CustomScrollView(
      cacheExtent: tv ? 600 : null,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16 + pad.left, 0, 16 + pad.right, 0),
          sliver: SliverMainAxisGroup(slivers: [
            if (on.isNotEmpty) ...[head(searching ? 'COCHÉES · ${on.length}' : 'POUR TOI · ${on.length}'), grid(on, first: true)],
            if (off.isNotEmpty) ...[head(on.isEmpty && !searching ? 'TOUTES LES CATÉGORIES · ${off.length}' : 'AUTRES · ${off.length}'), grid(off, first: on.isEmpty)],
          ]),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 30 + pad.bottom)),
      ],
    );
  }
}

/// carte de catégorie : dégradé quand elle est cochée, coche en haut à droite
class _CatTile extends StatelessWidget {
  final String label, tag;
  final bool on, autofocus;
  final Color a, b;
  final VoidCallback onTap;
  const _CatTile({super.key, required this.label, required this.tag, required this.on, required this.a, required this.b, required this.onTap, this.autofocus = false});

  @override
  Widget build(BuildContext context) => FocusCard(
        radius: 18,
        focusScale: Device.tv ? 1.05 : 1.0,
        autofocus: autofocus,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: kBg2,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: on ? [a, b] : [a.withOpacity(0.10), b.withOpacity(0.10)]),
            border: Border.all(color: on ? const Color(0x59FFFFFF) : kEdge, width: on ? 1.5 : 1),
          ),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (tag.isNotEmpty) Text(tag.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: T(10.5, w: 700, ls: 0.08, color: on ? const Color(0xCCFFFFFF) : kMut)),
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(14.5, w: 700, h: 1.15)),
              ]),
            ),
            const SizedBox(width: 6),
            AnimatedScale(
              scale: on ? 1 : 0.4,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: on ? 1 : 0,
                duration: const Duration(milliseconds: 140),
                child: Container(width: 22, height: 22, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF16203A))),
              ),
            ),
          ]),
        ),
      );
}

class _Grp {
  final String tag;
  final items = <(Cat, String)>[];
  _Grp(this.tag);
}

/// en-tête d'un groupe : pays, nombre de catégories cochées, flèche pour replier, case « tout »
class _CatHead extends StatelessWidget {
  final String title, count;
  final bool open, autofocus;
  final int state;     // 0 rien, 1 en partie, 2 tout
  final VoidCallback onOpen, onAll;
  const _CatHead({required this.title, required this.count, required this.open, required this.state, required this.autofocus, required this.onOpen, required this.onAll});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: FocusCard(
            autofocus: autofocus,
            onTap: onOpen,
            radius: 14,
            focusScale: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
              child: Row(children: [
                AnimatedRotation(turns: open ? 0.25 : 0, duration: const Duration(milliseconds: 180), child: const Icon(CupertinoIcons.chevron_right, size: 15, color: kMut)),
                const SizedBox(width: 12),
                Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(16.5, w: 700))),
                Text(count, style: T(13.5, color: kMut, w: 600)),
              ]),
            ),
          ),
        ),
        FocusCard(
          onTap: onAll,
          radius: 14,
          focusScale: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 16, 12),
            child: Icon(state == 2 ? Icons.check_circle : (state == 1 ? Icons.remove_circle_outline : Icons.circle_outlined), color: state == 0 ? kMut : kAccent, size: 26),
          ),
        ),
      ]);
}

/// petite action rapide sous la recherche
class _CatMini extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _CatMini({required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FocusCard(
          onTap: onTap,
          radius: 19,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(19)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: kAccent), const SizedBox(width: 7), Text(label, style: T(14, w: 650))]),
          ),
        ),
      );
}

class _CatChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _CatChip({required this.label, this.on = false, required this.onTap});
  @override
  Widget build(BuildContext context) => FocusCard(
        onTap: onTap,
        radius: 22,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: on ? Colors.white : const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(22)),
          child: Center(widthFactor: 1, child: Text(label, style: T(15, w: 700, color: on ? kBg : kText))),     // largeur du texte seulement (un Container centré remplirait toute la ligne)
        ),
      );
}

/// une catégorie : nom lisible et coche ; sur la télé, la ligne prend le focus et OK la coche
class _CatRow extends StatelessWidget {
  final String name;
  final bool on, autofocus;
  final VoidCallback onTap;
  const _CatRow({required this.name, required this.on, required this.autofocus, required this.onTap});
  @override
  Widget build(BuildContext context) => FocusCard(
        autofocus: autofocus,
        onTap: onTap,
        radius: 0,
        focusScale: 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 13, 16, 13),
          child: Row(children: [
            Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(16, w: 500))),
            const SizedBox(width: 10),
            Icon(on ? Icons.check_circle : Icons.circle_outlined, color: on ? kAccent : kMut, size: 26),
          ]),
        ),
      );
}

/// durée estimée lisible : « moins d'une minute », « environ 3 min »
String etaLabel(int sec) {
  if (sec < 50) return 'moins d\'une minute';
  final m = (sec / 60).round();
  return m <= 1 ? 'environ 1 min' : 'environ $m min';
}

/// ---------- 3. coque : en-tête, navigation, chargement du catalogue ----------
final _contNodes = <FocusNode>[];
FocusNode _contNode(int i) {
  while (_contNodes.length <= i) {
    _contNodes.add(FocusNode(debugLabel: 'continuer'));
  }
  return _contNodes[i];
}

class HomeScreen extends StatefulWidget {
  final Creds creds;
  final VoidCallback onReset, onChangeSelection;
  final VoidCallback? onWipe;
  final VoidCallback? onSwitch;      // source ajoutée, activée ou supprimée : on repart de zéro
  const HomeScreen({super.key, required this.creds, required this.onReset, required this.onChangeSelection, this.onWipe, this.onSwitch});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// nouvelle version Android publiée par le Pi (à la maison) ; null si aucune ou injoignable
Future<int?> newerBuild() async {
  if (kStore || kUpdateBase.isEmpty || kIsWeb || !Platform.isAndroid) return null;     // version store : mises à jour par le store seulement
  try {
    final r = await http.get(Uri.parse('$kUpdateBase/version.json')).timeout(const Duration(seconds: 6));
    final b = (jsonDecode(r.body) as Map)['build'];
    return b is int && b > kBuild ? b : null;
  } catch (_) {
    return null;
  }
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final Xtream x = Xtream(widget.creds);
  final libs = <Kind, Lib>{};
  List<Chan> chans = [];
  final busy = <Kind>{for (final k in Kind.values) if ((Store.selection(k) ?? []).isNotEmpty) k};     // jusqu'à la lecture du cache
  final _details = <String, Future<Detail?>>{};
  late Future<List<Ev>> sport = fetchSport(Store.sportKeys);
  DateTime _sportAt = DateTime.now();
  int tab = Store.initialTab(kid: Store.kid);
  int _lastSaved = -1;
  bool _quit = false;     // Retour : un second appui rapide quitte l'appli
  String liveTheme = '';

  // catalogue par catégorie (cache disque d'abord, puis réseau) et avancement « 12/40 »
  final _cats = <Kind, Map<String, List<Item>>>{};
  final progress = ValueNotifier<(int, int)>((0, 0));
  bool _running = false;
  int _tries = 0;
  DateTime _t0 = DateTime.now();     // début du chargement en cours (durée restante estimée)
  Timer? _retry, _deriveT;
  final _dirty = <Kind>{};

  Timer? _tick;
  final _pc = PageController();
  bool _slide = false;      // glissement lancé par le code (barre du bas) : ignore les changements de page intermédiaires

  /// pages qu'on fait défiler au doigt (téléphone, tablette) ; la télé garde un empilement simple
  Widget _swipePages(List<Widget> pages, List<int> vis) {
    final idx = vis.indexOf(tab).clamp(0, vis.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pc.hasClients || _slide || (_pc.page ?? idx).round() == idx) return;
      _slide = true;
      _pc.animateToPage(idx, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic).whenComplete(() => _slide = false);
    });
    return PageView(
      controller: _pc,
      onPageChanged: (i) {
        if (!_slide && vis[i] != tab) setState(() => tab = vis[i]);
      },
      // un seul défilement « principal » à la fois : sinon le toucher de la barre d'état (retour en haut sur iPhone) échoue, plusieurs listes étant attachées au même contrôleur
      children: [for (final v in vis) _KeepAlive(child: v == tab ? pages[v] : PrimaryScrollController.none(child: pages[v]))],
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Epg.src = x;
    unawaited(Connect.isTv().then((_) => Connect.start(_onRemote)));
    _loadAll();
    _checkUpdate();
    kCatalog = () => [...uniqueTitles(libs[Kind.vod]?.rows ?? []), ...uniqueTitles(libs[Kind.series]?.rows ?? [])];
    Epg.version.addListener(_epgChanged);
    Store.persoTick.addListener(_persoChanged);      // barre du bas et accueil personnalisés : on redessine
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _epgChanged());
    _sync();
    _syncT = Timer.periodic(const Duration(seconds: 45), (_) => _sync());
  }

  /// Android seulement : propose la nouvelle version quand le Pi en publie une (à la maison)
  Future<void> _checkUpdate() async {
    final b = await newerBuild();
    if (b == null || !mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: kBg2,
        title: Text('Nouvelle version disponible', style: T(18, w: 700)),
        content: Text('MinouFlix peut être mis à jour (version $b).', style: T(15, color: kMut)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mettre à jour'))],
      ),
    );
    if (go == true) await launchUrl(Uri.parse('$kUpdateBase/MinouFlix.apk'), mode: LaunchMode.externalApplication).catchError((_) => false);
  }

  /// retour dans l'appli (ou depuis le lecteur) : on récupère la reprise faite sur un autre appareil
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed && mounted) unawaited(_sync());
    if (s == AppLifecycleState.paused) unawaited(Sync.run());      // l'appli passe en arrière-plan : tout part avant qu'elle soit fermée
  }

  Timer? _syncT;

  Future<void> _sync() async {
    final before = Store.sportKeys.join();
    final p0 = Store.progress();
    final k0 = p0.isEmpty ? '' : '${p0.first.key}@${p0.first.t}';
    if (await Sync.run() && mounted) {
      if (Store.sportKeys.join() != before) sport = fetchSport(Store.sportKeys);     // sinon inutile de redemander les matchs
      setState(() {});
      // « Reprendre ici » : quelque chose a été regardé il y a peu sur un autre appareil
      final p1 = Store.progress();
      if (!Store.kid && p1.isNotEmpty && '${p1.first.key}@${p1.first.t}' != k0 && DateTime.now().millisecondsSinceEpoch - p1.first.t < 30 * 60 * 1000) {
        final p = p1.first;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text('Reprendre « ${p.name} » sur cet appareil ?'),
          action: SnackBarAction(label: 'Reprendre', onPressed: () => resume(p)),
        ));
      }
    }
  }

  String _sportSeen = Store.sportKeys.join(',');
  void _persoChanged() {
    if (!mounted) return;
    final k = Store.sportKeys.join(',');
    if (k != _sportSeen) {
      _sportSeen = k;
      sport = fetchSport(Store.sportKeys);      // championnats changés dans Réglages
    }
    setState(() {});
  }

  void _epgChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Store.persoTick.removeListener(_persoChanged);
    Connect.stop();
    _tick?.cancel();
    _pc.dispose();
    _syncT?.cancel();
    _retry?.cancel();
    _deriveT?.cancel();
    progress.dispose();
    Epg.version.removeListener(_epgChanged);
    super.dispose();
  }

  void _derive(Kind k) {
    final names = Store.catNames(k);
    final all = [for (final l in (_cats[k] ?? const <String, List<Item>>{}).values) ...l];
    if (k == Kind.live) {
      final hid = Store.hidden;
      chans = Store.kid ? [] : [for (final c in groupChannels(all, names)) if (!hid.contains(c.key)) c];
    } else {
      var l = all;
      if (Store.kid) {
        final ok = {for (final e in names.entries) if (RegExp(r'anim|enfant|jeunesse|kid|famil|disney|pixar|dessin|junior|cartoon|dreamworks|illumination', caseSensitive: false).hasMatch(norm(e.value))) e.key};
        l = l.where((i) => ok.contains(i.catId)).toList();
      }
      libs[k] = Lib(k, l, names);
    }
  }

  /// regroupe les mises à jour pendant le chargement : l'écran se redessine au plus toutes les 2,5 s
  void _soon(Kind k) {
    _dirty.add(k);
    _deriveT ??= Timer(Duration(milliseconds: libs.isEmpty && chans.isEmpty ? 200 : (Perf.lite ? 8000 : 2500)), () {
      _deriveT = null;
      if (!mounted) return;
      for (final d in [..._dirty]) {
        _derive(d);
      }
      _dirty.clear();
      setState(() {});
    });
  }

  /// ordre de chargement : ce qui se voit d'abord (nouveautés, plateformes, genres ; TNT et sport en direct)
  List<String> _byPriority(Kind k, List<String> ids) {
    final names = Store.catNames(k);
    int rank(String id) {
      final n = norm(catLabel(names[id] ?? ''));
      if (k == Kind.live) {
        final t = liveThemeOf(names[id] ?? '');
        final i = liveThemes.indexWhere((e) => e.$1 == t);
        return t == 'tnt' ? 0 : (t == 'sport' ? 1 : 2 + (i < 0 ? 20 : i));
      }
      if (RegExp(r'recent|nouveau|new|latest|dernier|derniere').hasMatch(n)) return 0;
      if (platOf(n) != null) return 1;
      final y = yearOfCat(n);
      if (y > 0) return 4 + (DateTime.now().year - y).clamp(0, 50);
      return vodCatKind(n) == 'genre' ? 2 : 3;
    }

    final r = {for (var i = 0; i < ids.length; i++) ids[i]: rank(ids[i]) * 10000 + i};     // tri stable
    return [...ids]..sort((a, b) => r[a]!.compareTo(r[b]!));
  }

  /// cache disque affiché tout de suite, puis catégories manquantes (par priorité, films/séries/direct en alternance),
  /// puis rafraîchissement en arrière-plan des catégories de plus de 12 h. Une catégorie en échec ne bloque pas les autres.
  Future<void> _loadAll({bool force = false}) async {
    if (_running) return;
    _running = true;
    _retry?.cancel();
    if (force) _tries = 0;
    final missing = <Kind, List<String>>{}, stale = <Kind, List<String>>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    final sw = Stopwatch()..start();
    final refreshMs = Store.catRefreshMs;
    for (final k in Kind.values) {
      final ids = Store.selection(k) ?? [];
      final have = await Store.cachedCats(k, ids);
      _cats[k] = {for (final id in ids) if (have.containsKey(id)) id: have[id]!.$2};
      if (have.isNotEmpty) _derive(k);
      missing[k] = _byPriority(k, [for (final id in ids) if (!have.containsKey(id)) id]);
      stale[k] = _byPriority(k, [for (final id in ids) if (have.containsKey(id) && (force || (refreshMs > 0 && now - have[id]!.$1 > refreshMs))) id]);
    }
    Journal.add('Catalogue : cache lu et classé en ${sw.elapsedMilliseconds} ms, mémoire ${PerfLog.rssMb} Mo, ${_cats.values.fold<int>(0, (a, m) => a + m.length)} catégories');
    List<(Kind, String)> mix(Map<Kind, List<String>> m) {
      final out = <(Kind, String)>[];
      for (var i = 0; m.values.any((l) => i < l.length); i++) {
        for (final k in const [Kind.vod, Kind.series, Kind.live]) {
          if (i < m[k]!.length) out.add((k, m[k]![i]));
        }
      }
      return out;
    }

    if (!mounted) return;
    final queue = [...mix(missing), ...mix(stale)];
    final left = <Kind, int>{for (final k in Kind.values) k: queue.where((q) => q.$1 == k).length};
    busy
      ..clear()
      ..addAll([for (final k in Kind.values) if (left[k]! > 0) k]);
    progress.value = (0, queue.length);
    _t0 = DateTime.now();
    if (mounted) setState(() {});
    final failed = <(Kind, String)>[];
    var authErr = false;
    if (queue.isNotEmpty) {
      try {
        await x.authenticate();
        // noms des catégories (filtres, thèmes) s'ils manquent
        for (final k in Kind.values) {
          if ((Store.selection(k) ?? []).isEmpty || Store.catNames(k).isNotEmpty) continue;
          final ids = Store.selection(k)!;
          final cs = await x.categories(k);
          await Store.saveCatNames(k, {for (final c in cs) if (ids.contains(c.id)) c.id: c.name});
        }
        Net.ok();
      } catch (e) {
        authErr = true;
        if ('$e'.startsWith('Serveur injoignable')) Net.fail();
        Journal.add('Catalogue : connexion au fournisseur', e);
        failed.addAll(queue);
        queue.clear();
        if (mounted && libs.isEmpty && chans.isEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    var next = 0, done = 0, fails = 0;
    final total = queue.length;
    // chargement groupé : une requête par type au lieu d'une par catégorie (repli automatique sur le mode normal)
    if (!authErr && queue.length >= 20) {
      for (final k in Kind.values) {
        final ks = {for (final q in queue) if (q.$1 == k) q.$2};
        if (ks.length < 15 || !mounted) continue;
        final got = await x.bulk(k, ks);
        if (got == null) continue;
        for (final e in got.entries) {
          _cats[k]?[e.key] = e.value.$1;
          unawaited(Store.cacheCat(k, e.key, e.value.$2));
        }
        final n0 = queue.length;
        queue.removeWhere((q) => q.$1 == k && got.containsKey(q.$2));
        done += n0 - queue.length;
        left[k] = left[k]! - (n0 - queue.length);
        progress.value = (done, total);
        if (left[k]! <= 0 && busy.contains(k)) busy.remove(k);
        Studios.forget(k);
        _derive(k);
        if (mounted) setState(() {});
      }
    }
    Future<void> worker() async {
      while (next < queue.length && mounted) {
        final (k, cid) = queue[next++];
        try {
          final (l, js) = await x.category(k, cid);
          _cats[k]?[cid] = l;
          unawaited(Store.cacheCat(k, cid, js));
          fails = 0;
          Net.ok();
        } catch (e) {
          failed.add((k, cid));
          // serveur saturé ou connexion perdue : on arrête là, on garde ce qu'on a et on réessaie plus tard
          if (++fails >= 4) {
            Journal.add('Catalogue : arrêt après 4 échecs', e);
            if ('$e'.startsWith('Serveur injoignable')) Net.fail();
            failed.addAll(queue.skip(next));
            next = queue.length;
          }
        }
        if (!mounted) return;
        progress.value = (++done, total);
        left[k] = left[k]! - 1;
        if (left[k]! <= 0 && busy.contains(k)) {
          busy.remove(k);
          Studios.forget(k);
          _derive(k);
          setState(() {});
        } else {
          _soon(k);
        }
      }
    }

    await Future.wait([worker(), worker()]);     // la passerelle limite déjà à 2 requêtes simultanées
    _running = false;
    if (!mounted) return;
    for (final k in Kind.values) {
      if (busy.remove(k)) _derive(k);
    }
    progress.value = (0, 0);
    setState(() {});
    if (total > 0) Journal.add('Catalogue', 'mise à jour : $total catégories en ${DateTime.now().difference(_t0).inSeconds} s, ${failed.length} en échec');
    if (failed.isEmpty) {
      _tries = 0;
      if (queue.isNotEmpty) await Store.setCatT();
    } else if (_tries++ < 3) {
      // seules les catégories en échec seront redemandées (les autres sont en cache)
      _retry = Timer(Duration(seconds: 90 * _tries), () {
        if (mounted) _loadAll();
      });
    }
    if (failed.isNotEmpty && !authErr && mounted) {
      final n = failed.toSet().length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n catégorie${n > 1 ? 's' : ''} non chargée${n > 1 ? 's' : ''} (serveur saturé ou hors ligne) : ${_tries <= 3 ? 'nouvel essai automatique dans quelques minutes.' : 'réessaie plus tard depuis les réglages.'}')));
    }
  }

  /// fiche (résumé, visuel) d'un élément : demandée une seule fois, conservée
  Future<Detail?> detailFor(Item it) => _details.putIfAbsent('${it.kind.name}${it.id}', () async {
        try {
          return it.kind == Kind.series ? (await x.seriesDetail(it.id)).$1 : await x.vodDetail(it.id);
        } catch (_) {
          return null;
        }
      });

  /// double appui : un seul écran ouvert
  DateTime _lastNav = DateTime(2000);
  bool _once() {
    final n = DateTime.now();
    if (n.difference(_lastNav) < const Duration(milliseconds: 700)) return false;
    _lastNav = n;
    return true;
  }

  Future<void> play(Item it) async {
    if (!_once()) return;
    await x.authenticate().catchError((_) => '');
    if (!mounted) return;
    final url = it.kind == Kind.live ? x.liveUrlOf(it) : x.vodUrl(it.id, it.ext);
    final prog = it.kind == Kind.vod ? Prog(kind: 'vod', id: it.id, ext: it.ext, name: it.title, icon: it.icon) : null;
    await Navigator.push(context, softRoute((_) => PlayerScreen(url: url, title: it.title, prog: prog)));
    unawaited(_sync());     // la reprise est tout de suite disponible sur tes autres appareils
    if (mounted) setState(() {});
  }

  /// « Continuer à regarder » : ouvre d'abord la fiche du film ou de la série (le bouton « Reprendre à … » y est) ; lecture directe si le titre n'est plus dans le catalogue
  void openProg(Prog p) {
    final kind = p.kind == 'ep' ? Kind.series : Kind.vod;
    final id = p.kind == 'ep' ? p.sid : p.id;
    final rows = libs[kind]?.rows ?? const <Item>[];
    final nm = norm(p.kind == 'ep' ? p.sname : p.name);
    final it = rows.where((r) => r.id == id).firstOrNull ?? (nm.isEmpty ? null : rows.where((r) => norm(r.title) == nm).firstOrNull);
    if (it == null) {
      resume(p);
    } else {
      info(it);
    }
  }

  /// reprise d'un film ou d'un épisode là où on l'avait laissé
  Future<void> resume(Prog p) async {
    if (!_once()) return;
    await x.authenticate().catchError((_) => '');
    if (!mounted) return;
    final url = p.kind == 'ep' ? x.episodeUrl(p.id, p.ext) : x.vodUrl(p.id, p.ext);
    await Navigator.push(context, softRoute((_) => PlayerScreen(url: url, title: p.name, prog: p)));
    unawaited(_sync());
    if (mounted) setState(() {});
  }

  Future<void> playChan(Chan c) async {
    if (!_once()) return;
    await x.authenticate().catchError((_) => '');
    if (!mounted) return;
    final alts = [for (final v in c.v) (v.label, x.liveUrlOf(v.item))];
    // zapping : les chaînes du même thème, dans l'ordre affiché
    var near = LiveTab.shown.contains(c) ? [...LiveTab.shown] : chans.where((o) => o.theme == c.theme).toList();
    if (!LiveTab.shown.contains(c) && c.theme == 'tnt') near = tntSort(near);
    LiveTab.shown = const [];
    final at = near.indexOf(c);
    final zap = [
      for (final o in near)
        () {
          final av = o.v.firstWhere((v) => v.item.arch > 0, orElse: () => o.best);
          return Zap(o.name, o.epgId, [for (final v in o.v) (v.label, x.liveUrlOf(v.item))], sid: av.item.id, arch: av.item.arch, key: o.key);
        }()
    ];
    await Navigator.push(context, softRoute((_) => PlayerScreen(url: alts.first.$2, title: c.name, alts: alts, zap: at < 0 ? const [] : zap, zapAt: at < 0 ? 0 : at, x: x)));
    if (mounted) setState(() {});
  }

  /// match : on cherche la chaîne qui le diffuse (guide du fournisseur, sinon chaînes habituelles de la compétition) ; si une seule chaîne est sûre, elle démarre
  Future<void> openEv(Ev e) async {
    if (e.post) {
      // terminé : statistiques, classement ou résultats plutôt que « où le voir »
      Navigator.push(context, softRoute((_) => EvDetailScreen(e: e)));
      return;
    }
    if (kStore) {
      // version store : le sport reste un calendrier (aucune chaîne lancée depuis un match)
      if (tab != 4) setState(() => tab = 4);
      return;
    }
    if (!mounted) return;
    // match en cours ou imminent : si le guide prouve la chaîne (les deux équipes dans le titre), on la lance directement
    if (e.ts <= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 900) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recherche de la chaîne du match…'), duration: Duration(seconds: 6)));
      List<WatchPick> found = const [];
      try {
        found = await whereToWatch(e, chans).timeout(const Duration(seconds: 6));
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (found.isNotEmpty && found.first.score >= 6) {
        playChan(found.first.c);
        return;
      }
    }
    // 2) sinon : la liste s'affiche tout de suite (chaînes habituelles), le guide la précise au fur et à mesure
    final live = ValueNotifier<List<WatchPick>>(quickPicks(e, chans));
    final busy = ValueNotifier<bool>(true);
    unawaited(whereToWatch(e, chans, progress: (l) => live.value = l).then((l) {
      if (l.isNotEmpty) live.value = l;
    }).whenComplete(() => busy.value = false));
    final c = await showWatchSheet(context, e, live, busy);
    if (c != null && mounted) playChan(c);
  }

  void info(Item it) {
    if (!_once()) return;
    warmBackdrop(context, it);
    Navigator.push(context, softRoute((_) => DetailScreen(x: x, item: it, detailFor: detailFor, lib: libs[it.kind], onOpen: info))).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// plateformes présentes dans le catalogue (films et séries réunis) : clé, nom, titres
  List<(String, String, List<Item>)> _platsAll() {
    final acc = <String, (String, List<Item>)>{};
    for (final k in [Kind.vod, Kind.series]) {
      final lb = libs[k];
      if (lb == null) continue;
      final gp = <String, Set<String>>{};
      for (final c in [...lb.ofKind('studio'), ...lb.ofKind('autre'), ...lb.ofKind('selection')]) {
        final pk = platOf(c.label);
        if (pk != null) gp.putIfAbsent(pk, () => {}).add(c.id);
      }
      for (final p in platforms) {
        final ids = gp[p.$1];
        if (ids == null) continue;
        final cur = acc[p.$1];
        acc[p.$1] = (p.$2, [...?cur?.$2, ...uniqueTitles(lb.inCats(ids))]);
      }
    }
    return [for (final e in acc.entries) (e.key, e.value.$1, e.value.$2)];
  }

  /// studios déjà appariés (on ne lance pas ici la construction, longue, des studios)
  Future<List<StudioHit>> _studiosAll() async => [
        for (final k in [Kind.vod, Kind.series])
          if (libs[k] != null && Studios.ready(k)) ...await Studios.of(libs[k]!),
      ];

  void openItem(Item it) => it.kind == Kind.live ? play(it) : info(it);
  bool _searchOpen = false;

  void search() {
    _searchOpen = true;
    kCatalog = () => [...uniqueTitles(libs[Kind.vod]?.rows ?? []), ...uniqueTitles(libs[Kind.series]?.rows ?? [])];
    Navigator.push(context, softRoute((_) => SearchScreen(items: kCatalog(), onOpen: openItem, plats: _platsAll, studios: _studiosAll))).then((_) => _searchOpen = false);
  }

  /// MinouFlix Connect : commande reçue d'un autre appareil du même compte
  void _onRemote(Map<String, dynamic> c) {
    if (!mounted) return;
    final a = '${c['a']}';
    if (a == 'ctl') {
      Connect.player.value = '${c['op']}:${DateTime.now().microsecondsSinceEpoch}';
      return;
    }
    if (a == 'search') {
      if (Connect.inPlayer) return;      // ne coupe jamais une lecture en cours
      Connect.query.value = '${c['q'] ?? ''}';
      if (!_searchOpen) {
        Navigator.of(context).popUntil((r) => r.isFirst);
        search();
      }
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (a == 'play') {
      resume(Prog(kind: '${c['k']}', id: (c['id'] as num).toInt(), sid: (c['sid'] as num?)?.toInt() ?? 0, ext: '${c['e']}', name: '${c['n']}', icon: '${c['i'] ?? ''}', sname: '${c['sn'] ?? ''}', pos: (c['p'] as num?)?.toInt() ?? 0));
    } else if (a == 'live') {
      final m = chans.where((o) => o.key == '${c['key']}');
      if (m.isNotEmpty) playChan(m.first);
    }
  }

  void _settings() => Navigator.push(
        context,
        softRoute((_) => SettingsScreen(
              progress: progress,
              onKid: () => setState(() {
                for (final k in Kind.values) {
                  Studios.forget(k);     // sinon les studios garderaient des titres hors mode enfant
                  if (_cats[k]?.isNotEmpty ?? false) _derive(k);
                }
              }),
              onRefresh: () => _loadAll(force: true),
              onLive: () => setState(() => _derive(Kind.live)),
              onSelection: widget.onChangeSelection,
              onSport: (k) async {
                await Store.saveSportKeys(k);
                if (mounted) setState(() => sport = fetchSport(k));
              },
              onLogout: () async {
                await Store.clear();
                widget.onReset();
              },
              onWipe: widget.onWipe,
              onSwitch: widget.onSwitch,
            )),
      ).then((_) {
        if (mounted) setState(() {});
        unawaited(Sync.run());      // les réglages modifiés partent tout de suite vers les autres appareils
      });

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final pad = MediaQuery.paddingOf(context);
    final kid = Store.kid;
    final empty = libs.values.every((l) => l.rows.isEmpty) && chans.isEmpty;
    if (empty && busy.isNotEmpty) {
      return Scaffold(
        body: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (_, p, __) {
            // durée restante mesurée (pas devinée) : après quelques catégories reçues
            final el = DateTime.now().difference(_t0).inSeconds;
            final left = p.$1 >= 3 && p.$2 > p.$1 ? el * (p.$2 - p.$1) ~/ p.$1 : -1;
            return LoadingScreen(status: p.$2 > 0 ? 'Chargement du catalogue… ${p.$1}/${p.$2} catégories${left >= 0 ? ' · encore ${etaLabel(left)}' : ''}' : 'Chargement du catalogue…');
          },
        ),
      );
    }
    final order = Store.tabsVisible(kid: kid);      // barre du bas : onglets choisis, dans l'ordre choisi
    if (!order.contains(tab)) tab = order.first;
    if (_lastSaved != tab) {
      _lastSaved = tab;
      Store.setLastTab(tab);      // « ouvrir sur le dernier onglet »
    }
    final nav = NavPill(index: tab, onSelect: (v) => setState(() {
          tab = v;
          // l'onglet Sport se met à jour dès qu'on y arrive (scores, matchs en direct), sans clic
          if (v == 4 && DateTime.now().difference(_sportAt).inMinutes >= 3) {
            _sportAt = DateTime.now();
            sport = fetchSport(Store.sportKeys);
          }
        }), onSearch: search, order: order, pages: Device.tv ? null : _pc);
    final pages = [
      HomeTab(libs: libs, chans: chans, sport: kid ? Future.value(<Ev>[]) : sport, busy: busy, detailFor: detailFor, onOpen: openItem, onPlay: (it) => it.kind == Kind.series ? info(it) : play(it), onInfo: info, onTab: (v) {
        if (Device.tv) NavPill.jump(v);
        setState(() => tab = v);
      }, onChan: playChan, onEv: openEv, onResume: openProg),
      LiveTab(chans: chans, busy: busy.contains(Kind.live), theme: liveTheme, onTheme: (t) => setState(() => liveTheme = t), onPlay: playChan, onHide: () => setState(() => _derive(Kind.live))),
      LibTab(kind: Kind.vod, lib: libs[Kind.vod], busy: busy.contains(Kind.vod), detailFor: detailFor, onOpen: info, onPlay: (it) => info(it)),
      LibTab(kind: Kind.series, lib: libs[Kind.series], busy: busy.contains(Kind.series), detailFor: detailFor, onOpen: info, onPlay: (it) => info(it)),
      SportTab(future: sport, onOpen: openEv, onKeys: (k) async {
        await Store.saveSportKeys(k);
        if (mounted) setState(() => sport = fetchSport(k));
      }),
    ];
    final title = tab == 0 ? (Store.name.isEmpty ? 'Accueil' : 'Bonjour ${Store.name}') : ['', 'Direct', 'Films', 'Séries', 'Sport'][tab];
    final heroTab = tab == 0 || tab == 2 || tab == 3;
    return PopScope(
      // Retour : d'abord à l'Accueil ; sur l'Accueil, un second appui dans les 2 s quitte l'appli
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (tab != order.first) {
          setState(() => tab = order.first);
          return;
        }
        if (_quit) {
          SystemNavigator.pop();
          return;
        }
        _quit = true;
        Timer(const Duration(seconds: 2), () => _quit = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Appuie encore sur Retour pour quitter')));
      },
      child: DsBg(child: Scaffold(backgroundColor: Colors.transparent, 
      body: Stack(children: [
        Positioned.fill(top: wide ? 78 + pad.top : 0, child: Device.tv ? KeyedSubtree(key: ValueKey(tab), child: pages[tab]) : _swipePages(pages, order)),
        // en-tête : titre à gauche, réglages à droite (navigation au centre sur grand écran)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(20 + pad.left, pad.top + 8, 20 + pad.right, 12),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kBg.withOpacity(wide || !heroTab ? 0.97 : 0.72), kBg.withOpacity(0.0)])),
            child: Row(children: [
              if (wide) ...[SvgPicture.asset('assets/logo.svg', height: 46), const Spacer(), nav, const Spacer()] else Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(28, w: 750, ls: -0.035))),
              _SettingsButton(onTap: _settings),
            ]),
          ),
        ),
        // hors ligne : bannière sous l'en-tête (le cache et les téléchargements restent utilisables)
        Positioned(
          top: pad.top + (wide ? 84 : 62),
          left: 16 + pad.left,
          right: 16 + pad.right,
          child: ValueListenableBuilder<bool>(
            valueListenable: Net.offline,
            builder: (_, off, __) => !off
                ? const SizedBox.shrink()
                : Center(
                    child: Glass(
                      radius: 18,
                      color: const Color(0xE62A1A1F),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.cloud_off_rounded, size: 18, color: Color(0xFFFF9AA5)),
                          const SizedBox(width: 8),
                          Flexible(child: Text('Hors ligne : catalogue en cache et téléchargements disponibles', maxLines: 2, overflow: TextOverflow.ellipsis, style: T(13, w: 600))),
                          const SizedBox(width: 8),
                          PillButton(label: 'Réessayer', height: 34, onTap: () {
                            Net.ok();
                            _loadAll();
                          }),
                        ]),
                      ),
                    ),
                  ),
          ),
        ),
        // avancement du catalogue pendant qu'on navigue déjà
        Positioned(
          left: 0,
          right: 0,
          bottom: wide ? 18 : pad.bottom + 70,
          child: IgnorePointer(
            child: ValueListenableBuilder<(int, int)>(
              valueListenable: progress,
              builder: (_, p, __) => AnimatedOpacity(
                opacity: p.$2 > 0 && p.$1 < p.$2 ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Center(child: _LoadPill(done: p.$1, total: p.$2)),
              ),
            ),
          ),
        ),
        if (!wide) Positioned(left: 12 + pad.left, right: 12 + pad.right, bottom: pad.bottom + 6, child: nav),
      ]),
    )));
  }
}

/// pastille « Catalogue · 12/40 » avec sa barre
class _LoadPill extends StatelessWidget {
  final int done, total;
  const _LoadPill({required this.done, required this.total});
  @override
  Widget build(BuildContext context) => Glass(
        radius: 18,
        child: Container(
          width: math.min(300.0, MediaQuery.sizeOf(context).width - 24),
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mise à jour · $done/$total catégories', maxLines: 1, overflow: TextOverflow.ellipsis, style: T(12.5, w: 650)),
            const SizedBox(height: 3),
            Text('Les fiches s\'ouvrent une fois le chargement fini.', maxLines: 2, overflow: TextOverflow.ellipsis, style: T(11, color: kMut)),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 3, backgroundColor: const Color(0x26FFFFFF), color: kAccent)),
          ]),
        ),
      );
}

class _SettingsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Réglages',
        button: true,
        child: FocusCard(
          onTap: onTap,
          radius: 19,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: const Color(0xFF0B0D12), shape: BoxShape.circle, border: Border.all(color: const Color(0x2EFFFFFF), width: 0.6)),
            child: const Center(child: Ic('gear', size: 21)),
          ),
        ),
      );
}

double _posterH(double w) => w * 1.5 + 54;

/// les 10 tendances de la semaine présentes dans la liste
List<Item> trendTop(List<Map> tr, Lib? vl, Lib? sl) {
  final out = <Item>[], seen = <String>{};
  for (final x in tr) {
    final lib = x['media_type'] == 'movie' ? vl : sl;
    if (lib == null) continue;
    final y = '${x['release_date'] ?? x['first_air_date'] ?? ''}';
    final yr = y.length >= 4 ? y.substring(0, 4) : '';
    final hit = lib.byTitle('${x['title'] ?? x['name'] ?? ''}', year: yr) ?? lib.byTitle('${x['original_title'] ?? x['original_name'] ?? ''}', year: yr);
    if (hit != null && hit.icon.isNotEmpty && seen.add('${hit.kind.name}${hit.id}')) out.add(hit);
    if (out.length >= 10) break;
  }
  return out;
}

/// durée « 1 h 27 » (minutes TMDB, sinon « 01:27:33 » du fournisseur)
String _dur(int min, String raw) {
  var m = min;
  if (m == 0) {
    final p = raw.split(':').map(int.tryParse).toList();
    if (p.length == 3 && p.every((e) => e != null)) m = p[0]! * 60 + p[1]!;
  }
  if (m <= 0) return '';
  return m >= 60 ? '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}' : '$m min';
}

String _n(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '\u202f');

List<Item> sortItems(List<Item> l, String mode) {
  final o = [...l];
  switch (mode) {
    case 'note':
      o.sort((a, b) => (b.rating < 9.5 ? b.rating : 0).compareTo(a.rating < 9.5 ? a.rating : 0));
    case 'az':
      o.sort((a, b) => norm(a.title).compareTo(norm(b.title)));
    default:
      o.sort((a, b) => b.added.compareTo(a.added));
  }
  return o;
}

/// ---------- accueil ----------
/// garde l'état (défilement) d'un onglet quand on glisse vers un autre
class _KeepAlive extends StatefulWidget {
  final Widget child;
  const _KeepAlive({required this.child});
  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class HomeTab extends StatelessWidget {
  final Map<Kind, Lib> libs;
  final List<Chan> chans;
  final Future<List<Ev>> sport;
  final Set<Kind> busy;
  final Future<Detail?> Function(Item) detailFor;
  final void Function(Item) onOpen, onPlay, onInfo;
  final void Function(int) onTab;
  final void Function(Chan) onChan;
  final void Function(Ev) onEv;
  final void Function(Prog) onResume;
  const HomeTab({super.key, required this.libs, required this.chans, required this.sport, required this.busy, required this.detailFor, required this.onOpen, required this.onPlay, required this.onInfo, required this.onTab, required this.onChan, required this.onEv, required this.onResume});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(valueListenable: Store.favTick, builder: (c, _, __) => _build(c));     // Ma liste, playlists et chaînes favorites se mettent à jour aussitôt

  Widget _build(BuildContext context) {
    final vl = libs[Kind.vod], sl = libs[Kind.series];
    if ((vl?.rows.isEmpty ?? true) && (sl?.rows.isEmpty ?? true) && chans.isEmpty) return busy.isNotEmpty ? const Center(child: SkeletonPage()) : const EmptyState(icon: Icons.inbox_rounded, title: 'Rien à afficher pour l\'instant', sub: 'Aucun titre reçu du fournisseur. Vérifie ta connexion, ou change les catégories à charger dans les réglages.');
    final rv = vl?.recent ?? <Item>[], rs = sl?.recent ?? <Item>[];
    // grande affiche : récents bien notés, films et séries en alternance
    final feat = <Item>[];
    final a = rv.where((i) => i.rating >= 6).take(4).toList(), b = rs.where((i) => i.rating >= 6).take(3).toList();
    for (var k = 0; k < 4; k++) {
      if (k < a.length) feat.add(a[k]);
      if (k < b.length) feat.add(b[k]);
    }
    if (feat.isEmpty) feat.addAll([...rv.take(4), ...rs.take(3)]);
    // top 10 : les mieux notés parmi les ajouts récents
    final pool = [...?vl?.rows.where((i) => i.icon.isNotEmpty).take(80), ...?sl?.rows.where((i) => i.icon.isNotEmpty).take(40)]..sort((x, y) => (y.rating < 9.5 ? y.rating : 0).compareTo(x.rating < 9.5 ? x.rating : 0));
    final top = uniqueTitles(pool.where((i) => i.rating > 0 && i.rating < 9.5)).take(10).toList();
    final wide = isWide(context);
    final pw = wide ? 150.0 : 128.0;
    final ph = _posterH(pw);
    final pad = MediaQuery.paddingOf(context);
    final favs0 = Store.favs;
    List<Item> reco(Lib? lib, String pre) {
      if (lib == null) return [];
      final seeds = lib.rows.where((i) => favs0.contains('$pre:${i.id}')).toList();
      final cats = {for (final s in seeds) s.catId};
      final ids = {for (final s in seeds) s.id};
      final l = lib.rows.where((i) => i.icon.isNotEmpty && i.rating > 5 && i.rating < 9.5 && !ids.contains(i.id) && (cats.isEmpty || cats.contains(i.catId))).toList()..sort((x, y) => y.rating.compareTo(x.rating));
      return uniqueTitles(l).skip(cats.isEmpty ? 10 : 0).take(20).toList();
    }
    final recoV = reco(vl, 'vod'), recoS = reco(sl, 'series');
    Widget rail(String t, List<Item> l, {int? tab}) => Rail(title: t, height: ph, count: l.length.clamp(0, 24), onMore: tab == null ? null : () => onTab(tab), builder: (_, i) => Poster(item: l[i], width: pw, onTap: () => onOpen(l[i])));
    final favCh = Store.favs;
    final mine = [for (final c in chans) if (c.v.any((v) => favCh.contains('live:${v.item.id}'))) c];     // seulement les chaînes marquées d'une étoile
    final sw = Device.tv ? 390.0 : (wide ? 270.0 : 256.0);
    final kid = Store.kid;
    final cont = kid ? <Prog>[] : Store.progress();     // mode enfant : pas de reprise ni de téléchargements des adultes
    final favs = Store.favs;
    final mylist = [...?vl?.rows.where((i) => favs.contains('vod:${i.id}')), ...?sl?.rows.where((i) => favs.contains('series:${i.id}'))];
    final secs = <String, Widget>{
      'hero': feat.isNotEmpty ? HeroBanner(items: feat.take(7).toList(), detailFor: detailFor, onPlay: onPlay, onInfo: onInfo) : SizedBox(height: pad.top + 70),
      'continue': Builder(builder: (ctx) => Rail(title: 'Continuer à regarder', height: 150, count: cont.length, moreLabel: '', builder: (_, i) => ContinueCard(focusNode: _contNode(i), p: cont[i], onTap: () => onResume(cont[i]), onRemove: () async {
            // appui long : confirmation avant de retirer (la position de lecture est conservée côté fiche tant qu'on ne relance pas)
            final ok = await showDialog<bool>(
              context: ctx,
              builder: (c) => AppDialog(
                title: Text('Retirer de « Continuer à regarder » ?', style: T(18, w: 700)),
                content: Text('${cont[i].sname.isEmpty ? cont[i].name : '${cont[i].sname} · ${cont[i].name}'}\nLe film ou l\'épisode disparaît de cette rangée.'),
                actions: [
                  TextButton(autofocus: true, onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Retirer')),
                ],
              ),
            );
            if (ok != true) return;
            await Store.hideProg(cont[i].key);
            unawaited(Sync.run());      // le retrait part tout de suite vers les autres appareils
            onTab(0);
            if (Device.tv && cont.length > 1) {      // la sélection va sur la carte d'après (la précédente si c'était la dernière), pas sur l'accueil
              final j = i < cont.length - 1 ? i : cont.length - 2;
              for (final ms in const [120, 350, 800]) {
                Timer(Duration(milliseconds: ms), () {
                  final n = _contNode(j);
                  if (n.context != null && n.canRequestFocus && FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<ContinueCard>() == null) n.requestFocus();
                });
              }
            }
          }))),
      'mylist': Rail(title: 'Ma liste', height: ph, count: mylist.length.clamp(0, 24), moreLabel: '', builder: (_, i) => Poster(item: mylist[i], width: pw, onTap: () => onOpen(mylist[i]))),
      'soon': CachedFuture<List<Soon>>(
        memKey: 'soon',
        future: Calendar.of(sl),
        builder: (_, s) => Rail(title: 'Prochains épisodes', height: 118, count: (s.data ?? const []).length, moreLabel: '', builder: (_, i) => SoonCard(s: s.data![i], onTap: () => onOpen(s.data![i].it))),
      ),
      'playlists': Builder(builder: (ctx) {
        final cs = Store.colls.entries.toList();     // même les playlists vides : on peut ainsi les supprimer
        final catalog = [...?vl?.rows, ...?sl?.rows];
        List<Item> of(List<String> ks) => [for (final r in catalog) if (ks.contains('${r.kind.name}:${r.id}')) r];
        return Rail(title: 'Mes playlists', height: 96, count: cs.length, moreLabel: '', builder: (_, i) {
          final its = of(cs[i].value);
          return SizedBox(
            width: 200,
            child: FocusCard(
              radius: 18,
              onTap: () => Navigator.push(ctx, softRoute((_) => PlaylistScreen(name: cs[i].key, all: catalog, onOpen: onOpen))),
              onLong: () async {
                final r = await appSheet<String>(
                  context: ctx,
                  builder: (_) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 6), child: Align(alignment: Alignment.centerLeft, child: Text(cs[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(17, w: 700)))),
                      ListTile(autofocus: true, leading: const Icon(CupertinoIcons.trash, color: Color(0xFFFF6B7A)), title: const Text('Supprimer la playlist', style: TextStyle(color: Color(0xFFFF6B7A))), subtitle: const Text('Les films et séries ne sont pas supprimés'), onTap: () => Navigator.pop(ctx, 'del')),
                      const SizedBox(height: 8),
                    ]),
                  ));
                if (r == 'del') await Store.deleteColl(cs[i].key);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: const Color(0xB8161B26), border: Border.all(color: const Color(0x1FFFFFFF), width: 0.8)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cs[i].key, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(16, w: 700, h: 1.2)),
                  const SizedBox(height: 4),
                  Text('${its.length} titre${its.length > 1 ? 's' : ''}', style: T(13, color: kMut)),
                ]),
              ),
            ),
          );
        });
      }),
      'downloads': Builder(builder: (ctx) {
        final dl = kid ? <Dl>[] : Downloads.all();
        return Rail(title: 'Téléchargés', height: 150, count: dl.length, moreLabel: '', builder: (_, i) => SizedBox(
              width: 300,
              child: FocusCard(
                radius: 20,
                onLong: () async {
                  await Downloads.remove(dl[i].key);
                  onTab(0);
                },
                onTap: () => Navigator.push(ctx, softRoute((_) => PlayerScreen(url: dl[i].path, title: dl[i].name))),
                child: GestureDetector(
                  onLongPress: () async {
                    await Downloads.remove(dl[i].key);
                    onTab(0);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0xB8161B26), border: Border.all(color: const Color(0x1FFFFFFF), width: 0.8)),
                    child: Row(children: [
                      SizedBox(width: 62, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: AspectRatio(aspectRatio: 2 / 3, child: netImage(dl[i].icon, dl[i].name)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(dl[i].name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(15, w: 700, h: 1.2)),
                        const SizedBox(height: 6),
                        Text('Hors ligne · appui long : supprimer', style: T(12, color: kMut)),
                      ])),
                    ]),
                  ),
                ),
              ),
            ));
      }),
      'top10': CachedFuture<List<Map>>(
        memKey: 'top10',
        future: Tmdb.trending(),
        builder: (_, s) {
          if (!s.hasData && s.connectionState != ConnectionState.done) return SizedBox(height: ph + 120);     // pas de liste provisoire qui change une seconde plus tard
          final tr = trendTop(s.data ?? const [], vl, sl);
          final l = tr.isNotEmpty ? tr : top;
          return Rail(title: 'Top 10 cette semaine', height: ph, count: l.length, moreLabel: '', builder: (_, i) => Top10Card(rank: i + 1, item: l[i], width: pw, onTap: () => onOpen(l[i])));
        },
      ),
      'affiche': CachedFuture<List<Map>>(
        memKey: 'affiche',
        future: Tmdb.nowPlaying(),
        builder: (_, s) {
          final seen = <int>{};
          final l = <Item>[];
          for (final f in s.data ?? const <Map>[]) {
            final d = '${f['release_date'] ?? ''}';
            final hit = vl?.byTitle('${f['title'] ?? ''}', year: d.length >= 4 ? d.substring(0, 4) : '') ?? vl?.byTitle('${f['original_title'] ?? ''}', year: d.length >= 4 ? d.substring(0, 4) : '');
            if (hit != null && hit.icon.isNotEmpty && seen.add(hit.id)) l.add(hit);
            if (l.length >= 18) break;
          }
          return Rail(title: 'À l\'affiche', height: ph, count: l.length, moreLabel: '', builder: (_, i) => Poster(item: l[i], width: pw, onTap: () => onOpen(l[i])));
        },
      ),
      'sport': CachedFuture<List<Ev>>(
        memKey: 'sport',
        future: sport,
        builder: (_, s) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          var evs = (s.data ?? []).where((e) => e.live || (e.ts > now - 7200 && e.ts < now + 3 * 86400 && !e.post));
          if (Store.str('home_sport') == 'mine') evs = evs.where(followed);      // Réglages › Sport : seulement mes équipes
          evs = evs.take(int.tryParse(Store.str('home_sport_n')) ?? 10).toList();
          return Rail(title: 'Sport', height: Device.tv ? 104 : 78, count: evs.length, onMore: Device.tv ? null : () => onTab(4), moreLabel: 'Calendrier', builder: (_, i) => SportCard(e: evs.toList()[i], width: sw, onTap: () => onEv(evs.toList()[i])));
        },
      ),
      'chains': Rail(title: 'Mes chaînes', height: 138, count: mine.length, onMore: () => onTab(1), builder: (_, i) => ChannelTile(item: mine[i], onTap: () => onChan(mine[i]))),
      'recoV': recoV.isNotEmpty ? rail('Vous aimerez peut-être', recoV) : const SizedBox.shrink(),
      'recoS': recoS.isNotEmpty ? rail('Séries pour vous', recoS) : const SizedBox.shrink(),
      'recent': rail('Derniers films ajoutés', rv, tab: 2),
      'recentS': rail('Séries mises à jour', rs, tab: 3),
      'trakt': !Trakt.linked
          ? const SizedBox.shrink()
          : CachedFuture<List<Item>>(
              memKey: 'trakt',
              future: Trakt.inCatalog([...uniqueTitles(vl?.rows ?? []), ...uniqueTitles(sl?.rows ?? [])]),
              builder: (_, s) => rail('Ma liste Trakt', s.data ?? const []),
            ),
    };
    // sections choisies dans Réglages › Écran d'accueil (ordre et affichage) ; la grande affiche reste en tête
    final hid = Store.homeHidden();
    return ListView(cacheExtent: Device.tv ? 1100 : 2600, padding: EdgeInsets.only(bottom: wide ? 40 : 110), children: [      // téléphone : les rangées voisines restent construites (pas de saut de page en remontant)
      // plus de grande affiche nulle part (télé, Android, iPhone) : le Top 10 passe tout en haut
      if (Device.tv || wide) const SizedBox(height: 8) else SizedBox(height: pad.top + 70),
      for (final id in ['top10', ...Store.homeOrder().where((x) => x != 'top10')])
        if (id != 'hero' && !hid.contains(id)) secs[id] ?? const SizedBox.shrink(),
    ]);
  }
}


/// ---------- direct ----------
class LiveTab extends StatefulWidget {
  /// chaînes affichées (thème + qualité choisis) au moment où l'on en lance une : le zapping suit exactement cette liste
  static List<Chan> shown = const [];
  final List<Chan> chans;
  final bool busy;
  final String theme;
  final void Function(String) onTheme;
  final void Function(Chan) onPlay;
  final VoidCallback? onGuide, onHide;
  const LiveTab({super.key, required this.chans, required this.busy, required this.theme, required this.onTheme, required this.onPlay, this.onGuide, this.onHide});
  @override
  State<LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<LiveTab> {
  String? ql;
  String lastTheme = '';

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 64;
    if (widget.busy && widget.chans.isEmpty) return const SkeletonPage(rows: true);
    final themes = [for (final t in liveThemes) if (widget.chans.any((c) => c.theme == t.$1)) t];
    if (themes.isEmpty) return const EmptyState(icon: Icons.live_tv_rounded, title: 'Aucune chaîne', sub: 'Coche des catégories « Direct » dans Réglages › Catégories à charger.');
    final theme = themes.any((t) => t.$1 == widget.theme) ? widget.theme : themes.first.$1;
    var chs = widget.chans.where((c) => c.theme == theme).toList();
    if (theme == 'tnt') chs = tntSort(chs);
    if (lastTheme != theme) {
      lastTheme = theme;
      ql = null;
    }
    // qualité à la place des catégories du fournisseur : 4K au départ si la plupart des chaînes en ont une
    final qs = ['4K', 'FHD', 'HD', 'SD'].where((q) => chs.any((c) => c.has(q))).toList();
    var q = ql ?? (Store.quality == '4k' && chs.where((c) => c.is4k).length * 2 >= chs.length ? '4K' : '');
    if (q.isNotEmpty && !qs.contains(q)) q = '';
    final l = q.isEmpty ? chs : chs.where((c) => c.has(q)).toList();
    if (Device.tv) {
      final side = ListView(padding: const EdgeInsets.fromLTRB(0, 8, 0, 40), children: [
        if (widget.onGuide != null) TvMenuItem(label: 'Guide TV', icon: Icons.calendar_view_day_rounded, on: false, onTap: widget.onGuide!),
        for (final t in themes) TvMenuItem(label: t.$2, icon: Icons.live_tv_rounded, on: t.$1 == theme, onTap: () => widget.onTheme(t.$1)),
        if (qs.length > 1) ...[
          Padding(padding: const EdgeInsets.fromLTRB(16, 14, 0, 8), child: Text('Qualité', style: T(14, w: 650, color: kMut))),
          TvMenuItem(label: 'Toutes', icon: Icons.high_quality_rounded, on: q.isEmpty, onTap: () => setState(() => ql = '')),
          for (final x in qs) TvMenuItem(label: x, icon: Icons.high_quality_rounded, on: q == x, onTap: () => setState(() => ql = x)),
        ],
      ]);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(children: [
          SizedBox(width: 290, child: side),
          const SizedBox(width: 16),
          Expanded(
            child: ListView.builder(
              key: ValueKey("$theme|$q|$ql"),
              padding: const EdgeInsets.only(top: 8, bottom: 60),
              itemExtent: 100,
              cacheExtent: 1600,
              itemCount: l.length,
              itemBuilder: (_, i) => ChannelRow(item: l[i], num: theme == 'tnt' ? i + 1 : 0, show4k: !l.every((c) => c.is4k), onTap: () {
                LiveTab.shown = l;
                widget.onPlay(l[i]);
              }, onLong: () => chanMenu(context, l[i], () => widget.onHide?.call())),
            ),
          ),
        ]),
      );
    }
    final wide = isWide(context);
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: SizedBox(height: wide ? 8 : top)),
      if (widget.onGuide != null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 4), child: Row(children: [PillButton(label: 'Guide TV', icon: 'tv', height: 42, onTap: widget.onGuide!)]))),
      SliverToBoxAdapter(child: Chips(labels: [for (final t in themes) t.$2], selected: themes.indexWhere((t) => t.$1 == theme), onSelect: (v) => widget.onTheme(themes[v].$1))),
      if (qs.length > 1) SliverToBoxAdapter(child: Chips(labels: ['Tout', ...qs], selected: q.isEmpty ? 0 : qs.indexOf(q) + 1, onSelect: (v) => setState(() => ql = v == 0 ? '' : qs[v - 1]))),
      SliverPadding(
        padding: EdgeInsets.only(top: 6, bottom: wide ? 40 : 110),
        sliver: wide
            ? SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 520, mainAxisExtent: 96),
                delegate: SliverChildBuilderDelegate((_, i) => ChannelRow(item: l[i], onTap: () {
                LiveTab.shown = l;
                widget.onPlay(l[i]);
              }, onLong: () => chanMenu(context, l[i], () => widget.onHide?.call())), childCount: l.length),
              )
            : SliverList(delegate: SliverChildBuilderDelegate((_, i) => ChannelRow(item: l[i], onTap: () {
                LiveTab.shown = l;
                widget.onPlay(l[i]);
              }, onLong: () => chanMenu(context, l[i], () => widget.onHide?.call())), childCount: l.length)),
      ),
    ]);
  }
}

final _platLogged = <Kind>{};

/// ---------- films / séries : accueil de la bibliothèque ----------
class LibTab extends StatelessWidget {
  final Kind kind;
  final Lib? lib;
  final bool busy;
  final Future<Detail?> Function(Item) detailFor;
  final void Function(Item) onOpen, onPlay;
  const LibTab({super.key, required this.kind, required this.lib, required this.busy, required this.detailFor, required this.onOpen, required this.onPlay});

  void _grid(BuildContext c, String title, List<Item> l) => Navigator.push(c, softRoute((_) => GridScreen(title: title, items: l, onOpen: onOpen)));

  @override
  Widget build(BuildContext context) {
    final lb = lib;
    if (lb == null || lb.rows.isEmpty) return busy ? const Center(child: SkeletonPage()) : EmptyState(icon: kind == Kind.vod ? Icons.movie_outlined : Icons.video_library_outlined, title: kind == Kind.vod ? 'Aucun film' : 'Aucune série', sub: 'Coche des catégories dans Réglages › Catégories à charger.');
    final wide = isWide(context);
    final pw = wide ? 150.0 : 128.0, ph = _posterH(pw);
    Widget rail(String t, List<Item> l, {VoidCallback? more}) => Rail(title: t, height: ph, count: l.length, onMore: more, moreLabel: '', builder: (_, i) => Poster(item: l[i], width: pw, onTap: () => onOpen(l[i])));
    // plateformes réelles (Marvel & co sont des studios : dans « Tout parcourir »)
    final gp = <String, Set<String>>{};
    for (final c in [...lb.ofKind('studio'), ...lb.ofKind('autre'), ...lb.ofKind('selection')]) {
      final k = platOf(c.label);
      if (k != null) gp.putIfAbsent(k, () => {}).add(c.id);
    }
    final plats = kStore ? <(String, String, String)>[] : [for (final p in platforms) if (gp.containsKey(p.$1)) p];
    if (_platLogged.add(kind)) {      // diagnostic (une fois par session) : pourquoi la rangée Plateformes manque sur un appareil
      final ks = <String, int>{};
      for (final c in lb.cats.values) {
        ks[c.kind] = (ks[c.kind] ?? 0) + 1;
      }
      Journal.add('Plateformes ${kind.name} : ${plats.length} reconnues, ${lb.cats.length} catégories $ks, ${lb.rows.length} titres, catégories candidates ${gp.length}');
    }     // version store : pas de rangée de plateformes
    final genres = lb.ofKind('genre')..sort((a, b) => norm(a.label).compareTo(norm(b.label)));
    // sélections regroupées par thème (4K, années, sagas…)
    final tg = <String, (String, List<CatInfo>)>{};
    for (final c in lb.ofKind('selection')) {
      final k = selThemeOf(c.label) ?? 'o${c.id}';
      if (k == 'an' || k == 'saga' || k == 'uhd') continue;     // ni « par année », ni sagas, ni 4K Ultra HD
      final nm = selThemes.where((t) => t.$1 == k).map((t) => t.$2).firstOrNull ?? pretty(c.label);
      tg.putIfAbsent(k, () => (nm, [])).$2.add(c);
    }
    final order = selThemes.map((t) => t.$1).toList();
    final themes = tg.entries.toList()..sort((a, b) => (order.contains(a.key) ? order.indexOf(a.key) : 99) - (order.contains(b.key) ? order.indexOf(b.key) : 99));
    final pad = MediaQuery.paddingOf(context);
    return ListView(cacheExtent: Device.tv ? 1100 : null, padding: EdgeInsets.only(bottom: wide ? 40 : 110), children: [
      SizedBox(height: Device.tv ? 8 : pad.top + 70),
      rail(kind == Kind.vod ? 'Derniers films ajoutés' : 'Dernières séries ajoutées', lb.recent),      // plus de grande affiche (télé, téléphone, tablette) : les derniers ajouts en premier
      if (plats.isNotEmpty)
        Rail(
          title: 'Plateformes',
          height: 132,
          count: plats.length > 10 ? 10 : plats.length,
          onMore: plats.isNotEmpty
              ? () => Navigator.push(context, softRoute((_) => AllTilesScreen(title: 'Plateformes', tiles: [for (final p in plats) PlatTile(keyName: p.$1, name: p.$2, onTap: () => _grid(context, p.$2, uniqueTitles(lb.inCats(gp[p.$1]!))))])))
              : null,
          builder: (_, i) => PlatTile(keyName: plats[i].$1, name: plats[i].$2, onTap: () => _grid(context, plats[i].$2, uniqueTitles(lb.inCats(gp[plats[i].$1]!)))),
        ),
      // studios : appariés une fois la bibliothèque complète (pas sur une liste encore partielle)
      if (!busy || Studios.ready(kind))
      FutureBuilder<List<StudioHit>>(
        future: Studios.of(lb),
        builder: (_, snap) {
          final st = [...(snap.data ?? const <StudioHit>[])]..sort((a, b) => b.items.length.compareTo(a.items.length));      // les plus fournis d'abord
          for (final k in ['DC', 'Marvel']) {      // Marvel et DC toujours dans la liste rapide (en tête)
            final j = st.indexWhere((x) => x.name.startsWith(k));
            if (j > 0) st.insert(0, st.removeAt(j));
          }
          if (st.isEmpty) return const SizedBox.shrink();
          return Rail(
            title: 'Studios',
            height: 140,
            count: st.length > 10 ? 10 : st.length,
            onMore: st.isNotEmpty
                ? () => Navigator.push(context, softRoute((_) => AllTilesScreen(title: 'Studios', tiles: [for (final s in st) StudioTile(name: s.name, icon: s.items.first.icon, logo: kStore ? '' : tmImg(s.logo, 'w185'), onTap: () => _grid(context, s.name, s.items))])))
                : null,
            builder: (_, i) => StudioTile(name: st[i].name, icon: st[i].items.first.icon, logo: kStore ? '' : tmImg(st[i].logo, 'w185'), onTap: () => _grid(context, st[i].name, st[i].items)),
          );
        },
      ),
      Rail(
        title: 'Genres',
        height: 88,
        count: genres.length,
        builder: (_, i) => GenreTile(name: genres[i].label, onTap: () => _grid(context, pretty(genres[i].label), uniqueTitles(lb.inCats([genres[i].id])))),
      ),
      if (!Device.tv) rail(kind == Kind.vod ? 'Derniers films ajoutés' : 'Dernières séries ajoutées', lb.recent),
      rail('Mieux notés', lb.top),
      for (final t in themes) rail(t.value.$1, uniqueTitles(lb.inCats(t.value.$2.map((c) => c.id)).take(60)).take(16).toList(), more: () => _grid(context, t.value.$1, uniqueTitles(lb.inCats(t.value.$2.map((c) => c.id))))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
        child: PillButton(label: 'Tout parcourir', onTap: () => Navigator.push(context, softRoute((_) => BrowseScreen(lib: lb, onOpen: onOpen)))),
      ),
    ]);
  }
}

/// liste en grille avec tri (plateforme, genre, thème)
/// « Tout voir » des plateformes et des studios : toutes les tuiles en grille
class AllTilesScreen extends StatelessWidget {
  final String title;
  final List<Widget> tiles;
  const AllTilesScreen({super.key, required this.title, required this.tiles});
  @override
  Widget build(BuildContext context) => DsBg(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(backgroundColor: Colors.transparent, title: Text(title, style: T(22, w: 750, ls: -0.03))),
          body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), child: Wrap(spacing: 14, runSpacing: 18, children: tiles)),
        ),
      );
}

class GridScreen extends StatefulWidget {
  final String title;
  final List<Item> items;
  final void Function(Item) onOpen;
  const GridScreen({super.key, required this.title, required this.items, required this.onOpen});
  @override
  State<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends State<GridScreen> {
  String sort = 'new';

  @override
  Widget build(BuildContext context) {
    final l = sortItems(widget.items, sort);
    final wide = isWide(context);
    final w = wide ? 170.0 : 118.0;
    return DsBg(child: Scaffold(backgroundColor: Colors.transparent, 
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(widget.title, style: T(22, w: 750, ls: -0.03))),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Chips(labels: const ['Récents', 'Mieux notés', 'A–Z'], selected: const ['new', 'note', 'az'].indexOf(sort), onSelect: (v) => setState(() => sort = const ['new', 'note', 'az'][v]))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 2, 20, 6), child: Text('${_n(l.length)} ${l.length > 1 ? 'titres' : 'titre'}', style: T(12.5, color: kMut)))),
        if (l.isEmpty) const SliverToBoxAdapter(child: EmptyState(icon: Icons.collections_bookmark_outlined, title: 'Rien ici pour l\'instant', sub: 'Depuis la fiche d\'un film ou d\'une série : « Collection » pour l\'ajouter.')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: w + 14, mainAxisExtent: _posterH(w) + 10, mainAxisSpacing: 12, crossAxisSpacing: 12),
            delegate: SliverChildBuilderDelegate((_, i) => Poster(item: l[i], width: w, onTap: () => widget.onOpen(l[i])), childCount: l.length),
          ),
        ),
      ]),
    ));
  }
}

/// « Tout parcourir » : Genres / Studios / Sélections puis catégories
class BrowseScreen extends StatefulWidget {
  final Lib lib;
  final void Function(Item) onOpen;
  const BrowseScreen({super.key, required this.lib, required this.onOpen});
  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  int seg = 0, cat = 0;
  String sort = 'new';
  static const kinds = ['genre', 'studio', 'selection', 'autre'];

  @override
  Widget build(BuildContext context) {
    final lb = widget.lib;
    final cats = lb.ofKind(kinds[seg])..sort((a, b) => kinds[seg] == 'genre' ? norm(a.label).compareTo(norm(b.label)) : 0);
    final c = cat.clamp(0, cats.length);
    final l = sortItems(uniqueTitles(c == 0 ? lb.inCats(cats.map((e) => e.id)) : lb.inCats([cats[c - 1].id])), sort);
    final wide = isWide(context);
    final w = wide ? 170.0 : 118.0;
    return DsBg(child: Scaffold(backgroundColor: Colors.transparent, 
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(lb.kind == Kind.vod ? 'Films' : 'Séries', style: T(22, w: 750, ls: -0.03))),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Chips(labels: const ['Genres', 'Studios', 'Sélections', 'Autres'], selected: seg, onSelect: (v) => setState(() {
              seg = v;
              cat = 0;
            }))),
        SliverToBoxAdapter(child: Chips(labels: ['Tout', ...cats.map((e) => pretty(e.label))], selected: c, onSelect: (v) => setState(() => cat = v))),
        SliverToBoxAdapter(child: Chips(labels: const ['Récents', 'Mieux notés', 'A–Z'], selected: const ['new', 'note', 'az'].indexOf(sort), onSelect: (v) => setState(() => sort = const ['new', 'note', 'az'][v]))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 2, 20, 6), child: Text('${_n(l.length)} ${l.length > 1 ? 'titres' : 'titre'}', style: T(12.5, color: kMut)))),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: w + 14, mainAxisExtent: _posterH(w) + 10, mainAxisSpacing: 12, crossAxisSpacing: 12),
            delegate: SliverChildBuilderDelegate((_, i) => Poster(item: l[i], width: w, onTap: () => widget.onOpen(l[i])), childCount: l.length),
          ),
        ),
      ]),
    ));
  }
}

/// ---------- recherche ----------
/// catalogue films + séries pour la recherche ouverte depuis une fiche (renseigné par l'accueil)
List<Item> Function() kCatalog = () => const [];

class SearchScreen extends StatefulWidget {
  final List<Item> items;
  final void Function(Item) onOpen;
  final String initial;
  final List<(String, String, List<Item>)> Function()? plats;      // plateformes du catalogue : clé, nom, titres
  final Future<List<StudioHit>> Function()? studios;               // studios déjà appariés
  const SearchScreen({super.key, required this.items, required this.onOpen, this.initial = '', this.plats, this.studios});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String q = '';
  final TextEditingController _tc = TextEditingController();
  final FocusNode _firstNode = FocusNode(debugLabel: 'premier résultat');
  Kind? _only;     // filtre : tout / films / séries
  String _pName = '';     // recherche par acteur ou réalisateur (TMDB) : titres du catalogue où la personne apparaît
  List<Item> _pItems = const [];
  Timer? _pT;
  bool _pBusy = false;      // recherche d'une personne (acteur, réalisateur) en cours
  List<(String, String, List<Item>)>? _plats;
  List<StudioHit> _studios = const [];

  /// rangée de tuiles (plateformes, studios) dans les résultats
  Widget _tiles(String title, List<Widget> tiles) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 10), child: Text(title, style: T(19, w: 700, ls: -0.02))),
        SizedBox(
          height: 140,
          child: ListView.separated(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: tiles.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, i) => tiles[i]),
        ),
      ]);

  void _askPerson(String text) {
    _pT?.cancel();
    final nt = norm(text);
    if (nt.length < 4 || kTmdbKey.isEmpty) {
      if (_pItems.isNotEmpty || _pBusy) setState(() {
            _pItems = const [];
            _pBusy = false;
          });
      return;
    }
    if (mounted) setState(() => _pBusy = true);
    _pT = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await Tmdb.raw('/search/person', {'query': text.trim(), 'language': L.tmdb});
        final res = r is Map ? r['results'] as List? : null;
        if (res == null || res.isEmpty) {
          if (mounted && _tc.text == text) setState(() => _pBusy = false);
          return;
        }
        final p = res.first as Map;
        final dep = '${p['known_for_department']}', nm = norm('${p['name']}');
        if (!['Acting', 'Directing', 'Writing'].contains(dep) || !(nm.contains(nt) || nt.contains(nm))) {
          if (mounted && _tc.text == text) setState(() => _pBusy = false);
          return;
        }
        final c = await Tmdb.raw('/person/${p['id']}/combined_credits', {'language': L.tmdb});
        final names = <String>{};
        for (final k in ['cast', 'crew']) {
          for (final e in (c is Map ? c[k] as List? ?? const [] : const [])) {
            for (final f in ['title', 'original_title', 'name', 'original_name']) {
              final v = '${(e as Map)[f] ?? ''}';
              if (v.isNotEmpty) names.add(norm(v));
            }
          }
        }
        final items = widget.items.where((i) => names.contains(i.nTitle)).take(60).toList();
        if (mounted && _tc.text == text) setState(() {
              _pName = '${p['name']}';
              _pItems = items;
            });
      } catch (_) {
      } finally {
        if (mounted && _tc.text == text) setState(() => _pBusy = false);
      }
    });
  }

  void _remote() {
    _tc.text = Connect.query.value;
    _tc.selection = TextSelection.collapsed(offset: _tc.text.length);
    setState(() => q = Connect.query.value);
  }

  @override
  void initState() {
    super.initState();
    Connect.query.addListener(_remote);
    widget.studios?.call().then((v) {
      if (mounted) setState(() => _studios = v);
    }).catchError((_) {});
    if (widget.initial.isNotEmpty) {
      q = widget.initial;
      _tc.text = widget.initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _askPerson(widget.initial));
    }
    if (Connect.query.value.isNotEmpty) {
      _tc.text = Connect.query.value;
      q = Connect.query.value;
    }
  }

  @override
  void dispose() {
    _pT?.cancel();
    Connect.query.removeListener(_remote);
    _tc.dispose();
    _firstNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nq = norm(q);
    final l = nq.length < 2 ? <Item>[] : widget.items.where((i) => (_only == null || i.kind == _only) && i.nTitle.contains(nq)).take(120).toList();
    final pm = nq.length < 2 ? const <(String, String, List<Item>)>[] : (_plats ??= widget.plats?.call() ?? const []).where((p) => norm(p.$2).contains(nq) && p.$3.isNotEmpty).toList();
    final sm = nq.length < 2 ? const <StudioHit>[] : _studios.where((s) => norm(s.name).contains(nq)).toList();
    final pl = [for (final i in _pItems) if (_only == null || i.kind == _only) i];
    final wide = isWide(context);
    final w = wide ? 170.0 : 118.0;
    final top = MediaQuery.paddingOf(context).top;
    return DsBg(child: Scaffold(backgroundColor: Colors.transparent, 
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + 8, 16, 10),
          child: Row(children: [
            RoundButton(size: 44, label: 'Retour', onTap: () => Navigator.pop(context), child: const Ic('back', size: 20)),
            const SizedBox(width: 14),
            Text('Recherche', style: T(28, w: 750, ls: -0.035)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Container(
            height: Device.tv ? null : 50,
            padding: Device.tv ? null : const EdgeInsets.symmetric(horizontal: 14),
            decoration: Device.tv ? null : BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: kEdge, width: 0.8)),
            child: Row(children: [
              if (!Device.tv) const Ic('search', size: 20, color: kMut),
              if (!Device.tv) const SizedBox(width: 10),
              Expanded(child: AppField(controller: _tc, autofocus: true, style: T(17, w: 500), onChanged: (v) {
                setState(() => q = v);
                _askPerson(v);
              }, onSubmitted: (_) {
                // télé : le clavier validé, le curseur va sur le premier résultat
                if (Device.tv) Future.delayed(const Duration(milliseconds: 500), () => mounted && _firstNode.context != null ? _firstNode.requestFocus() : null);
              }, decoration: InputDecoration(prefixIcon: Device.tv ? const Ic('search', size: 20, color: kMut) : null, hintText: 'Film, série, acteur, réalisateur…', hintStyle: T(17, w: 400, color: kMut), filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, isCollapsed: true))),
              VoiceButton(onResult: (v) {
                _tc.text = v;
                setState(() => q = v);
                _askPerson(v);
              }),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: Device.tv
                ? Row(children: [
                    for (final (i, n) in ['Tout', 'Films', 'Séries'].indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: FocusCard(
                          radius: 14,
                          preferred: (_only == null ? 0 : (_only == Kind.vod ? 1 : 2)) == i,
                          onTap: () => setState(() => _only = i == 1 ? Kind.vod : (i == 2 ? Kind.series : null)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
                            color: (_only == null ? 0 : (_only == Kind.vod ? 1 : 2)) == i ? const Color(0xFF5B6475) : const Color(0x3D767680),
                            child: Text(n, style: T(16, w: 650)),
                          ),
                        ),
                      ),
                  ])
                : CupertinoSlidingSegmentedControl<int>(
              groupValue: _only == null ? 0 : (_only == Kind.vod ? 1 : 2),
              backgroundColor: const Color(0x3D767680),
              thumbColor: const Color(0xFF5B6475),
              children: const {0: Padding(padding: EdgeInsets.symmetric(vertical: 7), child: Text('Tout')), 1: Padding(padding: EdgeInsets.symmetric(vertical: 7), child: Text('Films')), 2: Padding(padding: EdgeInsets.symmetric(vertical: 7), child: Text('Séries'))},
              onValueChanged: (v) => setState(() => _only = v == 1 ? Kind.vod : (v == 2 ? Kind.series : null)),
            ),
          ),
        ),
        Expanded(
          child: l.isEmpty && pl.isEmpty && pm.isEmpty && sm.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 90),
                  child: widget.items.isEmpty
                      ? const EmptyState(icon: Icons.hourglass_top_rounded, title: 'Catalogue en cours de chargement', sub: 'Les films et séries apparaissent ici dès qu\'ils sont reçus.')
                      : nq.length < 2
                          ? (Store.recentSearches().isNotEmpty
                              ? ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
                                  Row(children: [
                                    Expanded(child: Text('Dernières recherches', style: T(15, w: 650, color: kMut))),
                                    TextButton(onPressed: () async {
                                      await Store.clearRecentSearches();
                                      if (mounted) setState(() {});
                                    }, child: const Text('Effacer')),
                                  ]),
                                  Wrap(spacing: 8, runSpacing: 8, children: [
                                    for (final r in Store.recentSearches())
                                      ActionChip(
                                        label: Text(r),
                                        onPressed: () {
                                          _tc.text = r;
                                          _tc.selection = TextSelection.collapsed(offset: r.length);
                                          setState(() => q = r);
                                          _askPerson(r);
                                        },
                                      ),
                                  ]),
                                ])
                              : const EmptyState(icon: Icons.search_rounded, title: 'Que cherches-tu ?', sub: 'Un titre, un acteur ou un réalisateur.'))
                          : (_pBusy
                              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Spinner(), const SizedBox(height: 12), Text('Recherche en cours…', style: T(15, color: kMut))]))
                              : EmptyState(icon: Icons.search_off_rounded, title: 'Aucun résultat pour « $q »', sub: 'Vérifie l\'orthographe ou essaie un autre titre.')),
                )
              : CustomScrollView(slivers: [
                  if (_pBusy) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 10, 20, 0), child: Row(children: [const SizedBox(width: 16, height: 16, child: Spinner(strokeWidth: 2)), const SizedBox(width: 10), Text('Recherche d\'un acteur ou d\'un réalisateur…', style: T(13, color: kMut))]))),
                  if (pm.isNotEmpty) SliverToBoxAdapter(child: _tiles('Plateformes', [for (final p in pm) PlatTile(keyName: p.$1, name: p.$2, onTap: () => Navigator.push(context, softRoute((_) => GridScreen(title: p.$2, items: p.$3, onOpen: widget.onOpen))))])),
                  if (sm.isNotEmpty) SliverToBoxAdapter(child: _tiles('Studios', [for (final s in sm) StudioTile(name: s.name, icon: s.items.first.icon, logo: kStore ? '' : tmImg(s.logo, 'w185'), onTap: () => Navigator.push(context, softRoute((_) => GridScreen(title: s.name, items: s.items, onOpen: widget.onOpen))))])),
                  for (final sec in [if (pl.isNotEmpty) ('Avec $_pName', pl), ('Films', l.where((i) => i.kind == Kind.vod).toList()), ('Séries', l.where((i) => i.kind == Kind.series).toList())])
                    if (sec.$2.isNotEmpty) ...[
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 10), child: Row(children: [Text(sec.$1, style: T(19, w: 700, ls: -0.02)), const SizedBox(width: 8), Text('${sec.$2.length}', style: T(14, color: kMut))]))),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: w + 14, mainAxisExtent: _posterH(w) + 10, mainAxisSpacing: 12, crossAxisSpacing: 12),
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => Poster(
                              item: sec.$2[i],
                              width: w,
                              focusNode: i == 0 && sec.$1 == (pl.isNotEmpty ? 'Avec $_pName' : (l.any((x) => x.kind == Kind.vod) ? 'Films' : 'Séries')) ? _firstNode : null,
                              onTap: () {
                                Store.addRecentSearch(q);
                                widget.onOpen(sec.$2[i]);      // la fiche s'ouvre PAR-DESSUS la recherche : retour = résultats
                              },
                            ),
                            childCount: sec.$2.length,
                          ),
                        ),
                      ),
                    ],
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ]),
        ),
      ]),
    ));
  }
}

/// ---------- réglages ----------
class SettingsScreen extends StatefulWidget {
  final ValueListenable<(int, int)> progress;     // catalogue : (fait, total) pendant un chargement
  final VoidCallback onRefresh, onSelection, onLogout, onKid;
  final Future<void> Function(List<String>) onSport;
  final VoidCallback? onWipe, onSwitch, onLive;
  const SettingsScreen({super.key, required this.progress, required this.onKid, required this.onRefresh, required this.onSelection, required this.onLogout, required this.onSport, this.onWipe, this.onSwitch, this.onLive});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _catBytes = -1, _imgBytes = -1;
  int _sec = 0;      // rubrique affichée (grand écran)
  List<(String, String)> _srcs = const [];

  @override
  void initState() {
    super.initState();
    _sizes();
    _loadSrcs();
  }

  Future<void> _loadSrcs() async {
    final l = await Store.sources();
    if (mounted) setState(() => _srcs = l);
  }

  Future<void> _sizes() async {
    final c = await Store.catalogBytes(), i = await Store.imageBytes();
    if (mounted) {
      setState(() {
        _catBytes = c;
        _imgBytes = i;
      });
    }
  }

  void _snack(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Widget _group(String t) => _SubHead(t);
  /// interrupteur purement visuel : c'est toute la ligne qui bascule (un seul arrêt à la télécommande)
  Widget _sw(bool v) => ExcludeFocus(child: IgnorePointer(child: Switch(value: v, activeColor: Colors.white, activeTrackColor: const Color(0xFF30D158), onChanged: (_) {})));

  Future<bool> _confirm(String title, String body, String action, {bool danger = false}) async {
    final v = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: kBg2,
        title: Text(title, style: T(18, w: 700)),
        content: Text(body, style: T(15, color: kMut, h: 1.4)),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action, style: TextStyle(color: danger ? const Color(0xFFFF6B7A) : null))),
        ],
      ),
    );
    return v == true;
  }

  static const _forgot = '-oubli-';     // « Code oublié » choisi dans la fenêtre du code

  Future<String?> _pin(String titre, {bool forgot = false}) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: kBg2,
        title: Text(titre, style: T(18, w: 700)),
        content: AppField(controller: c, autofocus: true, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onSubmitted: (v) => Navigator.pop(ctx, v), decoration: const InputDecoration(hintText: '4 chiffres')),
        actions: [
          if (forgot) TextButton(onPressed: () => Navigator.pop(ctx, _forgot), child: const Text('Code oublié')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK')),
        ],
      ),
    );
  }

  /// mode enfant actif : le code est demandé avant les actions qui le contourneraient (3 essais, puis 5 min d'attente)
  Future<bool> _unlocked() async {
    if (!Store.kid) return true;
    final t0 = DateTime.now().millisecondsSinceEpoch;
    if (Store.pinGuard.locked(t0)) {
      _snack('Trop d\'essais : réessaie dans ${Store.pinGuard.waitMin(t0)} min.');
      return false;
    }
    final p = await _pin('Code du mode enfant', forgot: true);
    if (p == null) return false;
    if (p == _forgot) return _resetPin();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!Store.pinOk(p)) {
      final g = Store.pinGuard.failed(now);
      await Store.setPinGuard(g);
      if (mounted) _snack(g.locked(now) ? 'Code incorrect. Trop d\'essais : réessaie dans ${g.waitMin(now)} min.' : 'Code incorrect (encore ${g.left()} essai${g.left() > 1 ? 's' : ''}).');
      return false;
    }
    await Store.setPinGuard(const PinGuard(0, 0));
    return true;
  }

  /// code oublié : le mot de passe du compte MinouFlix lève le mode enfant (sans compte : impossible ici, par sécurité)
  Future<bool> _resetPin() async {
    if (!Account.signedIn) {
      _snack('Sans compte MinouFlix connecté, le code ne peut pas être réinitialisé ici : efface les données de l\'appli depuis les réglages de l\'appareil.');
      return false;
    }
    final c = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: kBg2,
        title: Text('Code oublié', style: T(18, w: 700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Saisis le mot de passe du compte ${Account.email} : le mode enfant sera désactivé (tu pourras le réactiver avec un nouveau code).', style: T(14, color: kMut, h: 1.4)),
          const SizedBox(height: 10),
          AppField(controller: c, autofocus: true, obscureText: true, autocorrect: false, onSubmitted: (v) => Navigator.pop(ctx, v), decoration: const InputDecoration(hintText: 'Mot de passe du compte')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Valider'))],
      ),
    );
    if (pw == null || pw.isEmpty) return false;
    final e = await Account.signIn(Account.email, pw);
    if (!mounted) return false;
    if (e != null) {
      _snack(e);
      return false;
    }
    await Store.setPinGuard(const PinGuard(0, 0));
    await Store.setKid(false);
    widget.onKid();
    if (mounted) setState(() {});
    _snack('Mode enfant désactivé.');
    return true;
  }

  Future<void> _pairTv() async {
    if (!Account.signedIn) {
      _snack('Connecte-toi d\'abord à un compte MinouFlix (Compte et synchronisation).');
      return;
    }
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: kBg2,
        title: Text('Code affiché sur la télé', style: T(18, w: 700)),
        content: AppField(controller: c, autofocus: true, textCapitalization: TextCapitalization.characters, autocorrect: false, onSubmitted: (v) => Navigator.pop(ctx, v), decoration: const InputDecoration(hintText: 'ABCD-EFGH')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Connecter'))],
      ),
    );
    if (v == null || v.trim().isEmpty) return;
    final e = await Pairing.send(v);
    if (mounted) _snack(e ?? 'Envoyé : la télé se connecte.');
  }

  Future<void> _kid() async {
    if (Store.kid) {
      if (!await _unlocked()) return;
      await Store.setKid(false);
    } else {
      final p = await _pin('Choisis un code à 4 chiffres');
      if (p == null) return;
      if (!RegExp(r'^\d{4}$').hasMatch(p)) {
        if (mounted) _snack('Le code doit faire 4 chiffres.');
        return;
      }
      await Store.setKid(true, p);
      await Store.setPinGuard(const PinGuard(0, 0));
    }
    widget.onKid();
    if (mounted) setState(() {});
  }

  Future<void> _account() async {
    await Navigator.push(context, softRoute((ctx) => SyncChoiceScreen(first: false, onDone: () => Navigator.pop(ctx))));
    if (mounted) setState(() {});
  }

  Future<void> _sport() async {
    final k = await editSports(context);
    if (k == null) return;
    await widget.onSport(k);
    if (mounted) setState(() {});
  }

  Future<void> _update() async {
    final b = await newerBuild();
    if (!mounted) return;
    if (b == null) {
      _snack('Tu as la dernière version (ou le serveur de mise à jour n\'est joignable qu\'à la maison).');
      return;
    }
    if (await _confirm('Nouvelle version disponible', 'MinouFlix peut être mis à jour (version $b).', 'Mettre à jour')) {
      await launchUrl(Uri.parse('$kUpdateBase/MinouFlix.apk'), mode: LaunchMode.externalApplication).catchError((_) => false);
    }
  }

  Future<void> _deleteDl(Dl d) async {
    if (!await _confirm('Supprimer le téléchargement ?', '« ${d.name} » ne sera plus disponible hors ligne.', 'Supprimer', danger: true)) return;
    await Downloads.remove(d.key);
    if (mounted) setState(() {});
  }

  Future<void> _clearImages() async {
    await Store.clearImages();
    PaintingBinding.instance.imageCache.clear();
    await _sizes();
    if (mounted) _snack('Images effacées : elles seront retéléchargées au besoin.');
  }

  /// liste des chaînes masquées : « Réafficher » une par une, ou toutes
  void _hiddenPage() => _page('Chaînes masquées', () {
        final h = Store.hidden.toList()..sort();
        String nice(String k) => k.isEmpty ? k : k[0].toUpperCase() + k.substring(1);
        if (h.isEmpty) return [_foot('Aucune chaîne masquée. Appui long sur une chaîne pour la masquer.')];
        return [
          _box([
            for (final k in h)
              _row(CupertinoIcons.eye_slash_fill, const Color(0xFF8E8E93), nice(k), value: 'Réafficher', onTap: () async {
                await Store.setHidden(Store.hidden..remove(k));
                widget.onLive?.call();
                if (mounted) setState(() {});
              }),
          ]),
          const SizedBox(height: 18),
          _box([
            _row(CupertinoIcons.eye_fill, const Color(0xFF0A84FF), 'Tout réafficher', onTap: () async {
              await Store.setHidden({});
              widget.onLive?.call();
              if (mounted) setState(() {});
            }),
          ]),
        ];
      });

  Future<void> _repair() async {
    if (!await _confirm('Réparer l\'application ?', 'Efface les images et le catalogue en cache puis recharge tout depuis ton fournisseur. Tes réglages, ta liste, ta reprise et ton compte sont conservés.', 'Réparer')) return;
    await Store.clearImages();
    PaintingBinding.instance.imageCache.clear();
    await Store.clearCatalog();
    Tmdb.reset();
    widget.onRefresh();
    await _sizes();
    if (mounted) _snack('Réparation lancée : le catalogue se recharge.');
  }

  Future<void> _clearCatalog() async {
    if (!await _confirm('Vider le catalogue ?', 'Les listes de chaînes, films et séries seront retéléchargées depuis le serveur. Tes réglages, ta liste et ta reprise sont conservés.', 'Vider')) return;
    await Store.clearCatalog();
    widget.onRefresh();
    await _sizes();
    if (mounted) _snack('Catalogue vidé : rechargement en cours.');
  }

  /// déconnexion du compte seulement : l'appli et l'abonnement IPTV restent, la synchronisation s'arrête
  Future<void> _accountOut() async {
    if (!await _confirm('Se déconnecter du compte ?', 'Tu gardes MinouFlix et ton abonnement IPTV sur cet appareil. Ton compte reste sur le serveur : reconnecte-toi quand tu veux pour tout retrouver. D\'ici là, plus de synchronisation avec tes autres appareils.', 'Se déconnecter')) return;
    await Account.signOut();
    await Store.setFlag('noacct', true);      // l'appli reste utilisable sans compte, sans redemander la connexion au lancement
    if (mounted) {
      _tick.value++;
      _snack('Déconnecté du compte.');
    }
  }

  /// ce que fait une action, ce qui est conservé, comment revenir : trois lignes sous chaque bouton
  Widget _why(String fait, String garde, String retour) {
    Widget line(String label, String txt, Color c) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 124, child: Text(label, style: T(12.5, w: 700, color: c, h: 1.4))),
            Expanded(child: Text(txt, style: T(12.5, color: kMut, h: 1.4))),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 10, 24, 0),
      child: Column(children: [
        line('Ce qui se passe', fait, const Color(0xFFFFB86B)),
        line('Conservé', garde, const Color(0xFF30D158)),
        line('Pour revenir', retour, const Color(0xFF8AB4FF)),
      ]),
    );
  }

  /// toutes les déconnexions et suppressions au même endroit, de la moins à la plus définitive
  void _disconnectPage() => _page('Déconnexion et suppression', () => [
        if (Account.signedIn) ...[
          _foot('Connecté : ${Account.email}'),
          const SizedBox(height: 14),
          _box([_row(CupertinoIcons.person_crop_circle_badge_xmark, const Color(0xFFFF9F0A), '1 · Se déconnecter du compte', onTap: _accountOut)]),
          _why('Ton e-mail est retiré de cet appareil et la synchronisation s\'arrête.', 'L\'appli, ton abonnement IPTV, ta liste et ta reprise sur cet appareil ; ton compte sur le serveur.', 'Te reconnecter avec ton e-mail et ton mot de passe.'),
          const SizedBox(height: 24),
        ],
        _box([_row(CupertinoIcons.arrow_right_square_fill, const Color(0xFFFF9F0A), '${Account.signedIn ? '2' : '1'} · Retirer l\'abonnement IPTV', onTap: _logout)]),
        _why('L\'adresse, l\'identifiant et le mot de passe IPTV sont effacés de cet appareil ; le catalogue disparaît.', 'Ton compte MinouFlix (reste connecté), ta liste, ta reprise et tes réglages.', 'Ressaisir ton abonnement, ou le retrouver via ton compte s\'il était synchronisé.'),
        const SizedBox(height: 24),
        _box([_row(CupertinoIcons.trash_fill, const Color(0xFFFF453A), '${Account.signedIn ? '3' : '2'} · Effacer les données de cet appareil', danger: true, onTap: _wipe)]),
        _why('Tout est supprimé sur cet appareil : abonnement, réglages, liste, reprise, catalogue, téléchargements. Tu es aussi déconnecté du compte.', 'Ton compte et sa copie sur le serveur.', 'Te reconnecter : tout revient si la synchronisation était active.'),
        if (Account.signedIn) ...[
          const SizedBox(height: 24),
          _box([_row(CupertinoIcons.person_crop_circle_badge_minus, const Color(0xFFFF453A), '4 · Supprimer mon compte', danger: true, onTap: _deleteAccount)]),
          _why('Ton compte et toutes les données synchronisées sont effacés du serveur et de cet appareil. Irréversible.', 'Rien.', 'Créer un nouveau compte : rien ne peut être récupéré.'),
        ],
      ]);

  Future<void> _logout() async {
    if (!await _confirm('Se déconnecter de l\'abonnement ?', 'Les identifiants IPTV de cet appareil seront effacés. Ton compte MinouFlix, ta liste et ta reprise sont conservés.', 'Se déconnecter')) return;
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);     // ferme aussi la page de catégorie ouverte
    widget.onLogout();
  }

  Future<void> _wipe() async {
    if (!await _unlocked()) return;
    if (!await _confirm(
      'Effacer les données de cet appareil ?',
      'Tout ce que MinouFlix garde sur cet appareil sera supprimé : identifiants, réglages, ma liste, reprise, catalogue et téléchargements.${Account.signedIn ? ' Ton compte et sa copie sur le serveur ne sont pas touchés : reconnecte-toi pour tout retrouver.' : ''}',
      'Tout effacer',
      danger: true,
    )) return;
    await Account.signOut();
    await Store.wipe();
    await Journal.clear();
    PaintingBinding.instance.imageCache.clear();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onWipe?.call();
  }

  /// suppression définitive du compte (exigée par les stores) : serveur d'abord, puis cet appareil
  Future<void> _deleteAccount() async {
    if (!await _unlocked()) return;
    if (!await _confirm(
      'Supprimer ton compte ?',
      'Ton compte ${Account.email}, ta liste, ta reprise et tes identifiants synchronisés seront définitivement effacés du serveur, puis cet appareil reviendra au premier lancement. C\'est irréversible.',
      'Supprimer définitivement',
      danger: true,
    )) return;
    final e = await Account.deleteAccount();
    if (!mounted) return;
    if (e != null) {
      Journal.add('Suppression de compte', e);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          backgroundColor: kBg2,
          title: Text('Compte non supprimé', style: T(18, w: 700)),
          content: Text(e, style: T(15, color: kMut, h: 1.4)),
          actions: [TextButton(autofocus: true, onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }
    await Account.signOut();
    await Store.wipe();
    await Journal.clear();
    PaintingBinding.instance.imageCache.clear();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    widget.onWipe?.call();
  }

  Future<void> _journal() async {
    var t = await Journal.read();
    if (!mounted) return;
    if (t.length > 60000) t = '…\n${t.substring(t.length - 60000)}';     // la fin suffit
    await Navigator.push(context, softRoute((_) => TextPage(title: 'Journal d\'erreurs', mono: t.isEmpty ? 'Aucune erreur notée.' : t, action: Device.tv ? null : 'Copier', onAction: Device.tv ? null : _copyJournal)));
  }

  Future<void> _copyJournal() async {
    final t = await Journal.read();
    await Clipboard.setData(ClipboardData(text: t.isEmpty ? 'Aucune erreur notée.' : t));
    if (mounted) _snack('Journal copié : colle-le dans ton message.');
  }

  /// « il y a 3 h »
  String _ago(int ms) {
    if (ms == 0) return 'jamais';
    final m = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms)).inMinutes;
    if (m < 1) return 'à l\'instant';
    if (m < 60) return 'il y a $m min';
    if (m < 48 * 60) return 'il y a ${m ~/ 60} h';
    return 'il y a ${m ~/ 1440} jours';
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final kid = Store.kid;
    final name = Store.name;
    final counts = [for (final k in Kind.values) if ((Store.selection(k) ?? []).isNotEmpty) '${k.label} ${Store.selection(k)!.length}'].join(' · ');
    final dls = Downloads.all();
    final dlTotal = dls.fold<int>(0, (a, d) => a + Downloads.bytes(d));
    final account = Account.expired
        ? 'Session expirée : reconnecte-toi pour reprendre la synchronisation'
        : (Account.signedIn ? '${Account.email} · synchronisé' : 'Pas de compte : rien n\'est synchronisé');
    final grey = const Color(0xFF8E8E93);
    final kidMode = kid;
    final profName = Store.profiles().firstWhere((e) => e.$1 == Store.profId, orElse: () => ('', 'Moi')).$2;
    final acctVal = Account.expired ? 'Expiré' : (Account.signedIn ? Account.email : 'Non connecté');
    String q(String k, List<(String, String)> o) => o.firstWhere((e) => e.$1 == Store.str(k), orElse: () => o.first).$2;
    const qOpts = [('4k', '4K si possible'), ('hd', 'HD · moins de données')];
    const aOpts = [('', 'Automatique'), ('fr', 'Français'), ('en', 'Anglais'), ('es', 'Espagnol'), ('de', 'Allemand'), ('pt', 'Portugais')];
    const sOpts = [('', 'Automatique'), ('no', 'Aucun'), ('fr', 'Français'), ('en', 'Anglais'), ('es', 'Espagnol'), ('de', 'Allemand'), ('pt', 'Portugais')];
    Widget sw(String t, IconData i, Color c, String k, bool def) => _row(i, c, t, on: Store.flag(k, def), onTap: () async {
          await Store.setFlag(k, !Store.flag(k, def));
          if (mounted) setState(() {});
        });
    // (nom dans la liste, titre de section, icône, lignes) : même arbre sur téléphone, tablette et télé
    final groups = <(String, String, IconData, List<Widget>)>[
      ('Compte', '', CupertinoIcons.person_crop_circle, [
        if (Device.tv) _row(CupertinoIcons.person_crop_circle_fill, const Color(0xFFAF52DE), 'Profil et compte', value: profName, chevron: true, onTap: () => Navigator.push(context, softRoute((_) => ProfilsScreen(onSwitch: widget.onSwitch ?? () {})))),
        _row(CupertinoIcons.smiley_fill, const Color(0xFF30D158), 'Mode enfant', on: kidMode, onTap: _kid),
      ]),
      ('Langues', 'Langues', CupertinoIcons.globe, [
        _row(CupertinoIcons.globe, const Color(0xFF0A84FF), 'Langue de l\'appli', value: L.names[L.lang] ?? 'English', chevron: true, onTap: () => _pickPage('Langue de l\'appli', [for (final c in L.supported) (c, L.names[c]!)], () => L.lang, (v) async {
          await L.set(v);
          Tmdb.reset();
        }, flags: true, foot: 'Change la langue de l\'appli, des fiches et du clavier de la télé.')),
        _row(CupertinoIcons.speaker_2_fill, const Color(0xFFFF9F0A), 'Langue audio', value: q('pref_aud', aOpts), chevron: true, onTap: () => _pickPage('Langue audio', aOpts, () => Store.str('pref_aud'), (v) => Store.setStr('pref_aud', v), flags: true, foot: 'Choisie automatiquement quand le film la propose.')),
        _row(CupertinoIcons.captions_bubble_fill, const Color(0xFF5E5CE6), 'Sous-titres', value: q('pref_sub', sOpts), chevron: true, onTap: () => _pickPage('Sous-titres', sOpts, () => Store.str('pref_sub'), (v) => Store.setStr('pref_sub', v), flags: true, foot: 'Appliqués au lancement de la lecture.')),
        _row(CupertinoIcons.flag_fill, const Color(0xFF30D158), 'Pays (chaînes de sport)', value: Rights.countries.firstWhere((c) => c.$1 == Rights.country, orElse: () => ('', '—')).$2, chevron: true, onTap: () => _pickPage('Pays', [for (final c in Rights.countries) (c.$1, c.$2)], () => Rights.country, (v) => Store.setStr('country', v), foot: 'Sert à trouver la chaîne qui diffuse un match, selon les droits TV de ton pays.')),
      ]),
      ('Lecture', 'Lecture', CupertinoIcons.play_circle, [
        _row(CupertinoIcons.slider_horizontal_3, const Color(0xFF0A84FF), 'Qualité', value: q('pref_q', qOpts).replaceAll(' si possible', '').replaceAll(' · moins de données', ''), chevron: true, onTap: () => _pickPage('Qualité', qOpts, () => Store.quality, (v) => Store.setStr('pref_q', v), foot: 'Films et chaînes proposés en plusieurs qualités.')),
        if (Device.tv) _row(CupertinoIcons.film, const Color(0xFFFF9F0A), 'Image du direct', value: q('dec_live', [('', Device.tv ? 'Matériel (recommandé)' : 'Automatique'), ('di', 'Désentrelacée'), ('sw', 'Logiciel'), ('swdi', 'Logiciel + désentrelacée')]), chevron: true, onTap: () => _pickPage('Image du direct', [('', Device.tv ? 'Logiciel (recommandé)' : 'Automatique'), ('di', 'Désentrelacée'), ('sw', 'Logiciel'), ('swdi', 'Logiciel + désentrelacée')], () => Store.str('dec_live'), (v) => Store.setStr('dec_live', v), foot: 'Si l\'image des chaînes TNT est hachée ou déchirée : essaie « Désentrelacée », puis « Logiciel ».')),
        _row(CupertinoIcons.speedometer, const Color(0xFF30D158), 'Tampon de lecture', value: '${_PlayerScreenState.bufSecs} s', chevron: true, onTap: () => _pickPage('Tampon de lecture', [for (final v in [1, ...List.generate(18, (i) => (i + 1) * 5)]) ('$v', '$v s')], () => '${_PlayerScreenState.bufSecs}', (v) => Store.setStr('buf_s', v), foot: 'Secondes de vidéo gardées d\'avance. Plus c\'est grand, moins il y a de coupures (au prix d\'un démarrage un peu plus long).')),
        if (Device.tv) sw('Lecture directe (plus fluide)', CupertinoIcons.bolt_fill, const Color(0xFFFFD60A), 'vo_embed', true),
        if (Device.tv) sw('Adapter la fréquence de l\'écran', CupertinoIcons.tv, const Color(0xFF64D2FF), 'fpsmatch', false),
        sw('Passer l\'intro', CupertinoIcons.forward_fill, const Color(0xFFFF375F), 'skipauto', false),
        sw('Épisode suivant', CupertinoIcons.forward_end_fill, const Color(0xFF64D2FF), 'autonext', true),
      ]),
      ('Personnaliser', 'Personnaliser', CupertinoIcons.slider_horizontal_3, [
        _row(CupertinoIcons.wand_stars, const Color(0xFF5B8CFF), 'Refaire la configuration', value: '', chevron: true, onTap: () => Navigator.push(context, softRoute((_) => OnboardingFlow(redo: true, onDone: () => Navigator.of(context).pop())))),
        _row(CupertinoIcons.paintbrush_fill, const Color(0xFFFF375F), 'Fond de l\'appli', value: Aurora.current.$2.split(' (').first, chevron: true, onTap: () => _pickPage('Fond de l\'appli', [for (final e in Aurora.styles) (e.$1, e.$2)], () => Aurora.currentId, (v) async {
              await Store.setStr('bg_style', v);
              Aurora.tick.value++;
            }, foot: 'Le même fond sur tous les écrans.')),
        _row(CupertinoIcons.rectangle_split_3x1_fill, const Color(0xFF5E5CE6), 'Onglets', value: '${Store.tabsVisible().length} onglets', chevron: true, onTap: () => Navigator.push(context, softRoute((_) => const TabsSettings()))),
        if (!kid) _row(CupertinoIcons.sportscourt_fill, const Color(0xFFFF9F0A), 'Sport', value: '${Store.sportKeys.length} championnats', chevron: true, onTap: () => Navigator.push(context, softRoute((_) => SportSettings(onKeys: (k) async {
              await Store.saveSportKeys(k);
              Store.persoTick.value++;
            })))),
        _row(CupertinoIcons.square_grid_2x2_fill, const Color(0xFF30B0C7), 'Écran d\'accueil', value: '${Store.homeIds.length - Store.homeHidden().length} sections', chevron: true, onTap: () => Navigator.push(context, softRoute((_) => const HomeSettings()))),
      ]),
      ('Contenu', 'Contenu', CupertinoIcons.square_stack, [
        _row(CupertinoIcons.cube_box_fill, const Color(0xFF32ADE6), 'Sources', value: _srcs.where((s) => s.$1 == Store.activeId).map((s) => s.$2).firstOrNull ?? (_srcs.isEmpty ? 'Ajouter' : ''), chevron: true, onTap: () async {
          if (!await _unlocked() || !mounted) return;
          await Navigator.push(context, softRoute((_) => SourcesScreen(onSwitch: () {
                widget.onSwitch?.call();
              })));
          _loadSrcs();
        }),
        _row(CupertinoIcons.list_bullet, const Color(0xFFFF9F0A), 'Catégories', value: counts.isEmpty ? 'Aucune' : counts, chevron: true, onTap: () async {
          if (!await _unlocked() || !mounted) return;
          Navigator.of(context).popUntil((r) => r.isFirst);
          widget.onSelection();
        }),
        _row(CupertinoIcons.eye_slash_fill, grey, 'Chaînes masquées', value: Store.hidden.isEmpty ? 'Aucune' : '${Store.hidden.length}', chevron: Store.hidden.isNotEmpty, onTap: Store.hidden.isEmpty ? null : _hiddenPage),
        if (!Device.tv) _row(CupertinoIcons.arrow_down_circle_fill, const Color(0xFF0A84FF), 'Téléchargements', value: dls.isEmpty ? 'Aucun' : '${dls.length} · ${sizeLabel(dlTotal)}', chevron: true, onTap: _dlPage),
        _row(CupertinoIcons.clock_fill, grey, 'Actualisation automatique', value: _refreshLabel(), chevron: true, onTap: () => _pickPage('Actualisation automatique', const [('12', 'Toutes les 12 h'), ('24', 'Tous les jours'), ('72', 'Tous les 3 jours'), ('168', 'Toutes les semaines'), ('0', 'Seulement à la main')], () => '${Store.catRefreshMs ~/ 3600000}', (v) => Store.setStr('cat_refresh_h', v), foot: 'Au lancement, l\'appli affiche tout de suite le catalogue gardé en mémoire, puis le met à jour seulement s\'il est plus ancien que ce délai. « Actualiser » le met à jour à la demande.')),
        _row(CupertinoIcons.folder_fill, grey, 'Cache', value: _imgBytes < 0 || _catBytes < 0 ? '' : sizeLabel(_imgBytes + _catBytes), chevron: true, onTap: _stockPage),
        ValueListenableBuilder<(int, int)>(
          valueListenable: widget.progress,
          builder: (_, p, __) => _row(CupertinoIcons.arrow_2_circlepath, const Color(0xFF30D158), 'Actualiser', value: p.$2 > 0 ? '${p.$1}/${p.$2}' : _ago(Store.catT), trailing: p.$2 > 0 ? const SizedBox(width: 18, height: 18, child: Spinner(strokeWidth: 2)) : null, onTap: () {
            if (p.$2 > 0) return;
            widget.onRefresh();
            _snack('Actualisation lancée : tu peux continuer à naviguer.');
          }),
        ),
      ]),
      if (!Connect.tvNow)
        ('Appareils', 'Appareils', CupertinoIcons.tv, [
          _row(CupertinoIcons.tv_fill, const Color(0xFFAF52DE), 'Connecter une télé', value: Account.signedIn ? '' : 'Compte requis', chevron: true, onTap: _pairTv),
        ]),
      ('Aide', '', CupertinoIcons.question_circle, [
        _row(CupertinoIcons.wrench_fill, const Color(0xFFFF9F0A), 'Aide et dépannage', chevron: true, onTap: _aidePage),
        _row(CupertinoIcons.info_circle_fill, grey, 'À propos', value: 'Version $kBuild', chevron: true, onTap: _aboutPage),
      ]),
      ('Déconnexion', '', CupertinoIcons.person_crop_circle_badge_xmark, [
        _row(CupertinoIcons.person_crop_circle_badge_xmark, const Color(0xFFFF9F0A), 'Déconnexion et suppression', chevron: true, onTap: _disconnectPage),
      ]),
    ];
    _groups = groups;
    Widget content(int i) => _box(groups[i].$4);
    if (Device.tv) {
      final cur = _sec.clamp(0, groups.length - 1);
      return DsBg(child: Scaffold(backgroundColor: Colors.transparent, 
        body: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(40 + pad.left, 0, 40 + pad.right, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 340,
                child: ListView(padding: EdgeInsets.only(top: pad.top + 8, bottom: 40 + pad.bottom), children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                    child: Row(children: [
                      RoundButton(size: 44, label: 'Retour', onTap: () => Navigator.pop(context), child: const Ic('back', size: 20)),
                      const SizedBox(width: 14),
                      Text('Réglages', style: T(28, w: 750, ls: -0.035)),
                    ]),
                  ),
                  for (var i = 0; i < groups.length; i++)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: FocusCard(
                        radius: 16,
                        autofocus: Device.tv && i == 0,
                        onTap: () => setState(() => _sec = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(color: i == cur ? Colors.white : const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(16)),
                          child: Row(children: [
                            Icon(groups[i].$3, size: 22, color: i == cur ? kBg : kMut),
                            const SizedBox(width: 12),
                            Expanded(child: Text(groups[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(17, w: 700, color: i == cur ? kBg : kText))),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: ListView(key: ValueKey(cur), padding: EdgeInsets.fromLTRB(0, pad.top + 24, 0, 60 + pad.bottom), children: [
                  Padding(padding: const EdgeInsets.fromLTRB(26, 0, 22, 14), child: Text(groups[cur].$1, style: T(26, w: 800, ls: -0.03))),
                  content(cur),
                ]),
              ),
            ]),
          ),
        ),
      ));
    }
    return DsBg(child: Scaffold(backgroundColor: Colors.transparent, 
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 60 + pad.bottom), children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, pad.top + 8, 16, 14),
              child: Row(children: [
                RoundButton(size: 44, label: 'Retour', onTap: () => Navigator.pop(context), child: const Ic('back', size: 20)),
                const SizedBox(width: 14),
                Text('Réglages', style: T(28, w: 750, ls: -0.035)),
              ]),
            ),
            // carte profil compacte : le nom du profil actif sert aussi pour « Bonjour … »
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: FocusCard(
                radius: 14,
                onTap: () => Navigator.push(context, softRoute((_) => ProfilsScreen(onSwitch: widget.onSwitch ?? () {}))),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(14), border: Border.all(color: kEdge, width: 0.8)),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7FA6FF), Color(0xFF4A6FE0)])),
                      child: Text(profName.isEmpty ? '?' : profName.characters.first.toUpperCase(), style: T(22, w: 800)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(profName, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(19, w: 700, ls: -0.02)),
                        const SizedBox(height: 2),
                        Text(acctVal, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(13.5, color: Account.expired ? const Color(0xFFFF6B7A) : kMut)),
                      ]),
                    ),
                    const Icon(CupertinoIcons.chevron_right, color: kMut, size: 16),
                  ]),
                ),
              ),
            ),
            for (var i = 0; i < groups.length; i++) ...[
              if (groups[i].$2.isNotEmpty) _group(groups[i].$2) else const SizedBox(height: 18),
              content(i),
            ],
          ]),
        ),
      ),
    ));
  }

  List<(String, String, IconData, List<Widget>)> _groups = const [];
  final ValueNotifier<int> _tick = ValueNotifier<int>(0);

  /// toute modification d'un réglage redessine aussi la sous-page ouverte
  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tick.value++;
    });
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  // ---- éléments de liste groupée (style Réglages iOS) ----

  /// ligne : icône carrée colorée, libellé, valeur à droite, puis chevron / interrupteur / coche
  Widget _row(IconData? icon, Color tint, String label, {String? value, Color? valueColor, bool? on, bool danger = false, bool chevron = false, bool check = false, VoidCallback? onTap, Widget? trailing}) {
    final tv = Device.tv;
    final body = Container(
      height: tv ? 64 : 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        if (icon != null) ...[
          Container(width: 30, height: 30, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: Colors.white)),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(tv ? 18 : 16.5, w: 500, color: danger ? const Color(0xFFFF6B7A) : kText))),
        if (value != null && value.isNotEmpty) ConstrainedBox(constraints: BoxConstraints(maxWidth: tv ? 320 : 170), child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: T(tv ? 16 : 15, color: valueColor ?? kMut))),
        if (trailing != null) ...[const SizedBox(width: 8), trailing]
        else if (on != null) ...[const SizedBox(width: 8), _sw(on)]
        else if (check) const Icon(CupertinoIcons.checkmark_alt, color: kAccent, size: 20)
        else if (chevron) ...[const SizedBox(width: 6), const Icon(CupertinoIcons.chevron_right, color: kMut, size: 15)],
      ]),
    );
    return onTap == null ? body : Semantics(button: true, label: label, child: FocusCard(onTap: onTap, radius: tv ? 10 : 0, focusScale: 1, child: body));
  }

  /// groupe de lignes dans un cadre arrondi, séparées par un filet décalé
  Widget _box(List<Widget> rows) {
    final r = rows;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(14), border: Border.all(color: kEdge, width: 0.8)),
          child: Column(children: [
            for (var i = 0; i < r.length; i++) ...[
              if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 56, color: kEdge),
              if (i == 0) ZoneFirst(child: r[i]) else r[i],
            ],
          ]),
        ),
      ),
    );
  }

  Widget _foot(String t) => Padding(padding: const EdgeInsets.fromLTRB(32, 8, 24, 0), child: Text(t, style: T(12.5, color: kMut, h: 1.4)));

  /// sous-page à barre de retour ; se redessine quand un réglage change
  void _page(String title, List<Widget> Function() body) => Navigator.push(
        context,
        softRoute((ctx) => ValueListenableBuilder<int>(
              valueListenable: _tick,
              builder: (ctx, _, __) {
                final pad = MediaQuery.paddingOf(ctx);
                return Scaffold(
                  body: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: LargeTitle(title: title, onBack: () => Navigator.pop(ctx), children: body()),
                  ),
                );
              },
            )),
      );

  /// choix dans une liste à coche (qualité, langues)
  String _refreshLabel() {
    final h = Store.catRefreshMs ~/ 3600000;
    return h == 0 ? 'À la main' : (h < 24 ? '$h h' : (h == 24 ? '1 jour' : (h == 168 ? '1 semaine' : '${h ~/ 24} jours')));
  }

  void _pickPage(String title, List<(String, String)> opts, String Function() cur, Future<void> Function(String) pick, {String foot = '', bool flags = false}) => _page(title, () => [
        ChoiceGrid(
          flags: flags,
          options: opts,
          selected: cur(),
          onPick: (v) async {
            await pick(v);
            if (mounted) setState(() {});
          },
        ),
        if (foot.isNotEmpty) _foot(foot),
      ]);

  void _dlPage() => _page('Téléchargements', () {
        final dls = Downloads.all();
        final tot = dls.fold<int>(0, (a, d) => a + Downloads.bytes(d));
        return [
          ValueListenableBuilder<Map<String, double>>(
            valueListenable: Downloads.progress,
            builder: (_, m, __) => m.isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 14), child: _box([for (final e in m.entries) _row(CupertinoIcons.arrow_2_circlepath, const Color(0xFF0A84FF), 'En cours · ${(e.value * 100).round()} %', value: 'Annuler', onTap: () => Downloads.cancel(e.key))])),
          ),
          if (dls.isEmpty) _foot('Aucun film téléchargé. Depuis la fiche d\'un film : « Télécharger » pour le regarder hors ligne.') else ...[
            _box([for (final d in dls) _row(CupertinoIcons.checkmark_alt_circle_fill, const Color(0xFF30D158), d.name, value: sizeLabel(Downloads.bytes(d)), trailing: const Icon(CupertinoIcons.trash, color: kMut, size: 18), onTap: () => _deleteDl(d))]),
            _foot('${dls.length} film${dls.length > 1 ? 's' : ''} · ${sizeLabel(tot)}. Touche un film pour le supprimer.'),
          ],
        ];
      });

  void _stockPage() => _page('Cache', () => [
        _box([
          _row(CupertinoIcons.photo_fill, const Color(0xFF32ADE6), 'Images', value: _imgBytes < 0 ? '…' : sizeLabel(_imgBytes), chevron: true, onTap: _clearImages),
          _row(CupertinoIcons.square_stack_3d_up_fill, const Color(0xFFFF9F0A), 'Catalogue', value: _catBytes < 0 ? '…' : sizeLabel(_catBytes), chevron: true, onTap: _clearCatalog),
        ]),
        _foot('Toucher une ligne la vide. Les téléchargements ne sont pas touchés ; le catalogue se recharge tout seul.'),
      ]);

  void _aidePage() => _page('Aide et dépannage', () => [
        _box([
          _row(CupertinoIcons.wifi, const Color(0xFF30D158), 'Tester ma source', chevron: true, onTap: () => testSource(context)),
          _row(CupertinoIcons.wrench_fill, const Color(0xFFFF9F0A), 'Réparer l\'application', chevron: true, onTap: _repair),
          _row(CupertinoIcons.doc_text_fill, const Color(0xFF8E8E93), 'Voir le journal', chevron: true, onTap: _journal),
          if (!Device.tv) _row(CupertinoIcons.doc_on_doc_fill, const Color(0xFF8E8E93), 'Copier le journal', onTap: _copyJournal),
        ]),
        _foot('Source injoignable alors que ta connexion marche ? Vérifie qu\'aucun autre appareil ne lit ton abonnement. Sur iPhone, désactive aussi le Relais privé iCloud (Réglages › ton nom › iCloud) et tout VPN : ils font passer l\'appli par des adresses que beaucoup de fournisseurs refusent.'),
        _SubHead('Ton avis'),
        _box([
          _row(CupertinoIcons.chat_bubble_text_fill, const Color(0xFF5B8CFF), 'Envoyer un retour', value: 'problème, idée, recommandation', chevron: true, onTap: _feedbackPage),
        ]),
        _foot('Le journal ne contient jamais tes identifiants. Déconnexion, effacement et suppression du compte : Réglages › Compte.'),
      ]);

  // ---- retours des utilisateurs
  final TextEditingController _fbCtl = TextEditingController();
  String _fbType = 'bug';
  bool _fbDiag = true;
  static const _fbTypes = [('bug', 'Un problème ou une erreur', CupertinoIcons.exclamationmark_triangle_fill, Color(0xFFFF9F0A)), ('idee', 'Une idée', CupertinoIcons.lightbulb_fill, Color(0xFFFFD60A)), ('reco', 'Une recommandation (film, série, chaîne)', CupertinoIcons.hand_thumbsup_fill, Color(0xFF30D158)), ('autre', 'Autre', CupertinoIcons.ellipsis_circle_fill, Color(0xFF8E8E93))];

  void _feedbackPage() => _page('Envoyer un retour', () => [
        _SubHead('Sujet'),
        _box([for (final t in _fbTypes) _row(t.$3, t.$4, t.$2, check: _fbType == t.$1, onTap: () => setState(() => _fbType = t.$1))]),
        _SubHead('Ton message'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppField(controller: _fbCtl, maxLines: 5, maxLength: 1000, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: _fbType == 'bug' ? 'Ce qui s\'est passé, sur quel film ou quelle chaîne' : (_fbType == 'reco' ? 'Le titre ou la chaîne à ajouter' : 'Dis-nous tout'), filled: true, fillColor: kGlass, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
        ),
        const SizedBox(height: 14),
        _box([
          _row(CupertinoIcons.info_circle_fill, const Color(0xFF8E8E93), 'Joindre les infos techniques', on: _fbDiag, onTap: () => setState(() => _fbDiag = !_fbDiag)),
          _row(CupertinoIcons.paperplane_fill, const Color(0xFF5B8CFF), 'Envoyer', onTap: _sendFeedback),
          if (!Device.tv) _row(CupertinoIcons.mail_solid, const Color(0xFF32ADE6), 'Envoyer par e-mail', chevron: true, onTap: _mailFeedback),
        ]),
        _foot('Infos techniques : version, appareil, langue et dernières erreurs. Jamais tes identifiants ni ta source. Connecté à ton compte, le retour part tout de suite ; sinon il est gardé et part à ta prochaine connexion.'),
      ]);

  Future<String> _fbDiagText() async {
    final j = (await Journal.read()).trim().split('\n');
    final os = kIsWeb ? 'web' : '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    return 'MinouFlix build $kBuild · ${Device.tv ? 'Android TV' : os} · langue ${L.lang}\n${j.skip(j.length > 12 ? j.length - 12 : 0).join('\n')}';
  }

  Future<void> _sendFeedback() async {
    final msg = _fbCtl.text.trim();
    if (msg.length < 3) {
      _snack('Écris d\'abord ton message.');
      return;
    }
    await Store.addFeedback({'id': DateTime.now().millisecondsSinceEpoch, 't': DateTime.now().toUtc().toIso8601String(), 'type': _fbType, 'msg': msg, if (_fbDiag) 'diag': await _fbDiagText()});
    _fbCtl.clear();
    if (!Account.signedIn) {
      _snack('Retour enregistré : il partira quand tu te connecteras à ton compte (ou envoie-le par e-mail).');
    } else {
      final ok = await Sync.run();
      _snack(Store.feedbackPending().isEmpty || ok ? 'Merci ! Retour envoyé.' : 'Retour enregistré : il partira à la prochaine synchro.');
    }
    if (mounted) setState(() {});
  }

  Future<void> _mailFeedback() async {
    final msg = _fbCtl.text.trim();
    final body = '$msg${_fbDiag ? '\n\n--\n${await _fbDiagText()}' : ''}';
    final u = Uri(scheme: 'mailto', path: kContact, queryParameters: {'subject': 'MinouFlix · ${_fbTypes.firstWhere((t) => t.$1 == _fbType).$2}', 'body': body.length > 1500 ? body.substring(0, 1500) : body});
    await launchUrl(Uri.parse(u.toString().replaceAll('+', '%20')));
  }

  void _aboutPage() => _page('À propos', () => [
        _box([
          _row(CupertinoIcons.info_circle_fill, const Color(0xFF8E8E93), 'Version', value: '$kBuild', chevron: true, onTap: () => Navigator.push(context, softRoute((_) => TextPage(title: 'Nouveautés', sections: [for (final n in kNews) (n.$1, [for (final l in n.$2) '• $l'].join('\n'))])))),
          if (!kStore && !kIsWeb && Platform.isAndroid) _row(CupertinoIcons.arrow_down_circle_fill, const Color(0xFF30D158), 'Rechercher une mise à jour', chevron: true, onTap: _update),
          _row(CupertinoIcons.lock_shield_fill, const Color(0xFF32ADE6), 'Confidentialité', chevron: true, onTap: () => Navigator.push(context, softRoute((_) => const TextPage(title: 'Confidentialité', sections: kPrivacy)))),
        ]),
        Padding(padding: const EdgeInsets.fromLTRB(32, 18, 24, 0), child: Text('MinouFlix est un lecteur : il ne fournit aucun contenu. Les chaînes, films et séries viennent de l\'abonnement que tu y connectes.', style: T(12.5, color: kMut, h: 1.4))),
        Padding(padding: const EdgeInsets.fromLTRB(32, 10, 24, 0), child: Text('Affiches, résumés et logos : The Movie Database (TMDB). $kTmdbNotice', style: T(12.5, color: kMut, h: 1.4))),
      ]);
}

/// sous-titre dans une catégorie
class _SubHead extends StatelessWidget {
  final String title;
  const _SubHead(this.title);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(26, 24, 22, 10), child: Text(title.toUpperCase(), style: T(12, w: 700, ls: 0.09, color: kMut)));
}

/// petite action de la fiche : icône dans un rond translucide, légende dessous (style Apple TV)
class _ActIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActIcon({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 92,
        child: FocusCard(
          radius: 16,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x1FFFFFFF)), child: Icon(icon, size: 24, color: Colors.white)),
              const SizedBox(height: 7),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: T(11.5, w: 550, color: const Color(0xFFAEB7C8))),
            ]),
          ),
        ),
      );
}

/// bouton rond d'action (Plus…)
class _RoundAct extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _RoundAct({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        button: true,
        child: FocusCard(
          radius: 27,
          onTap: onTap,
          child: Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x24FFFFFF), border: Border.all(color: kEdge)), child: Icon(icon, size: 22, color: Colors.white)),
        ),
      );
}

/// ---------- fiche film / série ----------
class DetailScreen extends StatefulWidget {
  final Xtream x;
  final Item item;
  final Future<Detail?> Function(Item) detailFor;
  final Lib? lib;
  final void Function(Item) onOpen;
  const DetailScreen({super.key, required this.x, required this.item, required this.detailFor, this.lib, required this.onOpen});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Detail? d;
  Fiche? f;
  bool _fReady = false;      // TMDB a répondu (ou délai dépassé) : on peut choisir l'image et le titre définitifs
  List<Episode> eps = [];
  int season = 0, ver = 0;
  bool _more = false;      // résumé déplié
  String? error;

  @override
  void initState() {
    super.initState();
    _initVer();
    _loadFiche();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.item.kind == Kind.series) {
        final r = await widget.x.seriesDetail(_sid);
        d = r.$1;
        eps = r.$2;
        season = eps.isEmpty ? 0 : eps.first.season;
      } else {
        d = await widget.detailFor(widget.item) ?? await widget.x.vodDetail(widget.item.id);
      }
    } catch (e) {
      error = '$e';
      d = const Detail();
    }
    if (mounted) setState(() {});
  }

  /// TMDB (titre, logo, image, résumé dans ta langue) part en même temps que le fournisseur ; rien n'est affiché avant, pour ne rien voir changer ensuite
  void _loadFiche() {
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted && !_fReady) setState(() => _fReady = true);
    });
    Tmdb.fiche(widget.item).then((v) {
      if (mounted) {
        setState(() {
          f = v;
          _fReady = true;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _fReady = true);
    });
  }

  void _play(String url, String title, {Prog? prog, List<(String, String, Prog)> next = const []}) => Navigator.push(context, softRoute((_) => PlayerScreen(url: url, title: title, prog: prog, next: next, tmdb: Tmdb.fiche(widget.item)))).then((_) {
        if (mounted) setState(() {});
      });

  /// bande-annonce dans le lecteur de l'appli ; si YouTube ne donne pas le flux, la page web s'ouvre
  Future<void> _trailer(String id) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(seconds: 2), content: Text('Chargement de la bande-annonce…')));
    final r = await Trailer.resolve(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (r == null) {
      launchUrl(Uri.parse('https://www.youtube.com/watch?v=$id'), mode: LaunchMode.externalApplication);
      return;
    }
    Navigator.push(context, softRoute((_) => PlayerScreen(url: r.$1, audioUrl: r.$2, debug: true, title: '${widget.item.title} · Bande-annonce')));
  }

  String _mmss(int ms) {
    final s = ms ~/ 1000, h = s ~/ 3600, m = (s % 3600) ~/ 60, c = s % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${c.toString().padLeft(2, '0')}' : '$m:${c.toString().padLeft(2, '0')}';
  }

  Prog _epProg(Episode x) => Prog(kind: 'ep', id: x.id, sid: _sid, ext: x.ext, name: 'S${x.season} · É${x.number}${x.title.isEmpty ? '' : ' · ${x.title}'}', icon: widget.item.icon, sname: widget.item.title);

  /// MinouFlix Connect : lance ce titre (à la position de reprise) sur la télé du même compte
  Future<void> _sendTv(Prog? p) async {
    if (p == null) return;
    final ok = await Connect.send(Connect.playCmd(p));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Envoyé sur la télé (elle doit avoir MinouFlix ouvert).' : 'Envoi impossible : connecte-toi au même compte sur la télé.')));
  }

  void _playEp(Episode e, {Prog? prog}) {
    final it = widget.item;
    final all = [...eps]..sort((a, b) => a.season != b.season ? a.season.compareTo(b.season) : a.number.compareTo(b.number));
    final at = all.indexWhere((x) => x.id == e.id);
    final nx = [for (final x in all.skip(at + 1).take(8)) ('${it.title} S${x.season}E${x.number}', widget.x.episodeUrl(x.id, x.ext), _epProg(x))];
    final saved = Store.allProg().where((p) => p.key == 'ep:${e.id}' && p.pos > 20000 && (p.dur == 0 || p.pos < p.dur * 0.95)).firstOrNull;
    _play(widget.x.episodeUrl(e.id, e.ext), '${it.title} S${e.season}E${e.number}', prog: prog ?? saved ?? _epProg(e), next: nx);
  }

  /// toutes les versions du même titre (qualités / catégories différentes)
  List<Item> get versions {
    final it = widget.item;
    final l = widget.lib;
    if (l == null || it.kind == Kind.live) return [it];
    final known = l.rows.where((r) => r.p.key == it.p.key && r.year.isNotEmpty).map((r) => r.year).toSet();
    final y = it.year.isNotEmpty ? it.year : (known.length == 1 ? known.first : '');
    final v = l.rows.where((r) => (r.p.key == it.p.key && (r.year == y || r.year.isEmpty || y.isEmpty)) || (it.icon.isNotEmpty && r.icon == it.icon && r.year == it.year)).toList();
    if (!v.any((r) => r.id == it.id)) v.insert(0, it);
    // qualité la plus haute d'abord
    const rank = {'4K': 0, 'FHD': 1, 'HD': 2, '': 2, 'SD': 3};
    v.sort((a, b) => (rank[a.quality] ?? 2).compareTo(rank[b.quality] ?? 2));
    return v;
  }

  /// libellé d'une version : qualité · langue · catégorie · format
  String _verLabel(Item v) {
    final cat = widget.lib?.cats[v.catId]?.label ?? '';
    return [v.quality.isEmpty ? 'HD' : v.quality, langTag(v.name), if (cat.isNotEmpty) cat, v.ext].where((e) => e.isNotEmpty).join(' · ');
  }

  /// bouton « Version » : une grande zone tactile (ou un bouton télécommande) qui ouvre la liste des versions
  Widget _verButton(List<Item> vs, Item cur) {
    final tag = langTag(cur.name);
    return PillButton(label: 'Version ${cur.quality.isEmpty ? 'HD' : cur.quality}${tag.isEmpty ? '' : ' · $tag'} ▾', height: 54, onTap: () => _verMenu(vs));      // détail complet dans la liste
  }

  Future<void> _verMenu(List<Item> vs) async {
    final cur = ver.clamp(0, vs.length - 1);
    final i = await appSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.fromLTRB(28, 22, 28, 6), child: Align(alignment: Alignment.centerLeft, child: Text('Version et source', style: T(22, w: 750)))),
            for (var k = 0; k < vs.length; k++)
              ListTile(
                minVerticalPadding: 14,
                autofocus: k == cur,
                leading: Icon(k == cur ? Icons.check_circle_rounded : Icons.circle_outlined),
                title: Text(_verLabel(vs[k]), style: T(16, w: 600)),
                onTap: () => Navigator.pop(context, k),
              ),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    );
    if (i != null && mounted) _pickVer(i);
  }

  /// série : identifiant de la version choisie (les épisodes en dépendent)
  int get _sid {
    final vs = versions;
    return vs[ver.clamp(0, vs.length - 1)].id;
  }

  void _pickVer(int i) {
    if (i == ver) return;
    setState(() => ver = i);
    Store.setVerChoice(widget.item.kind.name, widget.item.p.key, versions[i].id.toString());      // choix retenu pour ce titre
    if (widget.item.kind == Kind.series) {
      setState(() {
        d = null;
        eps = [];
        error = null;
      });
      _load();
    }
  }

  /// version de départ : celle retenue pour ce titre, sinon la qualité par défaut des réglages
  void _initVer() {
    final vs = versions;
    if (vs.length < 2) return;
    // 1) la version déjà commencée (sinon « Reprendre » ne la trouverait pas), 2) le choix retenu pour ce titre, 3) la qualité par défaut
    final ids = {for (final v in vs) v.id};
    final started = Store.allProg().where((p) => !p.hidden && p.pos > 20000 && (p.dur == 0 || p.pos < p.dur * 0.95) && (widget.item.kind == Kind.series ? p.kind == 'ep' && ids.contains(p.sid) : p.kind == 'vod' && ids.contains(p.id))).toList()
      ..sort((a, b) => b.t.compareTo(a.t));
    final startedId = started.isEmpty ? 0 : (widget.item.kind == Kind.series ? started.first.sid : started.first.id);
    final saved = startedId != 0 ? startedId : (int.tryParse(Store.verChoice(widget.item.kind.name, widget.item.p.key)) ?? 0);
    var i = saved == 0 ? -1 : vs.indexWhere((v) => v.id == saved);
    if (i < 0) {
      final want4k = Store.quality == '4k';
      i = vs.indexWhere((v) => (v.quality == '4K') == want4k);
    }
    if (i >= 0) ver = i;
  }

  @override
  Widget build(BuildContext context) {
    // mode enfant : un contenu classé -12 ou plus (TMDB) n'est pas montré
    if (Store.kid && f != null && certAge(f!.cert) > 10) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: EmptyState(icon: Icons.child_care_rounded, title: 'Pas pour les enfants', sub: 'Ce titre est déconseillé aux moins de ${certAge(f!.cert)} ans. Quitte le mode enfant (code PIN) pour le regarder.'),
      );
    }
    final it = widget.item;
    final det = d;
    final seasons = eps.map((e) => e.season).toSet().toList()..sort();
    final top = MediaQuery.paddingOf(context).top;
    final vs = versions;
    final cur = vs[ver.clamp(0, vs.length - 1)];
    final meta = [
      if (det != null && det.year.isNotEmpty) det.year else if (it.year.isNotEmpty) it.year,
      if (it.kind == Kind.vod) _dur(f?.runtime ?? 0, det?.duration ?? ''),
      if (it.rating >= 1 && it.rating < 9.5) '★ ${it.rating.toStringAsFixed(1)}' else if (it.rating >= 9.5) '★ 10',
      if (it.quality.isNotEmpty) it.quality,
    ].where((e) => e.isNotEmpty).toList();
    final fi = f;
    final bd = !_fReady ? '' : (fi != null && fi.bg.isNotEmpty ? tmImg(fi.bg, 'w1280') : (det != null && det.backdrop.isNotEmpty ? det.backdrop : it.icon));
    final lib = widget.lib;
    final sim = fi == null || lib == null ? <Item>[] : uniqueTitles([for (final t in fi.simTitles) lib.byTitle(t)].whereType<Item>().where((r) => r.p.key != it.p.key)).take(14).toList();
    final saga = fi == null || lib == null ? <Item>[] : uniqueTitles([for (final t in fi.sagaTitles) lib.byTitle(t)].whereType<Item>().where((r) => r.p.key != it.p.key)).toList();
    final same = widget.lib == null ? <Item>[] : widget.lib!.rows.where((r) => r.catId == it.catId && r.p.key != it.p.key && r.icon.isNotEmpty).take(16).toList();
    final fav = '${it.kind.name}:${it.id}';
    final prs = Store.allProg().where((p) => !p.hidden && p.pos > 20000 && (p.dur == 0 || p.pos < p.dur * 0.95)).toList();
    // reprise = la plus récente de TOUTES les versions du titre : passer de 4K à HD reprend au même endroit
    final oldAny = it.kind == Kind.vod ? (prs.where((p) => p.kind == 'vod' && vs.any((v) => v.id == p.id)).toList()..sort((a, b) => b.t.compareTo(a.t))).firstOrNull : null;
    final old = oldAny == null ? null : (oldAny.id == cur.id ? oldAny : Prog(kind: 'vod', id: cur.id, ext: cur.ext, name: it.title, icon: it.icon, pos: oldAny.pos, dur: oldAny.dur, t: oldAny.t));
    final lastProg0 = it.kind == Kind.series ? (prs.where((p) => p.kind == 'ep' && vs.any((v) => v.id == p.sid)).toList()..sort((a, b) => b.t.compareTo(a.t))).firstOrNull : null;
    Episode? lastEp0 = lastProg0 == null ? null : eps.where((e) => e.id == lastProg0.id).firstOrNull;
    if (lastEp0 == null && lastProg0 != null) {
      // autre version de la série : même saison et même numéro d'épisode
      final m = RegExp(r'^S(\d+) · É(\d+)').firstMatch(lastProg0.name);
      if (m != null) lastEp0 = eps.where((e) => e.season == int.parse(m.group(1)!) && e.number == int.parse(m.group(2)!)).firstOrNull;
    }
    final lastEp = lastEp0;
    final lastProg = (lastProg0 != null && lastEp != null && lastProg0.id != lastEp.id) ? Prog(kind: 'ep', id: lastEp.id, sid: _sid, ext: lastEp.ext, name: lastProg0.name, icon: lastProg0.icon, sname: lastProg0.sname, pos: lastProg0.pos, dur: lastProg0.dur, t: lastProg0.t) : lastProg0;
    final wide = Device.tv;     // fiche « salon » sur télé seulement
    // grand écran (télé) : fiche « cinéma » — grand visuel, titre, résumé et boutons compacts regroupés au même endroit
    String vodPath() => Downloads.get('${Store.pre}vod:${cur.id}')?.path ?? widget.x.vodUrl(cur.id, cur.ext);
    Widget playBtn() {
      if (it.kind == Kind.vod) return PillButton(autofocus: true, label: old != null ? 'Reprendre à ${_mmss(old.pos)}' : 'Lecture', icon: 'play', primary: true, height: 54, onTap: () => _play(vodPath(), it.title, prog: old ?? Prog(kind: 'vod', id: cur.id, ext: cur.ext, name: it.title, icon: it.icon)));
      if (lastEp != null) return PillButton(autofocus: true, label: 'Reprendre S${lastEp.season}E${lastEp.number} à ${_mmss(lastProg!.pos)}', icon: 'play', primary: true, height: 54, onTap: () => _playEp(lastEp, prog: lastProg));
      if (eps.isNotEmpty) return PillButton(autofocus: true, label: 'Lecture S${eps.first.season}E${eps.first.number}', icon: 'play', primary: true, height: 54, onTap: () => _playEp(eps.first));
      return PillButton(
          label: error != null ? 'Réessayer' : 'Chargement des épisodes…',
          height: 54,
          onTap: () {
            if (error == null && d == null) return;
            setState(() {
              error = null;
              d = null;
            });
            _load();
          });
    }

    final wideActions = Wrap(spacing: 12, runSpacing: 12, children: [
      playBtn(),
      if (it.kind == Kind.vod && old != null) PillButton(label: 'Depuis le début', height: 54, onTap: () => _play(vodPath(), it.title, prog: Prog(kind: 'vod', id: cur.id, ext: cur.ext, name: it.title, icon: it.icon))),
      if (vs.length > 1) _verButton(vs, cur),
      PillButton(label: '+ Ajouter à…', height: 54, onTap: () => collectionSheet(context, fav)),
      if (fi != null && fi.trailer.isNotEmpty) PillButton(label: 'Bande-annonce', icon: 'play', height: 54, onTap: () => _trailer(fi.trailer)),
      if (it.kind == Kind.vod && !Device.tv)      // pas de téléchargement sur la télé
        ValueListenableBuilder<Map<String, double>>(
          valueListenable: Downloads.progress,
          builder: (_, m, __) {
            final key = '${Store.pre}vod:${cur.id}';
            final dl = Downloads.get(key), p = m[key];
            if (p != null) return PillButton(label: 'Annuler · ${(p * 100).round()} %', height: 54, onTap: () => Downloads.cancel(key));
            if (dl != null) {
              return PillButton(label: 'Hors ligne ✓ · retirer', height: 54, onTap: () async {
                await Downloads.remove(key);
                if (mounted) setState(() {});
              });
            }
            return PillButton(label: 'Télécharger', height: 54, onTap: () => Downloads.start(key, widget.x.vodUrl(cur.id, cur.ext), it.title, it.icon, cur.ext));
          },
        ),
    ]);
    final plotText = !_fReady ? '' : (fi != null && fi.plot.isNotEmpty ? fi.plot : (det?.plot ?? ''));
    return Scaffold(
      body: Stack(children: [
        ListView(padding: EdgeInsets.zero, cacheExtent: 8000, children: [
          SizedBox(
            height: wide ? (MediaQuery.sizeOf(context).height * 0.78).clamp(420.0, 760.0) : 300 + top,
            child: Stack(fit: StackFit.expand, children: [
              fadeBackdrop(bd, _fReady ? it.icon : ''),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, .3, .72, 1], colors: [Color(0x8006080D), Color(0x0006080D), Color(0xB306080D), kBg]))),
              if (wide)
                Positioned(
                  left: 56,
                  right: 56,
                  bottom: 28,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: AnimatedOpacity(
                        opacity: _fReady ? 1 : 0,
                        duration: const Duration(milliseconds: 260),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        TitleLogo(ready: _fReady, url: fi != null && fi.logo.isNotEmpty ? tmImg(fi.logo, 'w500') : '', title: fi != null && fi.title.isNotEmpty ? fi.title : it.title, big: true, wide: true),
                        const SizedBox(height: 12),
                        Text([...meta, if (fi != null && fi.cert.isNotEmpty) fi.cert == 'U' ? 'Tout public' : '-${fi.cert}'].join('  ·  '), style: T(16, w: 600, color: const Color(0xFFC4CBD9))),
                        if (plotText.isNotEmpty) ...[const SizedBox(height: 10), Text(plotText, maxLines: 4, overflow: TextOverflow.ellipsis, style: T(16.5, w: 400, color: const Color(0xFFDFE5F0), h: 1.4))],
                        const SizedBox(height: 22),
                        wideActions,
                      ]),
                      ),
                    ),
                  ),
                )
              else
              Positioned(
                left: 16,
                right: 16,
                bottom: 6,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        TitleLogo(ready: _fReady, url: fi != null && fi.logo.isNotEmpty ? tmImg(fi.logo, 'w500') : '', title: fi != null && fi.title.isNotEmpty ? fi.title : it.title),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final m in meta) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(99), border: Border.all(color: const Color(0x1FFFFFFF), width: 0.6)), child: Text(m, style: T(13, w: 600, color: const Color(0xFFE6EBF5)))),
                        ]),
                      ]),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
          if (det == null || !_fReady) const SkeletonBlock(lines: 5) else ...[
            if (!wide) ...[
              // téléphone / tablette : une ligne principale (Lecture, Ma liste, Plus) puis de petites actions avec icône
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  Expanded(child: playBtn()),
                  const SizedBox(width: 10),
                  ValueListenableBuilder<int>(
                    valueListenable: Store.favTick,
                    builder: (_, __, ___) => _RoundAct(icon: Store.isFav(fav) ? CupertinoIcons.checkmark : CupertinoIcons.plus, label: 'Ajouter à ma liste ou à une playlist', onTap: () => collectionSheet(context, fav)),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 2),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  if (it.kind == Kind.vod && old != null) _ActIcon(icon: CupertinoIcons.gobackward, label: 'Depuis le début', onTap: () => _play(vodPath(), it.title, prog: Prog(kind: 'vod', id: cur.id, ext: cur.ext, name: it.title, icon: it.icon))),
                  if (fi != null && fi.trailer.isNotEmpty) _ActIcon(icon: CupertinoIcons.film, label: 'Bande-annonce', onTap: () => _trailer(fi.trailer)),
                  if (it.kind == Kind.vod)
                    ValueListenableBuilder<Map<String, double>>(
                      valueListenable: Downloads.progress,
                      builder: (_, m, __) {
                        final key = '${Store.pre}vod:${cur.id}';
                        final dl = Downloads.get(key), pr = m[key];
                        if (pr != null) return _ActIcon(icon: CupertinoIcons.xmark_circle, label: '${(pr * 100).round()} % · annuler', onTap: () => Downloads.cancel(key));
                        if (dl != null) {
                          return _ActIcon(icon: CupertinoIcons.checkmark_alt_circle_fill, label: 'Hors ligne', onTap: () async {
                            await Downloads.remove(key);
                            if (mounted) setState(() {});
                          });
                        }
                        return _ActIcon(icon: CupertinoIcons.arrow_down_circle, label: 'Télécharger', onTap: () => Downloads.start(key, widget.x.vodUrl(cur.id, cur.ext), it.title, it.icon, cur.ext));
                      },
                    ),
                ]),
              ),
            ],
            if (fi != null && fi.tagline.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Text(fi.tagline, style: T(15, w: 600, color: kMut).copyWith(fontStyle: FontStyle.italic))),
            if (det.genre.isNotEmpty || (fi != null && fi.genres.isNotEmpty)) Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 0), child: Text(fi != null && fi.genres.isNotEmpty ? fi.genres.join(', ') : det.genre, style: T(14, w: 600, color: kMut))),
            if (!wide && (det.plot.isNotEmpty || (fi != null && fi.plot.isNotEmpty)))
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: GestureDetector(
                  onTap: () => setState(() => _more = !_more),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fi != null && fi.plot.isNotEmpty ? fi.plot : det.plot, maxLines: _more ? null : 3, overflow: _more ? TextOverflow.visible : TextOverflow.ellipsis, style: T(15.5, w: 400, color: const Color(0xFFDFE5F0), h: 1.45)),
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(_more ? 'Moins' : 'Plus', style: T(14, w: 650, color: kAccent))),
                  ]),
                ),
              ),
            if (det.cast.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Text('${L.en ? 'With' : 'Avec'} ${det.cast}', maxLines: 3, overflow: TextOverflow.ellipsis, style: T(13.5, w: 400, color: kMut, h: 1.4))),
            if (det.director.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: Text('${L.en ? 'By' : 'De'} ${det.director}', style: T(13.5, w: 400, color: kMut))),
            if (vs.length > 1 && !wide) Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: _verButton(vs, cur)),
            if (error != null) Padding(padding: const EdgeInsets.all(20), child: Text(error!, style: T(14, color: const Color(0xFFFF6B7A)))),
            if (it.kind == Kind.series && eps.isNotEmpty) ...[
              const SectionTitle('Épisodes'),
              Chips(labels: [for (final s in seasons) 'Saison $s'], selected: seasons.indexOf(season).clamp(0, seasons.length - 1), onSelect: (v) => setState(() => season = seasons[v])),
              for (final e in eps.where((e) => e.season == season))
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: Device.tv ? 40 : 0),
                  child: FocusCard(
                  radius: 14,
                  focusScale: Device.tv ? 1.0 : 1.06,
                  onTap: () => _playEp(e),
                  child: Container(
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x14FFFFFF), width: 0.6))),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(children: [
                      SizedBox(width: 34, child: Text('${e.number}', style: T(20, w: 750, color: kMut))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.title.isEmpty ? 'Épisode ${e.number}' : e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(Device.tv ? 19 : 15.5, w: 600))),
                      const Ic('play', size: 20, color: kMut),
                    ]),
                  ),
                ),
                ),
            ],
            if (fi != null && fi.cast.isNotEmpty)
              Rail(
                title: 'Casting',
                height: 170,
                count: fi.cast.length,
                moreLabel: '',
                builder: (_, i) => SizedBox(
                  width: 92,
                  child: FocusCard(
                    radius: 16,
                    onTap: () => Navigator.push(context, softRoute((_) => PersonScreen(name: fi.cast[i].name, role: fi.cast[i].role, photo: fi.cast[i].photo, id: fi.cast[i].id, onOpen: widget.onOpen))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(children: [
                        ClipOval(child: SizedBox(width: 76, height: 76, child: fi.cast[i].photo.isEmpty ? Container(color: kBg3) : netImage(tmImg(fi.cast[i].photo, 'w185'), ''))),
                        const SizedBox(height: 8),
                        Text(fi.cast[i].name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(12.5, w: 650, h: 1.2)),
                        Text(fi.cast[i].role, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(11.5, color: kMut)),
                      ]),
                    ),
                  ),
                ),
              ),
            if (saga.isNotEmpty) Rail(title: fi!.sagaName.isEmpty ? 'Saga' : fi.sagaName, height: _posterH(118), count: saga.length, moreLabel: '', builder: (_, i) => Poster(item: saga[i], width: 118, onTap: () => widget.onOpen(saga[i]))),
            if (sim.isNotEmpty) Rail(title: 'Plus comme ça', height: _posterH(118), count: sim.length, moreLabel: '', builder: (_, i) => Poster(item: sim[i], width: 118, onTap: () => widget.onOpen(sim[i]))),
            if (same.isNotEmpty)
              Rail(
                title: 'Dans le même rayon',
                height: _posterH(118),
                count: same.length,
                moreLabel: '',
                builder: (_, i) => Poster(item: same[i], width: 118, onTap: () => widget.onOpen(same[i])),
              ),
            const SizedBox(height: 60),
          ],
        ]),
        if (!Device.tv)      // télé : la touche Retour suffit
        Positioned(
          top: top + 8,
          left: 16,
          right: 16,
          child: Row(children: [RoundButton(size: 44, label: 'Retour', onTap: () => Navigator.pop(context), child: const Ic('back', size: 20))]),
        ),
      ]),
    );
  }
}

/// ---------- lecteur (libmpv : MKV, AC3, HEVC… sans conversion) ----------
class PlayerScreen extends StatefulWidget {
  final String url, title;
  final Prog? prog;
  final List<(String, String)> alts;          // qualités d'une chaîne (libellé, adresse)
  final List<(String, String, Prog)> next;    // épisodes suivants (titre, adresse, suivi)
  final List<Zap> zap;                        // chaînes voisines (zapping haut / bas)
  final int zapAt;
  final Xtream? x;                            // pour le rattrapage (adresse des programmes passés)
  final Future<Fiche?>? tmdb;                 // identifiant TMDB : sert à retrouver intro / récap / générique
  final String? audioUrl;                     // bande-annonce : son à part de l'image
  final bool debug;
  const PlayerScreen({super.key, this.audioUrl, this.debug = false, required this.url, required this.title, this.prog, this.alts = const [], this.next = const [], this.zap = const [], this.zapAt = 0, this.x, this.tmdb});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

/// une chaîne du zapping : nom, identifiant du guide, qualités (libellé, adresse)
class Zap {
  final String name, epg;
  final List<(String, String)> alts;
  final int sid, arch;       // flux avec rattrapage : identifiant et jours d'archive (0 = aucun)
  final String key;          // clé de la chaîne (MinouFlix Connect)
  const Zap(this.name, this.epg, this.alts, {this.sid = 0, this.arch = 0, this.key = ''});
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const _pip = MethodChannel('minou/pip');
  late final Player player = Player(configuration: PlayerConfiguration(bufferSize: Perf.lite ? 16 * 1024 * 1024 : 32 * 1024 * 1024, logLevel: MPVLogLevel.warn));
  late final VideoController controller = Device.tv && Store.flag('vo_embed', true) ? VideoController(player, configuration: const VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec')) : VideoController(player);
  Timer? _t;
  int _alt = 0;
  int _hint = 0;
  late List<(String, String)> _alts = widget.alts;
  late int _zi = widget.zapAt;
  String _epgLine = '';
  Timer? _banner;
  StreamSubscription<Tracks>? _tr;
  StreamSubscription<bool>? _playSub;
  bool _trSet = false;
  double _rate = 1.0;
  static const _fpsCh = MethodChannel('minou/fps');
  final FocusNode _first = FocusNode(debugLabel: 'retour');
  bool _showTitle = true;
  late Prog? _prog = widget.prog;
  late String _title = widget.title;
  int _n = 0;
  StreamSubscription<bool>? _done;
  StreamSubscription<VideoParams>? _vp;
  StreamSubscription<Duration>? _posSub;
  final FocusNode _skipNode = FocusNode(debugLabel: 'passer');
  List<(String, int, int?)> _segs = [];      // intro / récap / générique (TheIntroDB) : type, début, fin en ms
  String? _skipLabel;
  int _skipTo = -1;                          // -1 : épisode suivant
  int _fpsFor = 0;

  // fiabilité : message lisible au lieu d'un écran noir, une reconnexion silencieuse du direct
  StreamSubscription<String>? _errSub;
  StreamSubscription<PlayerLog>? _logSub;
  final List<String> _mpvLog = [];      // derniers messages du lecteur, versés au journal quand la lecture échoue
  Xtream? get _xt => widget.x ?? Epg.src;
  StreamSubscription<bool>? _endSub;
  Timer? _watch;
  String? _fail;
  String _cur = '';
  int _silent = 0;
  DateTime _openedAt = DateTime.now();
  final FocusNode _retryNode = FocusNode(debugLabel: 'réessayer');
  final FocusNode _main = FocusNode(debugLabel: 'lecteur', skipTraversal: true);     // zapping haut / bas, retrouvé après « Réessayer »
  bool get _live => _alts.isNotEmpty || _cur.contains('/live/');

  /// intro, récap et générique de l'épisode (base communautaire TheIntroDB, par identifiant TMDB) ; rien si inconnu
  Future<void> _loadSegs() async {
    _segs = [];
    _setSkip(null, -1);
    final t = widget.tmdb;
    if (t == null || _live) return;
    try {
      final f = await t.timeout(const Duration(seconds: 8));
      final id = f?.tmdbId ?? 0;
      if (id == 0 || !mounted) return;
      final p = _prog;
      final q = <String, String>{'tmdb_id': '$id'};
      if (p != null && p.kind == 'ep') {
        final m = RegExp(r'^S(\d+) · É(\d+)').firstMatch(p.name);
        if (m == null) return;
        q['season'] = m.group(1)!;
        q['episode'] = m.group(2)!;
      }
      final r = await http.get(Uri.https('api.theintrodb.org', '/v4/media', q)).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200 || !mounted) return;
      final d = jsonDecode(r.body);
      if (d is! Map) return;
      final out = <(String, int, int?)>[];
      for (final k in const ['recap', 'intro', 'credits']) {
        for (final s in (d[k] as List? ?? const [])) {
          if (s is Map && s['start_ms'] is num) out.add((k, (s['start_ms'] as num).toInt(), (s['end_ms'] as num?)?.toInt()));
        }
      }
      _segs = out;
    } catch (_) {}
  }

  void _setSkip(String? label, int to) {
    if (label == _skipLabel && to == _skipTo) return;
    setState(() {
      _skipLabel = label;
      _skipTo = to;
    });
    if (label != null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted && _skipLabel != null ? _skipNode.requestFocus() : null);
  }

  void _onPos(Duration p) {
    if (_segs.isEmpty || !mounted) return;
    final ms = p.inMilliseconds;
    for (final s in _segs) {
      if (ms < s.$2 || (s.$3 != null && ms >= s.$3!)) continue;
      if (s.$1 == 'credits') {
        if (_n < widget.next.length) _setSkip('Épisode suivant', -1);
        return;
      }
      if (s.$3 == null) return;
      if (Store.flag('skipauto', false)) {
        player.seek(Duration(milliseconds: s.$3!));
        return;
      }
      _setSkip(s.$1 == 'recap' ? 'Passer le récap' : 'Passer l\'intro', s.$3!);
      return;
    }
    _setSkip(null, -1);
  }

  void _doSkip() {
    final to = _skipTo;
    _setSkip(null, -1);
    if (to < 0) {
      _playNext();
    } else {
      player.seek(Duration(milliseconds: to));
    }
    _main.requestFocus();
  }

  /// direct : garde ~10 min en mémoire pour pouvoir mettre en pause et revenir en arrière
  /// tampon réglable (Réglages › Lecture) : secondes d'avance gardées en mémoire, et d'attente après une coupure
  static int get bufSecs => (int.tryParse(Store.str('buf_s')) ?? 20).clamp(1, 90);

  Future<void> _bufferSecs(dynamic n) async {
    await n.setProperty('user-agent', kIptvUa);
    await n.setProperty('demuxer-readahead-secs', '$bufSecs');
    await n.setProperty('cache-secs', '$bufSecs');
    await n.setProperty('cache-pause-wait', '$bufSecs');
  }

  Future<void> _bufferVod() async {
    try {
      await _bufferSecs(player.platform as dynamic);
    } catch (_) {}
  }

  Future<void> _bufferLive() async {
    try {
      final dynamic n = player.platform;   // dynamic : la version web (contrôle visuel) n'a pas NativePlayer
      await n.setProperty('cache', 'yes');
      // télé : tampon borné en mémoire (un énorme tampon sature les boîtiers et fait saccader), reconnexion automatique du flux
      await n.setProperty('demuxer-max-bytes', Device.tv ? '32MiB' : (Perf.lite ? '48MiB' : '200MiB'));
      await n.setProperty('demuxer-max-back-bytes', Device.tv ? '16MiB' : (Perf.lite ? '40MiB' : '200MiB'));
      await _bufferSecs(n);
      await n.setProperty('network-timeout', '15');
      await n.setProperty('stream-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=4');
      final dec = Store.str('dec_live');      // décodage matériel par défaut (le logiciel sature les 4 petits cœurs) ; « sw » reste en option
      await n.setProperty('deinterlace', dec.contains('di') ? 'yes' : 'no');
      if (dec.contains('sw')) await n.setProperty('hwdec', 'no');
    } catch (_) {}
  }

  /// tampon réglable en lecture (même réglage que Réglages › Lecture), appliqué tout de suite
  Future<void> _bufMenu() async {
    const opts = [5, 10, 20, 30, 45, 60, 90];
    final cur = bufSecs;
    final v = await appSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.fromLTRB(28, 22, 28, 2), child: Align(alignment: Alignment.centerLeft, child: Text('Tampon de lecture', style: T(22, w: 750)))),
            Padding(padding: const EdgeInsets.fromLTRB(28, 0, 28, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Plus grand : lecture plus stable si la connexion est irrégulière, mais démarrage plus lent.', style: T(13, color: kMut, h: 1.35)))),
            for (final o in opts) ListTile(autofocus: o == opts.reduce((a, b) => (a - cur).abs() <= (b - cur).abs() ? a : b), leading: Icon(o == cur ? Icons.check_circle_rounded : Icons.circle_outlined), title: Text('$o s'), onTap: () => Navigator.pop(context, o)),
            const SizedBox(height: 10),
          ]),
        ),
      ));
    if (v == null || !mounted) return;
    await Store.setStr('buf_s', '$v');
    await (_live ? _bufferLive() : _bufferVod());
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${L.tr('Tampon de lecture')} : $v s')));
    }
  }

  /// menu « Plus d'options » : chaque action avec son nom (au lieu d'une rangée d'icônes sans légende)
  Future<void> _moreMenu() async {
    final items = <(IconData, String, VoidCallback)>[
      if (_live) (CupertinoIcons.gobackward_30, 'Reculer de 30 secondes', _back30),
      if (_live) (CupertinoIcons.dot_radiowaves_left_right, 'Revenir au direct', _goLive),
      if (!_live)
        (CupertinoIcons.speedometer, 'Vitesse de lecture : ×${_rate == _rate.roundToDouble() ? _rate.toInt() : _rate}', () {
          const r = [1.0, 1.25, 1.5, 2.0];
          _rate = r[(r.indexOf(_rate) + 1) % r.length];
          player.setRate(_rate);
          setState(() {});
        }),
      (CupertinoIcons.cloud_download, '${L.tr('Tampon de lecture')} : $bufSecs s', _bufMenu),
      (CupertinoIcons.chart_bar_alt_fill, _statsOn ? 'Masquer les statistiques' : 'Statistiques de lecture (réseau, tampon)', _statsToggle),
      if (!kIsWeb && Platform.isAndroid && Device.touch) (CupertinoIcons.rectangle_on_rectangle, 'Mini-fenêtre', () => _pip.invokeMethod('enter').catchError((_) {})),
    ];
    final i = await appSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          for (var k = 0; k < items.length; k++) ListTile(autofocus: k == 0, leading: Icon(items[k].$1), title: Text(items[k].$2), onTap: () => Navigator.pop(context, k)),
          const SizedBox(height: 8),
        ]),
      ));
    if (i != null && mounted) items[i].$3();
  }

  /// commandes d'un autre appareil : pause, ±30 s, arrêt
  void _remoteCtl() {
    final op = Connect.player.value.split(':').first;
    if (op == 'toggle') {
      player.playOrPause();
    } else if (op == 'back' || op == 'fwd') {
      final p = player.state.position + Duration(seconds: op == 'back' ? -30 : 30);
      player.seek(p < Duration.zero ? Duration.zero : p);
    } else if (op == 'stop') {
      Navigator.maybePop(context);
    }
  }

  /// « Continuer sur la télé » : la télé reprend ici, à la même seconde
  Future<void> _toTv() async {
    Map<String, dynamic>? cmd;
    final p = _prog;
    if (_live) {
      if (widget.zap.isNotEmpty && widget.zap[_zi].key.isNotEmpty) cmd = {'a': 'live', 'key': widget.zap[_zi].key};
    } else if (p != null) {
      cmd = Connect.playCmd(Prog(kind: p.kind, id: p.id, sid: p.sid, ext: p.ext, name: p.name, icon: p.icon, sname: p.sname, pos: player.state.position.inMilliseconds));
    }
    final ok = cmd != null && await Connect.send(cmd);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Envoyé sur la télé.' : 'Envoi impossible (même compte sur la télé, MinouFlix ouvert).')));
    if (ok) player.pause();
  }

  void _goLive() {
    _silent = 0;
    _open(_alts.isNotEmpty ? _alts[_alt].$2 : _cur);
  }

  void _seekBy(int sec) {
    final p = player.state.position + Duration(seconds: sec);
    final d = player.state.duration;
    player.seek(p < Duration.zero ? Duration.zero : (d > Duration.zero && p > d ? d : p));
    setState(() => _hintSec = sec);
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _hintSec = 0);
    });
  }

  int _hintSec = 0;      // dernier saut (télécommande / boutons) affiché au centre

  void _back30() {
    final p = player.state.position - const Duration(seconds: 30);
    player.seek(p < Duration.zero ? Duration.zero : p);
  }

  /// la télé s'adapte à la cadence de la vidéo (24 / 25 / 30 / 50 images par seconde) : plus de saccades
  Future<void> _matchFps() async {
    if (kIsWeb || !Platform.isAndroid || !Device.tv || !Store.flag('fpsmatch', false) || _fpsFor == _openedAt.millisecondsSinceEpoch) return;
    try {
      final v = await (player.platform as dynamic).getProperty('container-fps');
      final f = double.tryParse(v) ?? 0;
      if (f < 10 || f > 120) return;
      _fpsFor = _openedAt.millisecondsSinceEpoch;
      await _fpsCh.invokeMethod('set', f);
    } catch (_) {}
  }

  Timer? _apT, _soundT;

  /// 6 s après le départ : la lecture avance mais aucune sortie audio n'existe alors que le flux a du son → filtre retiré et sortie audio relancée
  void _soundCheck() {
    _soundT?.cancel();
    _soundT = Timer(const Duration(seconds: 6), () async {
      if (!mounted || _fail != null || !player.state.playing || player.state.position == Duration.zero) return;
      if (player.state.buffer <= player.state.position || player.state.duration == Duration.zero) return;      // rien ne arrive du serveur : ce n'est pas un problème de son
      try {
        final dynamic n = player.platform;
        final aid = '${await n.getProperty('aid')}';
        final out = '${await n.getProperty('audio-out-params/channels')}';
        if (out.isNotEmpty || aid.isEmpty || aid == 'no' || aid == 'false') return;      // le son sort, ou le flux n'en a pas
        Journal.add('Son : aucune sortie audio détectée (mode ${_mode}), filtre retiré et sortie relancée');
        _lastAf = '';
        await n.setProperty('af', '');
        await n.command(['ao-reload']);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Son relancé.')));
      } catch (_) {}
    });
  }

  /// ouvre un flux et surveille qu'il démarre (rien au bout de 15 s = échec)
  void _open(String url) {
    _cur = url;
    _soundCheck();
    _openedAt = DateTime.now();
    final t0 = _openedAt;
    player.stream.position.firstWhere((p) => p > Duration.zero).timeout(const Duration(seconds: 60)).then((_) => Journal.add('Lecture : démarrée en ${DateTime.now().difference(t0).inMilliseconds} ms (${_live ? 'direct' : 'film'}${(_prog?.pos ?? 0) > 20000 ? ', reprise' : ''})')).catchError((_) {});
    if (_fail != null) {
      setState(() => _fail = null);
      _main.requestFocus();
    }
    _watch?.cancel();
    _watch = Timer(const Duration(seconds: 15), () {
      if (!mounted || _fail != null) return;
      if (player.state.position == Duration.zero && player.state.duration == Duration.zero) _failed('Le flux ne démarre pas.');
    });
    if (widget.debug && _dbg == null) {
      _dbg = [
        player.stream.error.listen((e) => Journal.add('Bande-annonce : erreur du lecteur', e)),
      ];
    }
    // le filtre du mode son est posé AVANT l'ouverture du flux
    Future<void>.value().then((_) => _applyNight()).then((_) => player.open(Media(url))).then((_) async {
      final a = widget.audioUrl;
      if (a == null) return;
      try {
        await (player.platform as dynamic).command(['audio-add', a, 'select']);
      } catch (_) {}
    });
  }

  List<StreamSubscription>? _dbg;

  // direct : si une chaîne ne repart pas, on passe seul à une autre version (HD → SD, doublon…), puis on revient à la meilleure plus tard
  int _altTried = 0, _backMin = 3;
  bool _adjNote = false;
  Timer? _backT, _stableT, _noteT;

  void _adjNoteShow() {
    _noteT?.cancel();
    setState(() => _adjNote = true);
    _noteT = Timer(const Duration(seconds: 6), () => mounted ? setState(() => _adjNote = false) : null);
  }

  void _backSchedule() {
    _backT?.cancel();
    if (_alt == 0 || _alts.length < 2) return;
    _backT = Timer(Duration(minutes: _backMin), () {
      if (!mounted || _fail != null || _alt == 0) return;
      _backMin = (_backMin * 2).clamp(3, 24);      // si la meilleure version recoupe, on attend de plus en plus longtemps avant de réessayer
      _altTried = 0;
      _silent = 1;
      Journal.add('Direct : retour à la meilleure version');
      setState(() => _alt = 0);
      _open(_alts[0].$2);
      _stableCheck();
    });
  }

  /// 30 s de lecture sans incident : la panne est finie
  void _stableCheck() {
    _stableT?.cancel();
    _stableT = Timer(const Duration(seconds: 30), () {
      if (!mounted || _fail != null) return;
      _altTried = 0;
      _silent = 0;
      if (_alt == 0) _backMin = 3;
    });
  }

  void _manualAlt() {
    _backT?.cancel();
    _stableT?.cancel();
    _altTried = 0;
    _backMin = 3;
  }

  void _failed(String why) {
    if (!mounted || _fail != null) return;
    // direct : un nouvel essai silencieux (coupure passagère), puis le message ; de nouveau permis après 2 min de lecture
    final longRun = DateTime.now().difference(_openedAt) > const Duration(minutes: 2);
    if (_live && (_silent < 1 || longRun)) {
      _silent = 1;
      Journal.add('Direct : reconnexion automatique ($why)');
      _open(_cur);
      return;
    }
    _stableT?.cancel();
    if (_live && _alts.length > 1 && _altTried < _alts.length - 1) {
      _altTried++;
      final from = _alt;
      _alt = (_alt + 1) % _alts.length;
      Journal.add('Direct : bascule automatique vers une autre version ($why)');
      setState(() {});
      _adjNoteShow();
      _open(_alts[_alt].$2);
      _backSchedule();
      _stableCheck();
      if (from == _alt) _altTried = _alts.length;
      return;
    }
    Journal.add('Lecture impossible : $why');
    if (_mpvLog.isNotEmpty) Journal.add('Détail du lecteur', _mpvLog.join(' | '));
    setState(() => _fail = why);
    if (_oneScreen && !_kicked && Connect.canSend) unawaited(_takeOver());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fail != null) _retryNode.requestFocus();
    });
  }

  bool _kicked = false;
  int _uaTries = 0, _openFails = 0;

  /// source à un seul écran déjà utilisée : on demande avant de lire, puis l'autre appareil est arrêté (true = on lit)
  Future<bool> _askTakeOver() async {
    final x = _xt;
    final mx = x?.info['max'] ?? '';
    if (x == null || widget.audioUrl != null || !widget.url.startsWith('http') || (mx.isNotEmpty && mx != '1')) return true;      // seulement les sources à un écran (ou état pas encore connu)
    var busy = false;
    try {
      await x.refreshInfo().timeout(const Duration(seconds: 6));
    } catch (e) {
      busy = '$e'.contains('refuse la connexion');      // le fournisseur coupe même la simple vérification : l'abonnement est pris ailleurs
      if (!busy) return true;
    }
    if (!mounted) return true;
    if (!busy && (x.info['max'] != '1' || (int.tryParse(x.info['active'] ?? '') ?? 0) < 1)) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        backgroundColor: kBg2,
        title: Text('Attention', style: T(18, w: 700)),
        content: Text('Un autre appareil est en cours de lecture (ta source n\'autorise qu\'un écran à la fois). Veux-tu le remplacer et lire ici ?${!kIsWeb && Platform.isIOS ? ' (Si aucun autre appareil ne lit, désactive le Relais privé iCloud et tout VPN dans les Réglages de l\'iPhone.)' : ''}', style: T(15, color: kMut)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer'))],
      ),
    );
    if (go != true) return false;
    _kicked = true;
    if (Connect.canSend) {
      await Connect.kick();
      Journal.add('Source à un écran : demande d\'arrêt envoyée aux autres appareils');
      await Future<void>.delayed(const Duration(seconds: 4));
    }
    return true;
  }

  /// source à un seul écran : on demande à l'autre appareil de lâcher la source, puis on relance
  Future<void> _takeOver() async {
    _kicked = true;
    if (Connect.canSend) await Connect.kick();
    Journal.add('Source à un écran : demande d\'arrêt envoyée aux autres appareils');
    await Future<void>.delayed(const Duration(seconds: 4));
    if (mounted) _retryNow();
  }

  void _retryNow() {
    _uaTries = 0;
    _openFails = 0;
    _altTried = 0;
    _silent = 0;
    _open(_cur);
  }

  /// choix de la qualité du flux (télé : liste avec la qualité actuelle cochée)
  Future<void> _qualityMenu() async {
    final i = await appSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(28, 22, 28, 6), child: Align(alignment: Alignment.centerLeft, child: Text('Qualité du flux', style: T(22, w: 750)))),
          for (var k = 0; k < _alts.length; k++) ListTile(autofocus: k == _alt, leading: Icon(k == _alt ? Icons.check_circle_rounded : Icons.circle_outlined), title: Text(_alts[k].$1), onTap: () => Navigator.pop(context, k)),
          const SizedBox(height: 10),
        ]),
      ),
    );
    if (i == null || i == _alt || !mounted) return;
    setState(() => _alt = i);
    _manualAlt();
    _silent = 0;
    _open(_alts[i].$2);
  }

  void _otherQuality() {
    if (_alts.length < 2) return;
    _manualAlt();
    _silent = 0;
    setState(() => _alt = (_alt + 1) % _alts.length);
    _open(_alts[_alt].$2);
  }

  void _playNext() {
    if (_n >= widget.next.length || !mounted) return;
    _save();
    _nextT?.cancel();
    if (_nextIn > 0) _nextIn = 0;
    final nx = widget.next[_n++];
    try {
      (player.platform as dynamic).setProperty('start', 'none');      // le temps de reprise ne s'applique qu'au premier fichier
    } catch (_) {}
    _trSet = false;     // langues préférées appliquées aussi à l'épisode suivant
    setState(() {
      _prog = nx.$3;
      _title = nx.$1;
    });
    _open(nx.$2);
    unawaited(_loadSegs());
  }

  /// zapping : +1 chaîne suivante, -1 précédente
  void _zapBy(int d) {
    final z = widget.zap;
    if (z.length < 2) return;
    _zi = (_zi + d) % z.length;
    if (_zi < 0) _zi += z.length;
    final c = z[_zi];
    final e = c.epg.isEmpty ? null : Epg.now(c.epg);
    Epg.want(c.epg, [c.sid]).then((_) {
      final n = c.epg.isEmpty ? null : Epg.now(c.epg);
      if (mounted && _zi < z.length && identical(z[_zi], c) && n != null) setState(() => _epgLine = '${n.title} · encore ${n.leftMin} min');
    });
    _trSet = false;
    setState(() {
      _alts = c.alts;
      _alt = 0;
      _title = c.name;
      _showTitle = true;
      _epgLine = e == null ? '' : '${e.title} · encore ${e.leftMin} min';
    });
    _manualAlt();
    _silent = 0;
    _open(c.alts.first.$2);
    _banner?.cancel();
    _banner = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showTitle = false);
    });
  }

  /// piste audio que le lecteur sait décoder (pas Dolby TrueHD / MLP)
  bool _decodable(AudioTrack x) {
    final c = '${x.codec ?? ''} ${x.title ?? ''}'.toLowerCase();
    return !(c.contains('truehd') || c.contains('mlp'));
  }

  /// langues préférées retenues d'une fois sur l'autre
  void _applyPrefs(Tracks t) {
    if (_trSet) return;
    final a = t.audio.where((x) => x.id != 'auto' && x.id != 'no').toList();
    final s = t.subtitle.where((x) => x.id != 'auto' && x.id != 'no').toList();
    if (a.isEmpty && s.isEmpty) return;
    _trSet = true;
    final pa = Store.str('pref_aud'), ps = Store.str('pref_sub');
    // le lecteur embarqué n'a pas de décodeur Dolby TrueHD / MLP (pistes Atmos des films 4K) : choisie par défaut, une telle piste = film SANS SON
    // (journal : « Failed to initialize a decoder for codec 'truehd' »). On prend alors la meilleure piste lisible (même langue, sinon la première).
    final bad = a.where((x) => !_decodable(x)).toList(), ok = a.where(_decodable).toList();
    AudioTrack? pick;
    if (pa.isNotEmpty) pick = (ok.isNotEmpty ? ok : a).where((x) => L.trackIs(x.language, pa)).firstOrNull;
    if (pick == null && bad.isNotEmpty && ok.isNotEmpty) {
      pick = ok.where((x) => x.language == bad.first.language).firstOrNull ?? ok.first;
    }
    if (pick != null) {
      Journal.add('Son : piste choisie ${_lab(pick.language, pick.title, 0)} (${pick.codec ?? '?'})${bad.isNotEmpty ? ', pistes TrueHD ignorées' : ''}');
      player.setAudioTrack(pick);
    } else if (ok.isEmpty && bad.isNotEmpty && mounted) {
      Journal.add('Son : seules des pistes TrueHD, non lisibles par le lecteur');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ce film n\'a qu\'une piste Dolby TrueHD, que le lecteur ne sait pas lire : pas de son possible.')));
    }
    if (ps == 'no') {
      player.setSubtitleTrack(SubtitleTrack.no());
    } else if (ps.isNotEmpty) {
      final m = s.where((x) => L.trackIs(x.language, ps)).firstOrNull;
      if (m != null) player.setSubtitleTrack(m);
    }
  }

  /// fin d'épisode : le suivant démarre après 5 s, sauf si on annule
  int _nextIn = 0;
  Timer? _nextT;
  final _nextNode = FocusNode();

  /// fin d'épisode : compte à rebours visible (5 s) avant le suivant, annulable
  void _autoNext() {
    if (!mounted || _nextIn > 0) return;
    setState(() => _nextIn = 5);
    WidgetsBinding.instance.addPostFrameCallback((_) => mounted && _nextIn > 0 ? _nextNode.requestFocus() : null);
    _nextT = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_nextIn <= 1) {
        t.cancel();
        setState(() => _nextIn = 0);
        _playNext();
      } else {
        setState(() => _nextIn--);
      }
    });
  }

  void _cancelNext() {
    _nextT?.cancel();
    if (mounted && _nextIn > 0) setState(() => _nextIn = 0);
    _main.requestFocus();
  }

  /// sous-titres trouvés en ligne : liste, puis téléchargement et activation
  Future<void> _onlineSubs() async {
    final f = await widget.tmdb;
    final nums = RegExp(r'[Ss](\d{1,2})\s*[Ee](\d{1,3})').firstMatch(widget.title);
    final tv = widget.prog?.kind == 'ep';
    List<SubHit> hits;
    try {
      hits = await Subs.search(
        title: f?.title.isNotEmpty == true ? f!.title : widget.title,
        tmdbId: f?.tmdbId ?? 0,
        lang: L.lang.toUpperCase(),
        tv: tv,
        season: nums == null ? 0 : int.parse(nums.group(1)!),
        episode: nums == null ? 0 : int.parse(nums.group(2)!),
      );
    } catch (e) {
      Journal.add('Sous-titres en ligne', e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recherche impossible pour le moment.')));
      return;
    }
    if (!mounted) return;
    if (hits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucun sous-titre trouvé pour ce titre.')));
      return;
    }
    final h = await appSheet<SubHit>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), children: [
          Text('Sous-titres trouvés', style: T(18, w: 750)),
          for (final x in hits.take(12))
            ListTile(contentPadding: EdgeInsets.zero, title: Text(x.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(14.5, w: 600)), subtitle: Text(x.lang), onTap: () => Navigator.pop(context, x)),
        ]),
      ),
    );
    if (h == null || !mounted) return;
    try {
      final txt = await Subs.fetch(h);
      if (txt == null) throw Exception('fichier introuvable');
      await player.setSubtitleTrack(SubtitleTrack.data(txt, title: h.name, language: h.lang.toLowerCase()));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sous-titres chargés.')));
    } catch (e) {
      Journal.add('Sous-titres en ligne', e);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Téléchargement impossible.')));
    }
  }

  double _aDelay = 0;
  StreamSubscription? _ap;
  int _lastCh = 2;
  String? _lastAf;

  /// mode de son : off · cinema · night · voice (un seul à la fois, par profil ; les anciens réglages nuit / dialogues sont repris)
  String get _mode {
    final m = Store.str('snd_mode');
    if (m.isNotEmpty) return m;
    return Store.flag('snd_voice', false) ? 'voice' : (Store.flag('snd_night', false) ? 'night' : 'off');
  }

  static String _modeName(String m) => const {'off': 'Standard', 'cinema': 'Cinéma', 'night': 'Nuit', 'voice': 'Dialogues renforcés'}[m] ?? 'Standard';

  /// filtres de chaque mode. Le lecteur embarqué (libmpv Android et iOS) est compilé SANS la plupart des filtres audio de ffmpeg
  /// (--disable-filters, seuls « equalizer » et « overlay » restent) : pan, bass, treble, highpass, acompressor, alimiter n'existent pas et
  /// faisaient échouer toute la chaîne (« Audio filter initialized failed ») = plus de son. On n'utilise donc que des « equalizer » (cloche paramétrique),
  /// qui marchent quel que soit le nombre de voies.
  /// · Cinéma : graves et aigus un peu plus présents
  /// · Nuit : graves et explosions nettement atténués (pas de compresseur de dynamique disponible)
  /// · Dialogues : grave coupé, présence de la voix (1,5–4 kHz) poussée
  String _filters(String mode, int ch) {
    String eq(int f, double w, double g) => 'equalizer=f=$f:t=q:w=$w:g=$g';
    switch (mode) {
      case 'cinema':
        return [eq(70, 0.8, 4), eq(140, 1, 1.5), eq(7500, 0.6, 3)].join(',');
      case 'night':
        return [eq(45, 0.7, -10), eq(90, 0.8, -7), eq(180, 1, -3), eq(6000, 0.8, -1.5)].join(',');
      case 'voice':
        return [eq(60, 0.7, -8), eq(120, 0.8, -4), eq(250, 0.7, -3), eq(1800, 0.8, 5), eq(3200, 0.8, 4)].join(',');
    }
    return '';
  }

  /// vrai si le lecteur a bien pris le filtre (ou s'il n'y en a pas)
  Future<bool> _applyNight() async {
    try {
      final dynamic n = player.platform;
      final f = _filters(_mode, 2);
      final af = f.isEmpty ? '' : 'lavfi=[$f]';
      if (af == _lastAf) return true;      // identique : on ne réinitialise pas la chaîne audio (cela peut perturber la position)
      _lastAf = af;
      await n.setProperty('af', af);
      return f.isEmpty || '${await n.getProperty('af')}'.contains('lavfi');
    } catch (_) {
      return false;
    }
  }

  Future<void> _setMode(String m, void Function(void Function()) set) async {
    await Store.setStr('snd_mode', m);
    final ok = await _applyNight();
    _soundCheck();
    set(() {});
    if (!ok && m != 'off' && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filtre audio non pris en charge par le lecteur sur cet appareil.')));
  }

  bool _syncMode = false;
  Timer? _syncT;
  DateTime _syncLast = DateTime(2000);
  String _syncRead = '';

  Future<void> _setDelay(double v) async {
    _aDelay = double.parse(v.clamp(-5.0, 5.0).toStringAsFixed(2));
    Store.setStr('adelay', '$_aDelay');      // le calage reste pour tous les films suivants (même appareil)
    try {
      final dynamic n = player.platform;
      await n.setProperty('audio-delay', '$_aDelay');
      _syncRead = '${await n.getProperty('audio-delay')}';
    } catch (_) {}
    if (mounted) setState(() {});
  }

  /// calage du son : ← son plus tôt, → son plus tard (pas de 50 ms), OK ferme ; se ferme seul après 6 s
  void _syncOpen() {
    setState(() => _syncMode = true);
    _syncTick();
  }

  void _syncTick() {
    _syncT?.cancel();
    _syncT = Timer(const Duration(seconds: 6), _syncClose);
  }

  void _syncClose() {
    _syncT?.cancel();
    if (mounted && _syncMode) setState(() => _syncMode = false);
    if (mounted) _main.requestFocus();
  }

  void _syncStep(int dir, {bool repeat = false}) {
    final n = DateTime.now();
    if (repeat && n.difference(_syncLast).inMilliseconds < 140) return;
    _syncLast = n;
    _setDelay(_aDelay + dir * 0.05);
    _syncTick();
  }

  String get _syncTxt => '${_aDelay > 0 ? '+' : ''}${(_aDelay * 1000).round()} ms';

  String _lab(String? lang, String? title, int i) {
    final l = [if (lang != null && lang.isNotEmpty) lang.toUpperCase(), if (title != null && title.isNotEmpty) title].join(' · ');
    return l.isEmpty ? 'Piste ${i + 1}' : l;
  }

  List<AudioTrack> get _aTracks => player.state.tracks.audio.where((x) => x.id != 'auto' && x.id != 'no').toList();
  List<SubtitleTrack> get _sTracks => player.state.tracks.subtitle.where((x) => x.id != 'auto' && x.id != 'no').toList();

  /// menu Son : quatre entrées, chacune ouvre son sous-menu
  void _tracks() {
    final a = _aTracks, s = _sTracks;
    final ca = player.state.track.audio, cs = player.state.track.subtitle;
    final audioNow = a.isEmpty ? 'Une seule piste' : _lab(ca.language, ca.title, a.indexWhere((x) => x.id == ca.id).clamp(0, 99));
    final subNow = cs.id == 'no' ? 'Aucun' : (s.isEmpty ? 'Aucun' : _lab(cs.language, cs.title, s.indexWhere((x) => x.id == cs.id).clamp(0, 99)));
    Widget row(IconData ic, String title, String value, VoidCallback go) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(ic),
          title: Text(title, style: T(16, w: 650)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 170), child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(14, color: kMut))),
            const Icon(Icons.chevron_right_rounded, color: kMut),
          ]),
          onTap: () {
            Navigator.pop(context);
            go();
          },
        );
    appSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), children: [
          Text('Son', style: T(18, w: 750)),
          const SizedBox(height: 6),
          row(CupertinoIcons.speaker_2_fill, 'Audio', audioNow, _audioMenu),
          row(CupertinoIcons.captions_bubble_fill, 'Sous-titres', subNow, _subMenu),
          row(CupertinoIcons.timer, 'Synchro audio', _syncTxt, _syncOpen),
          row(CupertinoIcons.slider_horizontal_3, 'Mode son', _modeName(_mode), _modeMenu),
        ]),
      ));
  }

  void _audioMenu() {
    final a = _aTracks;
    final ca = player.state.track.audio;
    appSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), children: [
          Text('Audio', style: T(18, w: 750)),
          if (a.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('Une seule piste', style: T(14, color: kMut))),
          for (var i = 0; i < a.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_lab(a[i].language, a[i].title, i) + (a[i].id == ca.id ? '  ✓' : ''), style: T(15.5, w: 600)),
              onTap: () {
                player.setAudioTrack(a[i]);
                Store.setStr('pref_aud', (a[i].language ?? '').toLowerCase());
                Navigator.pop(context);
              },
            ),
        ]),
      ));
  }

  void _subMenu() {
    final s = _sTracks;
    final cs = player.state.track.subtitle;
    appSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), children: [
          Text('Sous-titres', style: T(18, w: 750)),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Aucun${cs.id == 'no' ? '  ✓' : ''}', style: T(15.5, w: 600)),
            onTap: () {
              player.setSubtitleTrack(SubtitleTrack.no());
              Store.setStr('pref_sub', 'no');
              Navigator.pop(context);
            },
          ),
          for (var i = 0; i < s.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_lab(s[i].language, s[i].title, i) + (s[i].id == cs.id ? '  ✓' : ''), style: T(15.5, w: 600)),
              onTap: () {
                player.setSubtitleTrack(s[i]);
                Store.setStr('pref_sub', (s[i].language ?? '').toLowerCase());
                Navigator.pop(context);
              },
            ),
          if (Subs.available && widget.zap.isEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(CupertinoIcons.search, color: kAccent),
              title: Text('Chercher des sous-titres en ligne', style: T(15.5, w: 600, color: kAccent)),
              onTap: () {
                Navigator.pop(context);
                _onlineSubs();
              },
            ),
        ]),
      ));
  }

  void _modeMenu() {
    appSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: StatefulBuilder(
          builder: (_, set) => ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), children: [
            Text('Mode son', style: T(18, w: 750)),
            const SizedBox(height: 4),
            for (final (id, name, sub) in const [
              ('off', 'Standard', 'Son d\'origine, sans aucun traitement.'),
              ('cinema', 'Mode Cinéma', 'Graves et aigus plus présents. Pour un film à volume normal.'),
              ('night', 'Mode nuit', 'Graves et explosions nettement atténués. Pour regarder à bas volume sans déranger.'),
              ('voice', 'Dialogues renforcés', 'Voix plus nettes (grave coupé, présence de la voix poussée). Quand les dialogues sont difficiles à comprendre.'),
            ])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(name, style: T(15.5, w: 650)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: T(12.5, color: kMut, h: 1.35))),
                trailing: _mode == id ? const Icon(Icons.check_rounded, color: kAccent) : null,
                onTap: () => _setMode(id, set),
              ),
          ]),
        ),
      ));
  }

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showTitle = false);
    });
    if (!kIsWeb && Platform.isAndroid && Device.touch) _pip.invokeMethod('arm', true).catchError((_) {});
    _tr = player.stream.tracks.listen(_applyPrefs);
    _playSub = player.stream.playing.listen((_) {
      if (mounted && _tvUi) setState(() {});
    });
    if (widget.zap.isNotEmpty) {
      final e = widget.zap[_zi].epg.isEmpty ? null : Epg.now(widget.zap[_zi].epg);
      if (e != null) _epgLine = '${e.title} · encore ${e.leftMin} min';
      final c0 = widget.zap[_zi];
      Epg.want(c0.epg, [c0.sid]).then((_) {
        final n = c0.epg.isEmpty ? null : Epg.now(c0.epg);
        if (mounted && n != null) setState(() => _epgLine = '${n.title} · encore ${n.leftMin} min');
      });
    }
    _logSub = player.stream.log.listen((l) {
      _mpvLog.add('${l.prefix}: ${l.text.trim()}');
      if (_mpvLog.length > 8) _mpvLog.removeAt(0);
    });
    _errSub = player.stream.error.listen((e) {
      Journal.add('Lecteur', e);
      if (e.contains('Failed to open') && _openFails < 3 && widget.audioUrl == null && !widget.debug) {
        // le serveur refuse ou coupe : on réessaie seul (autre identité de lecteur IPTV, puis pauses plus longues pour laisser le serveur libérer l'ancienne connexion)
        _openFails++;
        if (_uaTries < kIptvUas.length - 1) {
          _uaTries++;
          uaNext();
        }
        Future<void>.delayed(Duration(seconds: _openFails <= 1 ? 1 : 5), () async {
          if (!mounted || _fail != null) return;
          try {
            await (player.platform as dynamic).setProperty('user-agent', kIptvUa);
          } catch (_) {}
          if (mounted) _open(_cur);
        });
        return;
      }
      if (e.contains('Audio filter') && _lastAf != null && _lastAf!.isNotEmpty) {
        // chaîne audio refusée par le lecteur : sans ce retrait, plus aucun son
        _lastAf = '';
        (player.platform as dynamic).setProperty('af', '');
        Store.setStr('snd_mode', 'off');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.tr('Filtre audio non pris en charge par le lecteur sur cet appareil.'))));
      }
      // erreur de décodeur audio (piste TrueHD par défaut, changée aussitôt) ou de filtre : l'image continue, ce n'est pas une coupure du flux
      if (e.contains('decoder for codec') || e.contains('Audio filter')) return;
      // certaines erreurs ne sont pas bloquantes : échec seulement si la lecture avait démarré et n'avance plus
      // (au démarrage, c'est la surveillance des 15 s qui tranche)
      final at = player.state.position;
      Timer(const Duration(seconds: 4), () {
        // pas d'échec si le lecteur est simplement en train de charger (reprise au milieu d'un film 4K : le tampon se remplit)
        if (mounted && at > Duration.zero && player.state.position == at && !player.state.buffering) _failed('Le flux a été interrompu.');
      });
    });
    _endSub = player.stream.completed.listen((c) {
      if (c && _live) _failed('Le direct s\'est interrompu.');     // un direct ne « finit » pas : c'est une coupure
    });
    _posSub = player.stream.position.distinct((a, b) => a.inSeconds == b.inSeconds).listen(_onPos);
    Connect.inPlayer = true;
    Connect.player.addListener(_remoteCtl);
    Connect.watchKick(DateTime.now(), () {
      if (!mounted) return;
      Journal.add('Lecture arrêtée : un autre appareil a repris la source');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lecture reprise sur un autre appareil.')));
      Navigator.maybePop(context);
    });
    unawaited(_loadSegs());
    _vp = player.stream.videoParams.listen((_) => _matchFps());
    _aDelay = double.tryParse(Store.str('adelay')) ?? 0;
    final startMs = _prog?.pos ?? 0;
    (_live ? _bufferLive() : _bufferVod()).whenComplete(() async {      // réglages du lecteur posés AVANT l'ouverture du flux
      if (startMs > 20000 && !_live) {
        try {
          await (player.platform as dynamic).setProperty('start', '${startMs / 1000}');      // le flux démarre directement au temps enregistré (un déplacement demandé après coup était parfois ignoré)
        } catch (_) {}
      }
      if (!_live) {
        // piste audio de départ dans ta langue (évite de démarrer sur la piste Atmos / TrueHD en version originale, que le lecteur ne sait pas lire)
        const codes = {'fr': 'fre,fra,fr', 'en': 'eng,en', 'es': 'spa,es', 'de': 'ger,deu,de', 'pt': 'por,pt'};
        final pref = Store.str('pref_aud').isNotEmpty ? Store.str('pref_aud') : L.lang;
        try {
          await (player.platform as dynamic).setProperty('alang', codes[pref] ?? pref);
        } catch (_) {}
      }
      if (_aDelay != 0) {
        try {
          await (player.platform as dynamic).setProperty('audio-delay', '$_aDelay');
        } catch (_) {}
      }
      if (!mounted) return;
      if (!await _askTakeOver()) {
        if (mounted) Navigator.maybePop(context);
        return;
      }
      if (mounted) _open(widget.url);
    });
    _enterFull();
    if (widget.next.isNotEmpty && Store.flag('autonext')) _done = player.stream.completed.listen((c) { if (c) _autoNext(); });
    final p = _prog;
    if (p != null) {
      if (p.pos > 20000) {
        _resumePending = true;
        unawaited(_resumeAt(p.pos));
      }
      _t = Timer.periodic(const Duration(seconds: 10), (_) => _save());
    }
  }

  bool _resumePending = false;

  /// iPhone, iPad, téléphone Android : le lecteur démarre directement en plein écran (barre d'état masquée, téléphone en paysage)
  void _enterFull() {
    if (kIsWeb || Device.tv || !(Platform.isIOS || Platform.isAndroid)) return;
    _full = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final v = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (v != null && v.physicalSize.shortestSide / v.devicePixelRatio < 600) {
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
  }

  bool _full = false;

  void _leaveFull() {
    if (!_full) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  // ---------- statistiques du lecteur (réseau, tampon, décodage) ----------
  bool _statsOn = false;
  Timer? _statsT;
  Map<String, String> _st = const {};
  int _bufEvents = 0;
  StreamSubscription<bool>? _bufSub;

  void _statsToggle() {
    setState(() => _statsOn = !_statsOn);
    _statsT?.cancel();
    if (!_statsOn) return;
    _bufSub ??= player.stream.buffering.listen((b) {
      if (b) _bufEvents++;
    });
    _statsPoll();
    _statsT = Timer.periodic(const Duration(seconds: 1), (_) => _statsPoll());
  }

  Future<void> _statsPoll() async {
    final dynamic n = player.platform;
    Future<String> g(String k) async {
      try {
        return '${await n.getProperty(k)}';
      } catch (_) {
        return '';
      }
    }

    String rate(String bits, {bool bytes = false}) {
      final v = double.tryParse(bits);
      if (v == null || v <= 0) return '–';
      final mbit = (bytes ? v * 8 : v) / 1e6;
      return mbit >= 1 ? '${mbit.toStringAsFixed(1)} Mb/s' : '${(mbit * 1000).round()} kb/s';
    }

    final st = player.state;
    final ahead = (st.buffer - st.position).inSeconds.clamp(0, 99999);
    final m = <String, String>{
      'Image': '${st.width ?? 0}×${st.height ?? 0} · ${(await g('video-codec')).split(' ').first}',
      'Débit vidéo': rate(await g('video-bitrate')),
      'Débit audio': rate(await g('audio-bitrate')),
      'Réseau (lecture)': rate(await g('cache-speed'), bytes: true),
      'Tampon': '$ahead s${st.buffering ? ' · chargement…' : ''}',
      'Coupures (tampon vide)': '$_bufEvents',
      'Images perdues': '${await g('decoder-frame-drop-count')} décodeur · ${await g('frame-drop-count')} affichage',
      'Cadence': '${(double.tryParse(await g('estimated-vf-fps')) ?? 0).toStringAsFixed(1)} i/s',
      'Décalage son/image': '${(((double.tryParse(await g('avsync')) ?? 0) * 1000).round())} ms',
      'Décodage': (await g('hwdec-current')).isEmpty ? '–' : await g('hwdec-current'),
    };
    if (mounted && _statsOn) setState(() => _st = m);
  }

  Widget _statsPanel() => Positioned(
        top: MediaQuery.paddingOf(context).top + 62,
        left: MediaQuery.paddingOf(context).left + 14,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Statistiques', style: T(13, w: 750, color: kAccent)),
              const SizedBox(height: 4),
              if (_st.isEmpty) Text('Mesure en cours…', style: T(12.5, color: kMut)),
              for (final e in _st.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${e.key} : ${e.value}', style: T(12.5, w: 500, color: Colors.white)),
                ),
            ]),
          ),
        ),
      );

  /// reprise : on va au temps enregistré, puis on vérifie (le lecteur peut ignorer un déplacement demandé trop tôt) ; jusqu'à 4 essais
  Future<void> _resumeAt(int ms) async {
    try {
      Journal.add('Reprise : départ demandé à ${ms ~/ 1000} s');
      await player.stream.duration.firstWhere((d) => d > Duration.zero);
      Journal.add('Reprise : durée connue, position ${player.state.position.inSeconds} s');
      // changer de piste audio (langue préférée, piste TrueHD illisible) relance la lecture à la position courante et annulait la reprise :
      // on attend donc que les pistes soient posées, puis on vérifie la position
      for (var w = 0; w < 25 && !_trSet && mounted; w++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await Future<void>.delayed(const Duration(milliseconds: 800));
      // la position annoncée au chargement peut être celle demandée (« start ») alors que le flux repart de zéro juste après :
      // on surveille ~25 s et on ne conclut qu'après 3 s consécutives au bon temps ET lecture qui avance
      var good = 0, seeks = 0, lastSeek = DateTime.fromMillisecondsSinceEpoch(0);
      Duration? first;
      for (var w = 0; w < 50 && mounted; w++) {
        final pos = player.state.position;
        if (pos.inMilliseconds > ms + 90000) break;      // déplacé à la main plus loin : on ne touche à rien
        if ((pos.inMilliseconds - ms).abs() < 15000) {
          first ??= pos;
          good++;
          if (good >= 6 && pos - first >= const Duration(seconds: 1)) {
            Journal.add('Reprise : position ${pos.inSeconds} s, lecture confirmée au bon temps');
            break;
          }
        } else {
          good = 0;
          first = null;
          if (seeks < 5 && DateTime.now().difference(lastSeek) > const Duration(milliseconds: 2500) && !player.state.buffering) {
            seeks++;
            lastSeek = DateTime.now();
            Journal.add('Reprise : le lecteur est à ${pos.inSeconds} s au lieu de ${ms ~/ 1000} s, déplacement (essai $seeks)');
            await player.seek(Duration(milliseconds: ms));
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } catch (_) {}
    _resumePending = false;
  }

  void _save() {
    final p = _prog;
    if (p == null || _resumePending) return;      // pas d'enregistrement tant que la reprise n'a pas eu lieu (sinon le début écraserait le temps gardé)
    final pos = player.state.position.inMilliseconds, dur = player.state.duration.inMilliseconds;
    if (pos > 20000) {
      p.pos = pos;
      p.dur = dur;
      p.t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      p.hidden = false;
      Store.saveProg(p);
      Trakt.watched(p);
    }
  }

  @override
  void dispose() {
    _vp?.cancel();
    _posSub?.cancel();
    Connect.inPlayer = false;
    Connect.player.removeListener(_remoteCtl);
    Connect.unwatchKick();
    _nextT?.cancel();
    _backT?.cancel();
    _stableT?.cancel();
    _noteT?.cancel();
    _syncT?.cancel();
    _statsT?.cancel();
    _apT?.cancel();
    _soundT?.cancel();
    _bufSub?.cancel();
    _leaveFull();
    _ap?.cancel();
    _nextNode.dispose();
    _skipNode.dispose();
    if (!kIsWeb && Platform.isAndroid && Device.tv && _fpsFor != 0) _fpsCh.invokeMethod('set', 0.0).catchError((_) {});
    _save();
    _t?.cancel();
    _done?.cancel();
    _errSub?.cancel();
    _logSub?.cancel();
    _endSub?.cancel();
    _watch?.cancel();
    _retryNode.dispose();
    _main.dispose();
    _tvT?.cancel();
    _playSub?.cancel();
    _tvPlay.dispose();
    _tvBar.dispose();
    for (final n in [..._tvPool, ..._failNodes]) {
      n.dispose();
    }
    _tr?.cancel();
    _banner?.cancel();
    _first.dispose();
    if (!kIsWeb && Platform.isAndroid && Device.touch) _pip.invokeMethod('arm', false).catchError((_) {});
    for (final d in _dbg ?? <StreamSubscription>[]) {
      d.cancel();
    }
    player.dispose();
    super.dispose();
  }

  // ---------- télécommande : barre de lecture façon télé (OK = pause, ← → = saut, ↑ ↓ = chaîne ou commandes) ----------
  bool _tvUi = false;
  bool get _oneScreen => _xt?.info['max'] == '1' && widget.url.startsWith('http');
  bool get _touch => !Device.tv && !kIsWeb && (Platform.isIOS || Platform.isAndroid);      // téléphone / tablette : même barre de commandes que la télé, au toucher
  Timer? _tvT;
  final FocusNode _tvPlay = FocusNode(debugLabel: 'lecture');
  final FocusNode _tvBar = FocusNode(debugLabel: 'barre d\'avancement');
  bool _barOn = false;
  int _seekN = 0;
  DateTime _seekAt = DateTime(2000);
  Duration? _seekTgt;
  final List<FocusNode> _tvPool = List.generate(10, (i) => FocusNode(debugLabel: 'commande $i'));
  final List<FocusNode> _tvBtns = [];      // boutons de la barre, de gauche à droite (rempli à chaque affichage)

  void _tvShow({bool focus = false}) {
    _tvT?.cancel();
    _tvT = Timer(const Duration(seconds: 6), _tvHide);
    if (!_tvUi) setState(() => _tvUi = true);
    if (focus) WidgetsBinding.instance.addPostFrameCallback((_) => mounted && _tvUi ? _tvPlay.requestFocus() : null);
  }

  void _tvHide() {
    _tvT?.cancel();
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent == false) {      // un panneau (audio, options…) est ouvert : la barre reste
      _tvT = Timer(const Duration(seconds: 3), _tvHide);
      return;
    }
    if (_tvUi) setState(() => _tvUi = false);
    _main.requestFocus();
  }

  void _seekTo(Duration t) {
    _seekAt = DateTime.now();
    _seekTgt = t;
    player.seek(t);
    _tvShow();
    if (mounted) setState(() {});
  }

  void _tvSeek(int dir) {
    final now = DateTime.now();
    final recent = now.difference(_seekAt) < const Duration(milliseconds: 700);
    _seekN = recent ? _seekN + 1 : 0;
    final step = _seekN < 3 ? 10 : (_seekN < 8 ? 30 : 60);
    final base = recent && _seekTgt != null ? _seekTgt! : player.state.position;
    var t = base + Duration(seconds: dir * step);
    final d = player.state.duration;
    if (t < Duration.zero) t = Duration.zero;
    if (d > Duration.zero && t > d) t = d;
    _seekAt = now;
    _seekTgt = t;
    player.seek(t);
    _tvShow();
    if (mounted) setState(() {});      // la barre suit tout de suite la position visée
  }

  final List<FocusNode> _failNodes = [FocusNode(debugLabel: 'autre qualité'), FocusNode(debugLabel: 'retour échec')];

  KeyEventResult _tvKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (_syncMode) {
      if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
        _syncStep(k == LogicalKeyboardKey.arrowLeft ? -1 : 1, repeat: e is KeyRepeatEvent);
      } else if (e is KeyDownEvent) {
        _syncClose();
      }
      return KeyEventResult.handled;
    }
    if (_fail != null) {
      // message d'échec : ← → passent d'un bouton à l'autre, OK valide
      final ns = [_retryNode, if (_alts.length > 1) _failNodes[0], _failNodes[1]];
      final i = ns.indexWhere((n) => n.hasFocus);
      if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
        ns[i < 0 ? 0 : (i + (k == LogicalKeyboardKey.arrowLeft ? -1 : 1)).clamp(0, ns.length - 1)].requestFocus();
        return KeyEventResult.handled;
      }
      if (i < 0 && (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown)) {
        _retryNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final down = e is KeyDownEvent;
    final onBar = FocusManager.instance.primaryFocus != node;
    if (k == LogicalKeyboardKey.mediaPlayPause || k == LogicalKeyboardKey.mediaPlay || k == LogicalKeyboardKey.mediaPause) {
      if (down) {
        k == LogicalKeyboardKey.mediaPlay ? player.play() : (k == LogicalKeyboardKey.mediaPause ? player.pause() : player.playOrPause());
        _tvShow();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.mediaFastForward || k == LogicalKeyboardKey.mediaRewind) {
      if (down && !_live) _seekBy(k == LogicalKeyboardKey.mediaFastForward ? 30 : -30);
      return KeyEventResult.handled;
    }
    if ((k == LogicalKeyboardKey.channelUp || k == LogicalKeyboardKey.channelDown) && widget.zap.length > 1) {
      if (down) _zapBy(k == LogicalKeyboardKey.channelUp ? 1 : -1);
      return KeyEventResult.handled;
    }
    if (onBar) {
      if (_tvUi) _tvShow();      // chaque touche repousse la fermeture de la barre
      if (_tvBar.hasFocus) {
        // barre d'avancement sélectionnée : ← → avancent / reculent (pas qui grandit en maintenant), OK = pause, ↓ = boutons, ↑ = ferme
        if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
          _tvSeek(k == LogicalKeyboardKey.arrowLeft ? -1 : 1);
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowDown) {
          if (down) _tvPlay.requestFocus();
          return KeyEventResult.handled;
        }
        if (k == LogicalKeyboardKey.arrowUp) return KeyEventResult.handled;      // rien au-dessus : la barre reste (Retour ou le délai la ferment)
        if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
          if (down) {
            player.playOrPause();
            _tvShow();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
        final i = _tvBtns.indexWhere((n) => n.hasFocus);
        if (i >= 0) {
          final j = (i + (k == LogicalKeyboardKey.arrowLeft ? -1 : 1)).clamp(0, _tvBtns.length - 1);
          _tvBtns[j].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }
      if (k == LogicalKeyboardKey.arrowUp) {
        if (down) {
          if (!_live && _tvBar.canRequestFocus && _tvBar.context != null) _tvBar.requestFocus();      // ↑ depuis les boutons : on monte sur la barre d'avancement ; direct : rien au-dessus, la barre et la sélection restent
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (!down) return KeyEventResult.handled;
      if (_live) {
        _tvShow(focus: true);
      } else {
        player.playOrPause();
        _tvShow();
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight) {
      if (_live) {
        if (down) _tvShow(focus: true);
      } else {
        _tvSeek(k == LogicalKeyboardKey.arrowLeft ? -1 : 1);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      if (down) _tvShow(focus: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _clock(Duration d) {
    final s = d.inSeconds < 0 ? 0 : d.inSeconds;
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, x = s % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${x.toString().padLeft(2, '0')}' : '$m:${x.toString().padLeft(2, '0')}';
  }

  Widget _tvBtn(IconData ic, String label, VoidCallback f, {FocusNode? node, bool big = false}) {
    final nd = node ?? _tvPool[_tvBtns.length];
    _tvBtns.add(nd);
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FocusCard(
            focusNode: nd,
            radius: 40,
            focusScale: 1.12,
            onTap: () {
              _tvShow();
              f();
            },
            child: Container(width: big ? 80 : 68, height: big ? 80 : 68, color: const Color(0x66FFFFFF), child: Icon(ic, size: big ? 42 : 32, color: Colors.white)),
          ),
          const SizedBox(height: 6),
          Text(label, style: T(14, w: 600, color: const Color(0xCCFFFFFF))),
        ]),
      );
  }

  Widget _tvOverlay() {
    _tvBtns.clear();
    return Positioned.fill(
        child: IgnorePointer(
          ignoring: !_tvUi,
          child: ExcludeFocus(
            excluding: !_tvUi,
            child: AnimatedOpacity(
              opacity: _tvUi ? 1 : 0,
              duration: Duration(milliseconds: Perf.lite ? 0 : 160),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: EdgeInsets.fromLTRB(math.max(_touch ? 28.0 : 64.0, MediaQuery.paddingOf(context).left + 20), 70, math.max(_touch ? 28.0 : 64.0, MediaQuery.paddingOf(context).right + 20), math.max(_touch ? 20.0 : 36.0, MediaQuery.paddingOf(context).bottom + 8)),
                  decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xE6000000)])),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(28, w: 750)),
                    if (_epgLine.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_epgLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(18, w: 500, color: const Color(0xCCFFFFFF)))),
                    const SizedBox(height: 14),
                    if (!_live)
                      StreamBuilder<Duration>(
                        stream: player.stream.position.distinct((a, b) => a.inSeconds == b.inSeconds),
                        initialData: player.state.position,
                        builder: (_, sn) {
                          final d = player.state.duration;
                          final seeking = DateTime.now().difference(_seekAt) < const Duration(milliseconds: 800) && _seekTgt != null;
                          final p = seeking ? _seekTgt! : (sn.data ?? Duration.zero);
                          final v = d.inMilliseconds > 0 ? (p.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0) : 0.0;
                          final on = _barOn;
                          return Focus(
                            focusNode: _tvBar,
                            onFocusChange: (f) {
                              if (mounted) setState(() => _barOn = f);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: on ? const Color(0x33FFFFFF) : Colors.transparent, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? kAccent : Colors.transparent, width: 2.5)),
                              child: Row(children: [
                                SizedBox(width: 84, child: Text(_clock(p), style: T(on ? 21 : 18, w: 700))),
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (_, c) => GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTapDown: !_touch || d.inMilliseconds <= 0 ? null : (t) => _seekTo(d * (t.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)),
                                      onHorizontalDragUpdate: !_touch || d.inMilliseconds <= 0 ? null : (t) => _seekTo(d * (t.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)),
                                      child: SizedBox(
                                      height: 30,
                                      child: Stack(alignment: Alignment.centerLeft, clipBehavior: Clip.none, children: [
                                        AnimatedContainer(duration: const Duration(milliseconds: 120), height: on ? 14 : 8, decoration: BoxDecoration(color: const Color(0x40FFFFFF), borderRadius: BorderRadius.circular(8))),
                                        AnimatedContainer(duration: const Duration(milliseconds: 120), width: c.maxWidth * v, height: on ? 14 : 8, decoration: BoxDecoration(color: on ? kAccent : Colors.white, borderRadius: BorderRadius.circular(8))),
                                        if (on) Positioned(left: (c.maxWidth * v - 14).clamp(0.0, c.maxWidth - 28), child: Container(width: 28, height: 28, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 8)]))),
                                      ]),
                                    ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 100, child: Text(_clock(d), textAlign: TextAlign.right, style: T(on ? 21 : 18, w: 700, color: const Color(0xCCFFFFFF)))),
                              ]),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    Center(
                      child: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children: [
                        _tvBtn(CupertinoIcons.chevron_back, 'Retour', () => Navigator.pop(context)),      // pop et non maybePop : la barre est affichée, donc la touche Retour de la télécommande ne ferait que la masquer
                        _tvBtn(player.state.playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill, player.state.playing ? 'Pause' : 'Lecture', player.playOrPause, node: _tvPlay, big: true),
                        if (!_live) _tvBtn(CupertinoIcons.gobackward_10, '-10 s', () => _tvSeek(-1)),
                        if (!_live) _tvBtn(CupertinoIcons.goforward_10, '+10 s', () => _tvSeek(1)),
                        if (_live && widget.zap.length > 1) _tvBtn(CupertinoIcons.chevron_up, 'Chaîne +', () => _zapBy(1)),
                        if (_live && widget.zap.length > 1) _tvBtn(CupertinoIcons.chevron_down, 'Chaîne -', () => _zapBy(-1)),
                        if (_alts.length > 1) _tvBtn(CupertinoIcons.square_stack_3d_up, 'Qualité ${_alts[_alt].$1}', _qualityMenu),
                        _tvBtn(CupertinoIcons.speaker_2_fill, 'Son', _tracks),
                        _tvBtn(CupertinoIcons.ellipsis, 'Plus', _moreMenu),
                      ])),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !Device.tv || !_tvUi,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _tvHide();
      },
      child: Focus(
        focusNode: _main,
        autofocus: true,
        onKeyEvent: (node, e) {
          if (Device.tv) return _tvKey(node, e);
          if (e is! KeyDownEvent) return KeyEventResult.ignored;
          final k = e.logicalKey;
          final onBar = FocusManager.instance.primaryFocus != node;
          // Windows (clavier + souris) : espace = pause, ← → = ±10 s (films), Échap = retour
          if (!kIsWeb && Platform.isWindows && !onBar && _fail == null) {
            if (k == LogicalKeyboardKey.space) {
              player.playOrPause();
              return KeyEventResult.handled;
            }
            if (!_live && (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight)) {
              _seekBy(k == LogicalKeyboardKey.arrowLeft ? -10 : 10);
              return KeyEventResult.handled;
            }
            if (k == LogicalKeyboardKey.escape) {
              Navigator.maybePop(context);
              return KeyEventResult.handled;
            }
          }
          // message d'échec affiché : les flèches circulent entre ses boutons (les touches chaîne zappent toujours)
          if (_fail != null && onBar && k != LogicalKeyboardKey.channelUp && k != LogicalKeyboardKey.channelDown) return KeyEventResult.ignored;
          // gauche / droite : on passe aux boutons du haut
          if (!onBar && (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight)) {
            _first.requestFocus();
            return KeyEventResult.handled;
          }
          if (widget.zap.length < 2) {
            if (onBar && k == LogicalKeyboardKey.arrowDown) {
              node.requestFocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }
          if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.channelUp) {
            _zapBy(-1);
            return KeyEventResult.handled;
          }
          if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.channelDown) {
            _zapBy(1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: _scaffold(context),
      ));

  /// tampon en mémoire : trait fin au bas de l'écran (film : zone déjà chargée en clair, lecture en blanc ; direct : jauge d'avance sur le tampon réglé)
  Widget _bufBar() => StreamBuilder<Duration>(
        stream: player.stream.buffer.distinct((a, b) => a.inSeconds == b.inSeconds),
        initialData: player.state.buffer,
        builder: (_, sn) {
          final buf = sn.data ?? Duration.zero, pos = player.state.position, dur = player.state.duration;
          final ahead = (buf - pos).inSeconds.clamp(0, 9999);
          final double bufV = _live ? (ahead / _PlayerScreenState.bufSecs).clamp(0.0, 1.0) : (dur.inMilliseconds > 0 ? (buf.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0);
          final double posV = !_live && dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
          return IgnorePointer(
            child: Stack(alignment: Alignment.bottomLeft, children: [
              if ((Device.tv || _touch) && _tvUi) Align(alignment: Alignment.bottomRight, child: Padding(padding: const EdgeInsets.only(right: 18, bottom: 8), child: Text('${L.tr('Tampon')} : $ahead s', style: T(13, w: 650, color: const Color(0xCCFFFFFF))))),
              SizedBox(height: 3, width: double.infinity, child: Stack(children: [
                const Positioned.fill(child: ColoredBox(color: Color(0x26FFFFFF))),
                FractionallySizedBox(widthFactor: bufV, child: const ColoredBox(color: Color(0x99FFC857), child: SizedBox.expand())),
                if (!_live) FractionallySizedBox(widthFactor: posV, child: const ColoredBox(color: Colors.white, child: SizedBox.expand())),
              ])),
            ]),
          );
        },
      );

  Widget _scaffold(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Video(controller: controller, controls: _syncMode || Device.tv || _touch ? NoVideoControls : AdaptiveVideoControls),
          if (_touch) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _tvUi ? _tvHide() : _tvShow())),
          if ((Device.tv || _touch) && _tvUi) Positioned(left: 0, right: 0, bottom: 0, height: 34, child: _bufBar()),      // jamais par-dessus le film : seulement avec la barre de commandes
          if (_statsOn) _statsPanel(),
          // double tape à gauche / à droite : -10 s / +10 s (films et épisodes)
          if (_alts.isEmpty)
            Positioned.fill(
              child: Row(children: [
                for (final d in const [-10, 10])
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () {
                        final t = player.state.position + Duration(seconds: d);
                        player.seek(t < Duration.zero ? Duration.zero : t);
                        setState(() => _hint = d);
                        Timer(const Duration(milliseconds: 700), () {
                          if (mounted) setState(() => _hint = 0);
                        });
                      },
                      child: Center(child: AnimatedOpacity(opacity: _hint == d ? 1 : 0, duration: const Duration(milliseconds: 150), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(99)), child: Text(d < 0 ? '⏪ 10 s' : '10 s ⏩', style: T(15, w: 700))))),
                    ),
                  ),
              ]),
            ),
          if (Device.tv)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(child: AnimatedOpacity(opacity: _hintSec != 0 ? 1 : 0, duration: const Duration(milliseconds: 150), child: Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(99)), child: Text(_hintSec < 0 ? '⏪ ${-_hintSec} s' : '${_hintSec == 0 ? '' : _hintSec} s ⏩', style: T(20, w: 700))))),
              ),
            ),
          // échec : message lisible et choix (au doigt comme à la télécommande)
          if (_fail != null)
            Positioned.fill(
              child: Container(
                color: const Color(0xD9000000),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 44, color: kMut),
                  const SizedBox(height: 14),
                  Text('Lecture impossible', style: T(22, w: 750)),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Text(_oneScreen ? 'Attention : un autre appareil est peut-être en cours de lecture (ta source n\'autorise qu\'un écran à la fois). Je lui demande de s\'arrêter, puis je relance (quelques secondes). Si ça ne marche pas, ferme MinouFlix sur l\'autre appareil.' : '${_fail!} Vérifie ta connexion ; le serveur peut aussi être saturé.', textAlign: TextAlign.center, style: T(15, color: kMut, h: 1.4)),
                  ),
                  const SizedBox(height: 20),
                  Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                    _OvBtn(node: _retryNode, label: _oneScreen ? 'Remplacer et lire ici' : 'Réessayer', primary: true, onTap: _oneScreen && Connect.canSend ? _takeOver : _retryNow),
                    if (_alts.length > 1) _OvBtn(node: _failNodes[0], label: 'Autre qualité', onTap: _otherQuality),
                    _OvBtn(node: _failNodes[1], label: 'Retour', onTap: () => Navigator.pop(context)),
                  ]),
                ]),
              ),
            ),
          if (_adjNote)
            Positioned(
              top: 18,
              left: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(99)),
                child: Text('Qualité ajustée', style: T(13, w: 650, color: const Color(0xFFFFD08A))),
              ),
            ),
          if (_syncMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 90,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(color: const Color(0xD9000000), borderRadius: BorderRadius.circular(22)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Synchro audio', style: T(14, w: 600, color: kMut)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(iconSize: 34, icon: const Icon(CupertinoIcons.minus_circle_fill), onPressed: () => _syncStep(-1)),
                      SizedBox(width: 130, child: Text(_syncTxt, textAlign: TextAlign.center, style: T(26, w: 750))),
                      IconButton(iconSize: 34, icon: const Icon(CupertinoIcons.plus_circle_fill), onPressed: () => _syncStep(1)),
                    ]),
                    if (Device.tv) Text('← son plus tôt   ·   son plus tard →   ·   OK pour fermer', style: T(12.5, color: kMut)) else TextButton(onPressed: _syncClose, child: Text('OK', style: T(16, w: 700, color: kAccent))),
                    if (_syncRead.isNotEmpty && (double.tryParse(_syncRead.replaceAll(',', '.')) ?? _aDelay) != _aDelay) Text('non appliqué par le lecteur ($_syncRead)', style: T(12, color: const Color(0xFFFFB86B))),
                  ]),
                ),
              ),
            ),
          if (_nextIn > 0)
            Positioned(
              right: MediaQuery.paddingOf(context).right + 28,
              bottom: 110,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(99)),
                  child: Text('Épisode suivant dans $_nextIn s', style: T(16, w: 700)),
                ),
                const SizedBox(width: 10),
                _OvBtn(node: _nextNode, label: 'Annuler', onTap: _cancelNext),
              ]),
            ),
          if (_skipLabel != null && _fail == null && _nextIn == 0)
            Positioned(right: MediaQuery.paddingOf(context).right + 28, bottom: 110, child: _OvBtn(node: _skipNode, label: _skipLabel!, primary: true, onTap: _doSkip)),
          // titre, affiché quelques secondes au démarrage
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: math.max(64.0, MediaQuery.paddingOf(context).left + 20),
            right: 150,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showTitle ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(17, w: 700)),
                  if (_epgLine.isNotEmpty) Text(_epgLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(13, w: 500, color: const Color(0xCCFFFFFF))),
                ]),
              ),
            ),
          ),
          if ((Device.tv || _touch) && _tvUi && !_syncMode) _tvOverlay(),
          if (!Device.tv && !_touch && !_syncMode) Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: _TopBtn(node: _first, icon: CupertinoIcons.chevron_back, tip: 'Retour', onTap: () => Navigator.maybePop(context)),
          ),
          if (!Device.tv && !_touch && !_syncMode) Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 64,     // laisse la place au bouton Retour : la rangée défile au lieu de passer dessus
            right: 12,
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (_alts.length > 1)
                PopupMenuButton<int>(
                  tooltip: 'Qualité',
                  color: const Color(0xFF1A1D26),
                  onSelected: (i) {
                    setState(() => _alt = i);
                    _manualAlt();
                    _silent = 0;
                    _open(_alts[i].$2);
                  },
                  itemBuilder: (_) => [for (var i = 0; i < _alts.length; i++) PopupMenuItem(value: i, child: Text(_alts[i].$1 + (i == _alt ? '  ✓' : ''), style: T(15, w: 600)))],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(99)),
                    child: Text(_alts[_alt].$1, style: T(13, w: 650)),
                  ),
                ),
              if (widget.zap.length > 1) ...[const SizedBox(width: 8), _TopBtn(icon: CupertinoIcons.chevron_up, tip: 'Chaîne précédente', onTap: () => _zapBy(-1)), const SizedBox(width: 8), _TopBtn(icon: CupertinoIcons.chevron_down, tip: 'Chaîne suivante', onTap: () => _zapBy(1))],
              if (Device.tv && !_live) ...[
                const SizedBox(width: 8),
                _TopBtn(icon: CupertinoIcons.gobackward_30, tip: 'Reculer de 30 secondes', onTap: () => _seekBy(-30)),
                const SizedBox(width: 8),
                _TopBtn(icon: CupertinoIcons.gobackward_10, tip: 'Reculer de 10 secondes', onTap: () => _seekBy(-10)),
                const SizedBox(width: 8),
                _TopBtn(icon: CupertinoIcons.goforward_10, tip: 'Avancer de 10 secondes', onTap: () => _seekBy(10)),
                const SizedBox(width: 8),
                _TopBtn(icon: CupertinoIcons.goforward_30, tip: 'Avancer de 30 secondes', onTap: () => _seekBy(30)),
              ],
              const SizedBox(width: 8),
              _TopBtn(icon: CupertinoIcons.speaker_2_fill, tip: 'Son', onTap: _tracks),
              const SizedBox(width: 8),
              _TopBtn(icon: CupertinoIcons.ellipsis, tip: 'Plus d\'options', onTap: _moreMenu),
            ]),
            ),
            ),
          ),
        ]),
      );
}

class _TopBtn extends StatefulWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final FocusNode? node;
  const _TopBtn({required this.icon, required this.tip, required this.onTap, this.node});
  @override
  State<_TopBtn> createState() => _TopBtnState();
}

class _TopBtnState extends State<_TopBtn> {
  bool f = false;
  @override
  Widget build(BuildContext context) => Focus(
        focusNode: widget.node,
        onFocusChange: (v) => setState(() => f = v),
        onKeyEvent: (_, e) {
          final k = e.logicalKey;
          if (e is KeyDownEvent && (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.gameButtonA)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Tooltip(
          message: widget.tip,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: f ? Colors.white : const Color(0x99000000), shape: BoxShape.circle), child: Icon(widget.icon, size: 20, color: f ? Colors.black : Colors.white)),
          ),
        ),
      );
}

/// bouton du message d'échec du lecteur (pilule, cadre blanc au focus)
class _OvBtn extends StatefulWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  final FocusNode? node;
  const _OvBtn({required this.label, required this.onTap, this.primary = false, this.node});
  @override
  State<_OvBtn> createState() => _OvBtnState();
}

class _OvBtnState extends State<_OvBtn> {
  bool f = false;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: widget.label,
        child: Focus(
          focusNode: widget.node,
          onFocusChange: (v) => setState(() => f = v),
          onKeyEvent: (_, e) {
            final k = e.logicalKey;
            if (e is KeyDownEvent && (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.gameButtonA)) {
              widget.onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(color: f ? Colors.white : (widget.primary ? kAccent : const Color(0x33FFFFFF)), borderRadius: BorderRadius.circular(99), border: Border.all(color: f ? Colors.white : Colors.transparent, width: 2)),
              child: ExcludeSemantics(child: Text(widget.label, style: T(16, w: 700, color: f ? Colors.black : Colors.white))),
            ),
          ),
        ),
      );
}
