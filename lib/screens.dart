import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb, ValueListenable;
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' hide Text;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'about.dart';
import 'epg.dart';
import 'extras.dart';
import 'journal.dart';
import 'names.dart';
import 'tmdb.dart';
import 'sport.dart';
import 'version.dart';
import 'store.dart';
import 'account_ui.dart';
import 'sync.dart';
import 'auth.dart';
import 'pairing.dart';
import 'phone_entry.dart';
import 'chaines.dart';
import 'connect.dart';
import 'telecommande.dart';
import 'diag.dart';
import 'profils.dart';
import 'sources.dart';
import 'pin_guard.dart';
import 'osk.dart';
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
        AppField(controller: prenom, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nom du profil (pour « Bonjour … »)', border: OutlineInputBorder())),
        const SizedBox(height: 14),
      ],
      SegmentedButton<bool>(
        segments: const [ButtonSegment(value: false, label: Text('Identifiants')), ButtonSegment(value: true, label: Text('Playlist M3U'))],
        selected: {m3u},
        onSelectionChanged: (v) => setState(() => m3u = v.first),
      ),
      const SizedBox(height: 14),
      AppField(controller: server, keyboardType: TextInputType.url, autocorrect: false, onSubmitted: (_) => m3u ? go() : null, decoration: InputDecoration(labelText: m3u ? 'Adresse de la playlist (http://….m3u)' : 'Adresse du serveur (http://…)', border: const OutlineInputBorder())),
      if (!m3u) ...[
        const SizedBox(height: 14),
        AppField(controller: user, autocorrect: false, decoration: const InputDecoration(labelText: 'Identifiant', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        AppField(controller: pass, obscureText: true, autocorrect: false, onSubmitted: (_) => go(), decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder())),
      ],
      if (error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(error!, style: const TextStyle(color: Color(0xFFFF6B7A)))),
      const SizedBox(height: 22),
      FilledButton(onPressed: busy ? null : go, child: Padding(padding: const EdgeInsets.all(14), child: busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Se connecter'))),
    ];
    const intro = 'Connecte ton abonnement. Les identifiants restent chiffrés sur cet appareil.';
    if (!widget.adding) {
      // premier lancement : sur télé, formulaire à gauche et connexion par le téléphone (QR) à droite
      return AuthLayout(step: 1, text: intro, side: [if (phone.url != null) phone.card(qr: AuthLayout.wide(context) ? 170 : 110)], form: form);
    }
    return Scaffold(
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
    );
  }
}

/// ---------- 2. choix des catégories (seules celles cochées sont téléchargées) ----------
class CategoriesScreen extends StatefulWidget {
  final Creds creds;
  final VoidCallback onDone;
  final VoidCallback? onCancel;     // changement depuis les réglages : Retour garde l'ancienne sélection
  const CategoriesScreen({super.key, required this.creds, required this.onDone, this.onCancel});
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

  @override
  void initState() {
    super.initState();
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
      builder: (ctx) => AlertDialog(
        backgroundColor: kBg2,
        title: Text('Filtrer les catégories', style: T(18, w: 700)),
        content: AppField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v), decoration: InputDecoration(hintText: kStore ? 'Ex. : sport, documentaire…' : 'Ex. : sport, netflix…')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Effacer')), TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('OK'))],
      ),
    );
    if (v != null && mounted) setState(() => filter = v.toLowerCase().trim());
  }

  @override
  Widget build(BuildContext context) {
    final total = picked.values.fold<int>(0, (a, s) => a + s.length);
    final ready = cats.length >= 3;
    final k = Kind.values[ki];
    final shown = ready ? cats[k]!.where((c) => filter.isEmpty || c.name.toLowerCase().contains(filter)).toList() : <Cat>[];
    final pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: widget.onCancel == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onCancel?.call();
      },
      child: Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(28 + pad.left, 18 + pad.top, 28 + pad.right, 0),
        child: error != null
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(error!, textAlign: TextAlign.center, style: T(16, color: kMut)),
                  const SizedBox(height: 18),
                  PillButton(label: 'Réessayer', primary: true, onTap: load),
                  if (widget.onCancel != null) ...[const SizedBox(height: 10), PillButton(label: 'Annuler', onTap: widget.onCancel!)],
                ]),
              )
            : !ready
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('Lecture des catégories… ${cats.length}/3', style: T(14, color: kMut)),
                      if (widget.onCancel == null) ...[const SizedBox(height: 18), const Steps(2)],
                    ]),
                  )
                : FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (widget.onCancel == null) const Padding(padding: EdgeInsets.only(bottom: 12), child: Steps(2)),
                      Row(children: [
                        if (widget.onCancel != null) ...[RoundButton(size: 44, label: 'Annuler', onTap: widget.onCancel, child: const Ic('back', size: 20)), const SizedBox(width: 12)],
                        Expanded(child: Text('Que veux-tu charger ?', maxLines: 2, overflow: TextOverflow.ellipsis, style: T(26, w: 800, ls: -0.03))),
                        const SizedBox(width: 10),
                        PillButton(
                          label: 'Charger ($total)',
                          icon: 'play',
                          primary: true,
                          height: 50,
                          onTap: total == 0 ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coche au moins une catégorie.'))) : save,
                        ),
                      ]),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '${total > 60 ? 'Beaucoup de catégories : le premier chargement sera long (l\'accueil s\'affiche dès les premières). Moins il y en a, plus c\'est rapide.' : 'Seules les catégories cochées sont téléchargées. L\'accueil s\'affiche dès les premières reçues.'}${total > 0 ? ' Premier chargement estimé : ${etaLabel(total * 2)} (selon ton fournisseur), ensuite presque instantané grâce au cache.' : ''}',
                          style: T(13.5, color: total > 60 ? const Color(0xFFFFB86B) : kMut),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        for (var i = 0; i < Kind.values.length; i++)
                          _CatChip(label: '${Kind.values[i].label} (${picked[Kind.values[i]]!.length}/${cats[Kind.values[i]]!.length})', on: i == ki, onTap: () => setState(() => ki = i)),
                        _CatChip(label: 'Suggestion', onTap: () => setState(() => picked[k] = {for (final c in cats[k]!) if (suggested(k, c.name)) c.id})),
                        _CatChip(label: 'Tout cocher', onTap: () => setState(() => picked[k]!.addAll(shown.map((c) => c.id)))),
                        _CatChip(label: 'Tout décocher', onTap: () => setState(() => picked[k]!.removeAll(shown.map((c) => c.id)))),
                        _CatChip(label: filter.isEmpty ? 'Filtrer' : 'Filtre : $filter', onTap: _filter),
                      ]),
                      const SizedBox(height: 10),
                      Expanded(
                        child: shown.isEmpty
                            ? Center(child: Text(filter.isEmpty ? 'Aucune catégorie chez le fournisseur.' : 'Aucune catégorie ne correspond au filtre.', style: T(15, color: kMut)))
                            : ListView.builder(
                                padding: EdgeInsets.only(bottom: 40 + pad.bottom),
                                itemCount: shown.length,
                                itemBuilder: (_, i) {
                                  final c = shown[i];
                                  final on = picked[k]!.contains(c.id);
                                  return _CatRow(name: c.name, on: on, autofocus: i == 0, onTap: () => setState(() => on ? picked[k]!.remove(c.id) : picked[k]!.add(c.id)));
                                },
                              ),
                      ),
                    ]),
                  ),
      ),
      ),
    );
  }
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

class _CatRow extends StatefulWidget {
  final String name;
  final bool on, autofocus;
  final VoidCallback onTap;
  const _CatRow({required this.name, required this.on, required this.autofocus, required this.onTap});
  @override
  State<_CatRow> createState() => _CatRowState();
}

class _CatRowState extends State<_CatRow> {
  bool f = false;
  @override
  Widget build(BuildContext context) => Focus(
        autofocus: widget.autofocus,
        onFocusChange: (v) {
          setState(() => f = v);
          if (v) Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 120));
        },
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
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(color: f ? const Color(0x33FFFFFF) : const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(14), border: Border.all(color: f ? Colors.white : Colors.transparent, width: 2.5)),
            child: Row(children: [
              Expanded(child: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(16.5, w: 600))),
              Icon(widget.on ? Icons.check_circle : Icons.circle_outlined, color: widget.on ? kAccent : kMut, size: 26),
            ]),
          ),
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
  int tab = 0;
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
  Widget _swipePages(List<Widget> pages, bool kid) {
    final vis = [for (var i = 0; i < pages.length; i++) if (!(kid && (i == 1 || i == 2))) i];
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
      children: [for (final v in vis) _KeepAlive(child: pages[v])],
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
    Epg.version.addListener(_epgChanged);
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
      builder: (ctx) => AlertDialog(
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
  }

  Timer? _syncT;

  Future<void> _sync() async {
    final before = Store.sportKeys.join();
    if (await Sync.run() && mounted) {
      if (Store.sportKeys.join() != before) sport = fetchSport(Store.sportKeys);     // sinon inutile de redemander les matchs
      setState(() {});
    }
  }

  void _epgChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    for (final k in Kind.values) {
      final ids = Store.selection(k) ?? [];
      final have = await Store.cachedCats(k, ids);
      _cats[k] = {for (final id in ids) if (have.containsKey(id)) id: have[id]!.$2};
      if (have.isNotEmpty) _derive(k);
      missing[k] = _byPriority(k, [for (final id in ids) if (!have.containsKey(id)) id]);
      stale[k] = _byPriority(k, [for (final id in ids) if (have.containsKey(id) && (force || now - have[id]!.$1 > 12 * 3600 * 1000)) id]);
    }
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
    final near = chans.where((o) => o.theme == c.theme).toList();
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

  /// match : on lance la chaîne habituelle de la compétition si on la trouve, sinon on ouvre le Direct « Sport »
  void openEv(Ev e) {
    if (kStore) {
      // version store : le sport reste un calendrier (aucune chaîne lancée depuis un match)
      if (tab != 2) setState(() => tab = 2);
      return;
    }
    for (final p in lgOf(e.lg).ch) {
      final rx = RegExp(p);
      final c = chans.where((c) => rx.hasMatch(norm(c.name))).firstOrNull;
      if (c != null) {
        playChan(c);
        return;
      }
    }
    setState(() {
      liveTheme = 'sport';
      tab = 1;
    });
  }

  void info(Item it) {
    if (!_once()) return;
    warmBackdrop(context, it);
    Navigator.push(context, softRoute((_) => DetailScreen(x: x, item: it, detailFor: detailFor, lib: libs[it.kind], onOpen: info))).then((_) {
      if (mounted) setState(() {});
    });
  }

  void openItem(Item it) => it.kind == Kind.live ? play(it) : info(it);
  bool _searchOpen = false;

  void search() {
    _searchOpen = true;
    Navigator.push(context, softRoute((_) => SearchScreen(items: [...uniqueTitles(libs[Kind.vod]?.rows ?? []), ...uniqueTitles(libs[Kind.series]?.rows ?? [])], onOpen: openItem))).then((_) => _searchOpen = false);
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
    if (kid && (tab == 1 || tab == 2)) tab = 0;
    final nav = NavPill(index: tab, onSelect: (v) => setState(() => tab = v), onSearch: search, hidden: kid ? const {1, 2} : const {}, pages: Device.tv ? null : _pc);
    final pages = [
      HomeTab(libs: libs, chans: chans, sport: kid ? Future.value(<Ev>[]) : sport, busy: busy, detailFor: detailFor, onOpen: openItem, onPlay: (it) => it.kind == Kind.series ? info(it) : play(it), onInfo: info, onTab: (v) => setState(() => tab = v), onChan: playChan, onEv: openEv, onResume: resume),
      LiveTab(chans: chans, busy: busy.contains(Kind.live), theme: liveTheme, onTheme: (t) => setState(() => liveTheme = t), onPlay: playChan, onHide: () => setState(() => _derive(Kind.live))),
      SportTab(future: sport, onOpen: openEv, onKeys: (k) async {
        await Store.saveSportKeys(k);
        if (mounted) setState(() => sport = fetchSport(k));
      }),
      LibTab(kind: Kind.vod, lib: libs[Kind.vod], busy: busy.contains(Kind.vod), detailFor: detailFor, onOpen: info, onPlay: (it) => info(it)),
      LibTab(kind: Kind.series, lib: libs[Kind.series], busy: busy.contains(Kind.series), detailFor: detailFor, onOpen: info, onPlay: (it) => info(it)),
    ];
    final title = tab == 0 ? (Store.name.isEmpty ? 'Accueil' : 'Bonjour ${Store.name}') : ['', 'Direct', 'Sport', 'Films', 'Séries'][tab];
    final heroTab = tab == 0 || tab == 3 || tab == 4;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(top: wide ? 78 + pad.top : 0, child: Device.tv ? IndexedStack(index: tab, children: pages) : _swipePages(pages, kid)),
        // en-tête : titre à gauche, réglages à droite (navigation au centre sur grand écran)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(20 + pad.left, pad.top + 8, 20 + pad.right, 12),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kBg.withOpacity(wide || !heroTab ? 0.97 : 0.72), kBg.withOpacity(0.0)])),
            child: Row(children: [
              if (wide) ...[Text('MinouFlix', style: T(26, w: 850, ls: -0.04)), const Spacer(), nav, const Spacer()] else Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(28, w: 750, ls: -0.035))),
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
    );
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
    final sw = wide ? 270.0 : 256.0;
    final kid = Store.kid;
    final cont = kid ? <Prog>[] : Store.progress();     // mode enfant : pas de reprise ni de téléchargements des adultes
    final favs = Store.favs;
    final mylist = [...?vl?.rows.where((i) => favs.contains('vod:${i.id}')), ...?sl?.rows.where((i) => favs.contains('series:${i.id}'))];
    return ListView(padding: EdgeInsets.only(bottom: wide ? 40 : 110), children: [
      if (feat.isNotEmpty) HeroBanner(items: feat.take(7).toList(), detailFor: detailFor, onPlay: onPlay, onInfo: onInfo) else SizedBox(height: pad.top + 70),
      Rail(title: 'Continuer à regarder', height: 150, count: cont.length, moreLabel: '', builder: (_, i) => ContinueCard(p: cont[i], onTap: () => onResume(cont[i]), onRemove: () async {
            await Store.hideProg(cont[i].key);
            onTab(0);
          })),
      Rail(title: 'Ma liste', height: ph, count: mylist.length.clamp(0, 24), moreLabel: '', builder: (_, i) => Poster(item: mylist[i], width: pw, onTap: () => onOpen(mylist[i]))),
      // ni liste ni collection : une ligne d'aide plutôt qu'un vide
      if (mylist.isEmpty && Store.colls.values.every((v) => v.isEmpty) && !kid && (vl?.rows.isNotEmpty ?? false)) ...[
        const SectionTitle('Ma liste'),
        const EmptyState(compact: true, icon: Icons.bookmark_border_rounded, title: 'Garde tes envies ici', sub: 'Sur une fiche, « + » ajoute un film ou une série à ta liste ou à une playlist, pour les ranger par thème.'),
      ],
      FutureBuilder<List<Soon>>(
        future: Calendar.of(sl),
        builder: (_, s) => Rail(title: 'Prochains épisodes', height: 118, count: (s.data ?? const []).length, moreLabel: '', builder: (_, i) => SoonCard(s: s.data![i], onTap: () => onOpen(s.data![i].it))),
      ),
      Builder(builder: (ctx) {
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
                final r = await showModalBottomSheet<String>(
                  context: ctx,
                  backgroundColor: kBg2,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
                  builder: (_) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Padding(padding: const EdgeInsets.fromLTRB(22, 18, 22, 6), child: Align(alignment: Alignment.centerLeft, child: Text(cs[i].key, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(17, w: 700)))),
                      ListTile(autofocus: true, leading: const Icon(CupertinoIcons.trash, color: Color(0xFFFF6B7A)), title: const Text('Supprimer la playlist', style: TextStyle(color: Color(0xFFFF6B7A))), subtitle: const Text('Les films et séries ne sont pas supprimés'), onTap: () => Navigator.pop(ctx, 'del')),
                      const SizedBox(height: 8),
                    ]),
                  ),
                );
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
      Builder(builder: (ctx) {
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
      FutureBuilder<List<Map>>(
        future: Tmdb.trending(),
        builder: (_, s) {
          final tr = trendTop(s.data ?? const [], vl, sl);
          final l = tr.isNotEmpty ? tr : top;
          return Rail(title: 'Top 10 cette semaine', height: ph, count: l.length, moreLabel: '', builder: (_, i) => Top10Card(rank: i + 1, item: l[i], width: pw, onTap: () => onOpen(l[i])));
        },
      ),
      FutureBuilder<List<Map>>(
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
      FutureBuilder<List<Ev>>(
        future: sport,
        builder: (_, s) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final evs = (s.data ?? []).where((e) => e.live || (e.ts > now - 7200 && e.ts < now + 3 * 86400 && !e.post)).take(10).toList();
          return Rail(title: 'Sport', height: 124, count: evs.length, onMore: () => onTab(2), moreLabel: 'Calendrier', builder: (_, i) => SportCard(e: evs[i], width: sw, onTap: () => onEv(evs[i])));
        },
      ),
      Rail(title: 'Mes chaînes', height: 138, count: mine.length, onMore: () => onTab(1), builder: (_, i) => ChannelTile(item: mine[i], onTap: () => onChan(mine[i]))),
      if (mine.isEmpty && chans.isNotEmpty && !kid) ...[
        const SectionTitle('Mes chaînes'),
        const EmptyState(compact: true, icon: Icons.star_border_rounded, title: 'Aucune chaîne favorite', sub: 'Dans Direct, touche l\'étoile d\'une chaîne (ou appui long) pour la retrouver ici.'),
      ],
      if (recoV.isNotEmpty) rail('Vous aimerez peut-être', recoV),
      if (recoS.isNotEmpty) rail('Séries pour vous', recoS),
      rail('Derniers films ajoutés', rv, tab: 3),
      rail('Séries mises à jour', rs, tab: 4),
    ]);
  }
}

/// ---------- direct ----------
class LiveTab extends StatefulWidget {
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
                delegate: SliverChildBuilderDelegate((_, i) => ChannelRow(item: l[i], onTap: () => widget.onPlay(l[i]), onLong: () => chanMenu(context, l[i], () => widget.onHide?.call())), childCount: l.length),
              )
            : SliverList(delegate: SliverChildBuilderDelegate((_, i) => ChannelRow(item: l[i], onTap: () => widget.onPlay(l[i]), onLong: () => chanMenu(context, l[i], () => widget.onHide?.call())), childCount: l.length)),
      ),
    ]);
  }
}

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
    for (final c in lb.ofKind('studio')) {
      final k = platOf(c.label);
      if (k != null) gp.putIfAbsent(k, () => {}).add(c.id);
    }
    final plats = kStore ? <(String, String, String)>[] : [for (final p in platforms) if (gp.containsKey(p.$1)) p];     // version store : pas de rangée de plateformes
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
    final hero = lb.recent.where((i) => i.rating >= 6).take(7).toList();
    final pad = MediaQuery.paddingOf(context);
    return ListView(padding: EdgeInsets.only(bottom: wide ? 40 : 110), children: [
      if (hero.length >= 3) HeroBanner(items: hero, detailFor: detailFor, onPlay: onPlay, onInfo: onOpen) else SizedBox(height: pad.top + 70),
      if (plats.isNotEmpty)
        Rail(
          title: 'Plateformes',
          height: 132,
          count: plats.length,
          builder: (_, i) => PlatTile(keyName: plats[i].$1, name: plats[i].$2, onTap: () => _grid(context, plats[i].$2, uniqueTitles(lb.inCats(gp[plats[i].$1]!)))),
        ),
      // studios : appariés une fois la bibliothèque complète (pas sur une liste encore partielle)
      if (!busy || Studios.ready(kind))
      FutureBuilder<List<StudioHit>>(
        future: Studios.of(lb),
        builder: (_, snap) {
          final st = snap.data ?? const <StudioHit>[];
          if (st.isEmpty) return const SizedBox.shrink();
          return Rail(
            title: 'Studios',
            height: 260,
            count: st.length,
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
      rail(kind == Kind.vod ? 'Derniers films ajoutés' : 'Dernières séries ajoutées', lb.recent),
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
    return Scaffold(
      appBar: AppBar(backgroundColor: kBg, title: Text(widget.title, style: T(22, w: 750, ls: -0.03))),
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
    );
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
    return Scaffold(
      appBar: AppBar(backgroundColor: kBg, title: Text(lb.kind == Kind.vod ? 'Films' : 'Séries', style: T(22, w: 750, ls: -0.03))),
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
    );
  }
}

/// ---------- recherche ----------
class SearchScreen extends StatefulWidget {
  final List<Item> items;
  final void Function(Item) onOpen;
  const SearchScreen({super.key, required this.items, required this.onOpen});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String q = '';
  final TextEditingController _tc = TextEditingController();

  void _remote() {
    _tc.text = Connect.query.value;
    _tc.selection = TextSelection.collapsed(offset: _tc.text.length);
    setState(() => q = Connect.query.value);
  }

  @override
  void initState() {
    super.initState();
    Connect.query.addListener(_remote);
    if (Connect.query.value.isNotEmpty) {
      _tc.text = Connect.query.value;
      q = Connect.query.value;
    }
  }

  @override
  void dispose() {
    Connect.query.removeListener(_remote);
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nq = norm(q);
    final l = nq.length < 2 ? <Item>[] : widget.items.where((i) => norm(i.title).contains(nq)).take(120).toList();
    final wide = isWide(context);
    final w = wide ? 170.0 : 118.0;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
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
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: kEdge, width: 0.8)),
            child: Row(children: [
              const Ic('search', size: 20, color: kMut),
              const SizedBox(width: 10),
              Expanded(child: AppField(controller: _tc, autofocus: true, style: T(17, w: 500), onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: 'Film, série…', hintStyle: T(17, w: 400, color: kMut), border: InputBorder.none, isCollapsed: true))),
            ]),
          ),
        ),
        Expanded(
          child: l.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 90),
                  child: widget.items.isEmpty
                      ? const EmptyState(icon: Icons.hourglass_top_rounded, title: 'Catalogue en cours de chargement', sub: 'Les films et séries apparaissent ici dès qu\'ils sont reçus.')
                      : nq.length < 2
                          ? const EmptyState(icon: Icons.search_rounded, title: 'Que cherches-tu ?', sub: 'Tape au moins 2 lettres d\'un film ou d\'une série.')
                          : EmptyState(icon: Icons.search_off_rounded, title: 'Aucun résultat pour « $q »', sub: 'Vérifie l\'orthographe ou essaie un autre titre.'),
                )
              : CustomScrollView(slivers: [
                  for (final sec in [('Films', l.where((i) => i.kind == Kind.vod).toList()), ('Séries', l.where((i) => i.kind == Kind.series).toList())])
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
                              onTap: () {
                                Navigator.pop(context);
                                widget.onOpen(sec.$2[i]);
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
    );
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
      builder: (ctx) => AlertDialog(
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
      builder: (ctx) => AlertDialog(
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
      builder: (ctx) => AlertDialog(
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
      builder: (ctx) => AlertDialog(
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
    final k = await manageLeagues(context);
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

  Future<void> _logout() async {
    if (!await _confirm('Se déconnecter de l\'abonnement ?', 'Les identifiants IPTV de cet appareil seront effacés. Ton compte MinouFlix, ta liste et ta reprise sont conservés.', 'Se déconnecter')) return;
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);     // ferme aussi la page de catégorie ouverte
    widget.onLogout();
  }

  Future<void> _wipe() async {
    if (!await _unlocked()) return;
    if (!await _confirm(
      'Effacer mes données ?',
      'Tout ce que MinouFlix garde sur cet appareil sera supprimé : identifiants, réglages, ma liste, reprise, catalogue et téléchargements.${Account.signedIn ? ' La copie synchronisée de ton compte sera aussi effacée si possible.' : ''}',
      'Tout effacer',
      danger: true,
    )) return;
    if (Account.signedIn) await Sync.wipe();
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
        builder: (ctx) => AlertDialog(
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
    await Navigator.push(context, softRoute((_) => TextPage(title: 'Journal d\'erreurs', mono: t.isEmpty ? 'Aucune erreur notée.' : t, action: 'Copier', onAction: _copyJournal)));
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
    final sports = [for (final k in knownLeagues(Store.sportKeys)) lgOf(k).n].join(', ');
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
    const aOpts = [('', 'Automatique'), ('fr', 'Français'), ('en', 'Anglais')];
    const sOpts = [('', 'Automatique'), ('no', 'Aucun'), ('fr', 'Français'), ('en', 'Anglais')];
    Widget sw(String t, IconData i, Color c, String k, bool def) => _row(i, c, t, on: Store.flag(k, def), onTap: () async {
          await Store.setFlag(k, !Store.flag(k, def));
          if (mounted) setState(() {});
        });
    // (nom dans la liste, titre de section, icône, lignes) : même arbre sur téléphone, tablette et télé
    final groups = <(String, String, IconData, List<Widget>)>[
      ('Compte', '', CupertinoIcons.person_crop_circle, [
        if (Device.tv) _row(CupertinoIcons.person_crop_circle_fill, const Color(0xFFAF52DE), 'Profil et compte', value: profName, chevron: true, onTap: () => Navigator.push(context, softRoute((_) => ProfilsScreen(onSwitch: widget.onSwitch ?? () {})))),
        _row(CupertinoIcons.smiley_fill, const Color(0xFF30D158), 'Mode enfant', on: kidMode, onTap: _kid),
        _row(CupertinoIcons.globe, const Color(0xFF0A84FF), 'Langue', value: L.en ? 'English' : 'Français', chevron: true, onTap: () => _pickPage('Langue', const [('fr', 'Français'), ('en', 'English')], () => L.lang, (v) async {
          await L.set(v);
          Tmdb.reset();
        }, foot: 'Change la langue de l\'appli, des fiches et du clavier de la télé.')),
      ]),
      ('Lecture', 'Lecture', CupertinoIcons.play_circle, [
        _row(CupertinoIcons.slider_horizontal_3, const Color(0xFF0A84FF), 'Qualité', value: q('pref_q', qOpts).replaceAll(' si possible', '').replaceAll(' · moins de données', ''), chevron: true, onTap: () => _pickPage('Qualité', qOpts, () => Store.quality, (v) => Store.setStr('pref_q', v), foot: 'Films et chaînes proposés en plusieurs qualités.')),
        _row(CupertinoIcons.speaker_2_fill, const Color(0xFFFF9F0A), 'Langue audio', value: q('pref_aud', aOpts), chevron: true, onTap: () => _pickPage('Langue audio', aOpts, () => Store.str('pref_aud'), (v) => Store.setStr('pref_aud', v), foot: 'Choisie automatiquement quand le film la propose.')),
        _row(CupertinoIcons.captions_bubble_fill, const Color(0xFF5E5CE6), 'Sous-titres', value: q('pref_sub', sOpts), chevron: true, onTap: () => _pickPage('Sous-titres', sOpts, () => Store.str('pref_sub'), (v) => Store.setStr('pref_sub', v), foot: 'Appliqués au lancement de la lecture.')),
        sw('Passer l\'intro', CupertinoIcons.forward_fill, const Color(0xFFFF375F), 'skipauto', false),
        sw('Épisode suivant', CupertinoIcons.forward_end_fill, const Color(0xFF64D2FF), 'autonext', true),
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
        if (!kid) _row(CupertinoIcons.sportscourt_fill, const Color(0xFFFF453A), 'Championnats', value: sports.isEmpty ? 'Aucun' : '${knownLeagues(Store.sportKeys).length}', chevron: true, onTap: _sport),
        ValueListenableBuilder<(int, int)>(
          valueListenable: widget.progress,
          builder: (_, p, __) => _row(CupertinoIcons.arrow_2_circlepath, const Color(0xFF30D158), 'Actualiser', value: p.$2 > 0 ? '${p.$1}/${p.$2}' : _ago(Store.catT), trailing: p.$2 > 0 ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null, onTap: () {
            if (p.$2 > 0) return;
            widget.onRefresh();
            _snack('Actualisation lancée : tu peux continuer à naviguer.');
          }),
        ),
      ]),
      if (!Connect.tvNow)
        ('Appareils', 'Appareils', CupertinoIcons.tv, [
          if (Connect.canSend && !Connect.tvNow) _row(CupertinoIcons.slider_horizontal_3, const Color(0xFF32ADE6), 'Télécommande', chevron: true, onTap: () => Navigator.push(context, softRoute((_) => const TelecommandeScreen()))),
          if (!Connect.tvNow) _row(CupertinoIcons.tv_fill, const Color(0xFFAF52DE), 'Connecter une télé', value: Account.signedIn ? '' : 'Compte requis', chevron: true, onTap: _pairTv),
        ]),
      ('Stockage', 'Stockage', CupertinoIcons.arrow_down_circle, [
        _row(CupertinoIcons.arrow_down_circle_fill, const Color(0xFF0A84FF), 'Téléchargements', value: dls.isEmpty ? 'Aucun' : '${dls.length} · ${sizeLabel(dlTotal)}', chevron: true, onTap: _dlPage),
        _row(CupertinoIcons.folder_fill, grey, 'Cache', value: _imgBytes < 0 || _catBytes < 0 ? '' : sizeLabel(_imgBytes + _catBytes), chevron: true, onTap: _stockPage),
      ]),
      ('Aide', '', CupertinoIcons.question_circle, [
        _row(CupertinoIcons.wrench_fill, const Color(0xFFFF9F0A), 'Aide et dépannage', chevron: true, onTap: _aidePage),
        _row(CupertinoIcons.info_circle_fill, grey, 'À propos', value: 'Version $kBuild', chevron: true, onTap: _aboutPage),
      ]),
    ];
    _groups = groups;
    Widget content(int i) => _box(groups[i].$4);
    if (Device.tv) {
      final cur = _sec.clamp(0, groups.length - 1);
      return Scaffold(
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
      );
    }
    return Scaffold(
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
    );
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
              r[i],
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
                  body: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: FocusTraversalGroup(
                        policy: ReadingOrderTraversalPolicy(),
                        child: ListView(padding: EdgeInsets.fromLTRB(pad.left, 0, pad.right, 60 + pad.bottom), children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(16, pad.top + 8, 16, 14),
                            child: Row(children: [
                              RoundButton(size: 44, label: 'Retour', onTap: () => Navigator.pop(ctx), child: const Ic('back', size: 20)),
                              const SizedBox(width: 14),
                              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(26, w: 750, ls: -0.035))),
                            ]),
                          ),
                          ...body(),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            )),
      );

  /// choix dans une liste à coche (qualité, langues)
  void _pickPage(String title, List<(String, String)> opts, String Function() cur, Future<void> Function(String) pick, {String foot = ''}) => _page(title, () => [
        _box([for (final o in opts) _row(null, kAccent, o.$2, check: o.$1 == cur(), onTap: () async {
              await pick(o.$1);
              if (mounted) setState(() {});
            })]),
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
          _row(CupertinoIcons.doc_on_doc_fill, const Color(0xFF8E8E93), 'Copier le journal', onTap: _copyJournal),
        ]),
        _foot('Le journal ne contient jamais tes identifiants.'),
        const SizedBox(height: 22),
        _box([
          _row(CupertinoIcons.arrow_right_square_fill, const Color(0xFFFF9F0A), 'Se déconnecter de l\'abonnement', onTap: _logout),
          _row(CupertinoIcons.trash_fill, const Color(0xFFFF453A), 'Effacer mes données', danger: true, onTap: _wipe),
          if (Account.signedIn) _row(CupertinoIcons.person_crop_circle_badge_minus, const Color(0xFFFF453A), 'Supprimer mon compte', danger: true, onTap: _deleteAccount),
        ]),
        _foot('« Effacer mes données » remet l\'appli à zéro sur cet appareil. « Supprimer mon compte » efface aussi les données synchronisées.'),
      ]);

  void _aboutPage() => _page('À propos', () => [
        _box([
          _row(CupertinoIcons.info_circle_fill, const Color(0xFF8E8E93), 'Version', value: '$kBuild', chevron: !kStore && !kIsWeb && Platform.isAndroid, onTap: !kStore && !kIsWeb && Platform.isAndroid ? _update : null),
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
  bool _verSet = false;
  bool _more = false;      // résumé déplié
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.item.kind == Kind.series) {
        final r = await widget.x.seriesDetail(widget.item.id);
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
    Timer(const Duration(milliseconds: 2500), () {
      if (mounted && !_fReady) setState(() => _fReady = true);
    });
    Tmdb.fiche(widget.item).then((v) {
      if (mounted) setState(() {
        f = v;
        _fReady = true;
      });
    }).catchError((_) {
      if (mounted) setState(() => _fReady = true);
    });
  }

  void _play(String url, String title, {Prog? prog, List<(String, String, Prog)> next = const []}) => Navigator.push(context, softRoute((_) => PlayerScreen(url: url, title: title, prog: prog, next: next, tmdb: Tmdb.fiche(widget.item)))).then((_) {
        if (mounted) setState(() {});
      });

  String _mmss(int ms) {
    final s = ms ~/ 1000, h = s ~/ 3600, m = (s % 3600) ~/ 60, c = s % 60;
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${c.toString().padLeft(2, '0')}' : '$m:${c.toString().padLeft(2, '0')}';
  }

  Prog _epProg(Episode x) => Prog(kind: 'ep', id: x.id, sid: widget.item.id, ext: x.ext, name: 'S${x.season} · É${x.number}${x.title.isEmpty ? '' : ' · ${x.title}'}', icon: widget.item.icon, sname: widget.item.title);

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
    if (l == null || it.kind != Kind.vod) return [it];
    final v = l.rows.where((r) => r.p.key == it.p.key && r.year == it.year).toList();
    return v.isEmpty ? [it] : v;
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
    if (!_verSet && vs.length > 1) {
      // version choisie d'après la qualité par défaut des réglages
      _verSet = true;
      final want4k = Store.quality == '4k';
      final i = vs.indexWhere((v) => (v.quality == '4K') == want4k);
      if (i >= 0) ver = i;
    }
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
    final old = it.kind == Kind.vod ? prs.where((p) => p.kind == 'vod' && p.id == cur.id).firstOrNull : null;
    final lastProg = it.kind == Kind.series ? (prs.where((p) => p.kind == 'ep' && p.sid == it.id).toList()..sort((a, b) => b.t.compareTo(a.t))).firstOrNull : null;
    final lastEp = lastProg == null ? null : eps.where((e) => e.id == lastProg.id).firstOrNull;
    final wide = Device.tv;     // fiche « salon » sur télé seulement
    // grand écran (télé) : fiche « cinéma » — grand visuel, titre, résumé et boutons compacts regroupés au même endroit
    String vodPath() => Downloads.get('${Store.pre}vod:${cur.id}')?.path ?? widget.x.vodUrl(cur.id, cur.ext);
    Widget playBtn() {
      if (it.kind == Kind.vod) return PillButton(label: old != null ? 'Reprendre à ${_mmss(old.pos)}' : 'Lecture', icon: 'play', primary: true, height: 54, onTap: () => _play(vodPath(), it.title, prog: old ?? Prog(kind: 'vod', id: cur.id, ext: cur.ext, name: it.title, icon: it.icon)));
      if (lastEp != null) return PillButton(label: 'Reprendre S${lastEp.season}E${lastEp.number} à ${_mmss(lastProg!.pos)}', icon: 'play', primary: true, height: 54, onTap: () => _playEp(lastEp, prog: lastProg));
      if (eps.isNotEmpty) return PillButton(label: 'Lecture S${eps.first.season}E${eps.first.number}', icon: 'play', primary: true, height: 54, onTap: () => _playEp(eps.first));
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
      PillButton(label: '+ Ajouter à…', height: 54, onTap: () => collectionSheet(context, fav)),
      if (fi != null && fi.trailer.isNotEmpty) PillButton(label: 'Bande-annonce', icon: 'play', height: 54, onTap: () => launchUrl(Uri.parse('https://www.youtube.com/watch?v=${fi.trailer}'), mode: LaunchMode.externalApplication)),
      if (it.kind == Kind.vod)
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
    final plotText = fi != null && fi.plot.isNotEmpty ? fi.plot : (det?.plot ?? '');
    return Scaffold(
      body: Stack(children: [
        ListView(padding: EdgeInsets.zero, cacheExtent: 8000, children: [
          SizedBox(
            height: wide ? (MediaQuery.sizeOf(context).height * 0.78).clamp(420.0, 760.0) : 300 + top,
            child: Stack(fit: StackFit.expand, children: [
              fadeBackdrop(bd, it.icon),
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
          if (det == null) const SkeletonBlock(lines: 5) else ...[
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
                  if (fi != null && fi.trailer.isNotEmpty) _ActIcon(icon: CupertinoIcons.film, label: 'Bande-annonce', onTap: () => launchUrl(Uri.parse('https://www.youtube.com/watch?v=${fi.trailer}'), mode: LaunchMode.externalApplication)),
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
                  if (Connect.canSend && !Connect.tvNow)
                    _ActIcon(
                      icon: CupertinoIcons.tv,
                      label: 'Sur la télé',
                      onTap: () => _sendTv(it.kind == Kind.vod
                          ? (old ?? Prog(kind: 'vod', id: cur.id, ext: cur.ext, name: it.title, icon: it.icon))
                          : (lastProg ?? (eps.isEmpty ? null : _epProg(([...eps]..sort((a, b) => a.season != b.season ? a.season.compareTo(b.season) : a.number.compareTo(b.number))).first)))),
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
            if (vs.length > 1) ...[
              const SizedBox(height: 6),
              Chips(labels: [for (final v in vs) '${v.quality.isEmpty ? 'HD' : v.quality} · ${v.ext}'], selected: ver.clamp(0, vs.length - 1), onSelect: (i) => setState(() => ver = i)),
            ],
            if (error != null) Padding(padding: const EdgeInsets.all(20), child: Text(error!, style: T(14, color: const Color(0xFFFF6B7A)))),
            if (it.kind == Kind.series && eps.isNotEmpty) ...[
              const SectionTitle('Épisodes'),
              Chips(labels: [for (final s in seasons) 'Saison $s'], selected: seasons.indexOf(season).clamp(0, seasons.length - 1), onSelect: (v) => setState(() => season = seasons[v])),
              for (final e in eps.where((e) => e.season == season))
                FocusCard(
                  radius: 14,
                  onTap: () => _playEp(e),
                  child: Container(
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x14FFFFFF), width: 0.6))),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(children: [
                      SizedBox(width: 34, child: Text('${e.number}', style: T(20, w: 750, color: kMut))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.title.isEmpty ? 'Épisode ${e.number}' : e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(15.5, w: 600))),
                      const Ic('play', size: 20, color: kMut),
                    ]),
                  ),
                ),
            ],
            if (fi != null && fi.cast.isNotEmpty)
              Rail(
                title: 'Casting',
                height: 150,
                count: fi.cast.length,
                moreLabel: '',
                builder: (_, i) => SizedBox(
                  width: 86,
                  child: Column(children: [
                    ClipOval(child: SizedBox(width: 76, height: 76, child: fi.cast[i].photo.isEmpty ? Container(color: kBg3) : netImage(tmImg(fi.cast[i].photo, 'w185'), ''))),
                    const SizedBox(height: 8),
                    Text(fi.cast[i].name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(12.5, w: 650, h: 1.2)),
                    Text(fi.cast[i].role, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(11.5, color: kMut)),
                  ]),
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
  const PlayerScreen({super.key, required this.url, required this.title, this.prog, this.alts = const [], this.next = const [], this.zap = const [], this.zapAt = 0, this.x, this.tmdb});
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
  late final Player player = Player(configuration: PlayerConfiguration(bufferSize: Perf.lite ? 16 * 1024 * 1024 : 32 * 1024 * 1024));
  late final VideoController controller = VideoController(player);
  Timer? _t;
  int _alt = 0;
  int _hint = 0;
  late List<(String, String)> _alts = widget.alts;
  late int _zi = widget.zapAt;
  String _epgLine = '';
  Timer? _banner;
  StreamSubscription<Tracks>? _tr;
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
  StreamSubscription<bool>? _endSub;
  Timer? _watch;
  String? _fail;
  String _cur = '';
  int _silent = 0;
  DateTime _openedAt = DateTime.now();
  final FocusNode _retryNode = FocusNode(debugLabel: 'réessayer');
  final FocusNode _main = FocusNode(debugLabel: 'lecteur');     // zapping haut / bas, retrouvé après « Réessayer »
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
  Future<void> _bufferLive() async {
    try {
      final n = player.platform as NativePlayer;
      await n.setProperty('cache', 'yes');
      await n.setProperty('demuxer-max-bytes', Perf.lite ? '40MiB' : '200MiB');
      await n.setProperty('demuxer-max-back-bytes', Perf.lite ? '40MiB' : '200MiB');
      await n.setProperty('demuxer-readahead-secs', Perf.lite ? '120' : '600');
    } catch (_) {}
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
      if (Connect.canSend && !Connect.tvNow) (CupertinoIcons.tv, 'Continuer sur la télé', _toTv),
      if (!kIsWeb && Platform.isAndroid && Device.touch) (CupertinoIcons.rectangle_on_rectangle, 'Mini-fenêtre', () => _pip.invokeMethod('enter').catchError((_) {})),
    ];
    final i = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: kBg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          for (var k = 0; k < items.length; k++) ListTile(autofocus: k == 0, leading: Icon(items[k].$1), title: Text(items[k].$2), onTap: () => Navigator.pop(context, k)),
          const SizedBox(height: 8),
        ]),
      ),
    );
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
    if (kIsWeb || !Platform.isAndroid || !Device.tv || _fpsFor == _openedAt.millisecondsSinceEpoch) return;
    try {
      final v = await (player.platform as NativePlayer).getProperty('container-fps');
      final f = double.tryParse(v) ?? 0;
      if (f < 10 || f > 120) return;
      _fpsFor = _openedAt.millisecondsSinceEpoch;
      await _fpsCh.invokeMethod('set', f);
    } catch (_) {}
  }

  /// ouvre un flux et surveille qu'il démarre (rien au bout de 15 s = échec)
  void _open(String url) {
    _cur = url;
    _openedAt = DateTime.now();
    if (_fail != null) {
      setState(() => _fail = null);
      _main.requestFocus();
    }
    _watch?.cancel();
    _watch = Timer(const Duration(seconds: 15), () {
      if (!mounted || _fail != null) return;
      if (player.state.position == Duration.zero && player.state.duration == Duration.zero) _failed('Le flux ne démarre pas.');
    });
    player.open(Media(url));
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
    Journal.add('Lecture impossible : $why');
    setState(() => _fail = why);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _fail != null) _retryNode.requestFocus();
    });
  }

  void _retryNow() {
    _silent = 0;
    _open(_cur);
  }

  void _otherQuality() {
    if (_alts.length < 2) return;
    _silent = 0;
    setState(() => _alt = (_alt + 1) % _alts.length);
    _open(_alts[_alt].$2);
  }

  void _playNext() {
    if (_n >= widget.next.length || !mounted) return;
    _save();
    final nx = widget.next[_n++];
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
    _silent = 0;
    _open(c.alts.first.$2);
    _banner?.cancel();
    _banner = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showTitle = false);
    });
  }

  /// langues préférées retenues d'une fois sur l'autre
  void _applyPrefs(Tracks t) {
    if (_trSet) return;
    final a = t.audio.where((x) => x.id != 'auto' && x.id != 'no').toList();
    final s = t.subtitle.where((x) => x.id != 'auto' && x.id != 'no').toList();
    if (a.isEmpty && s.isEmpty) return;
    _trSet = true;
    final pa = Store.str('pref_aud'), ps = Store.str('pref_sub');
    if (pa.isNotEmpty) {
      final m = a.where((x) => (x.language ?? '').toLowerCase().startsWith(pa)).firstOrNull;
      if (m != null) player.setAudioTrack(m);
    }
    if (ps == 'no') {
      player.setSubtitleTrack(SubtitleTrack.no());
    } else if (ps.isNotEmpty) {
      final m = s.where((x) => (x.language ?? '').toLowerCase().startsWith(ps)).firstOrNull;
      if (m != null) player.setSubtitleTrack(m);
    }
  }

  void _tracks() {
    final t = player.state.tracks;
    final a = t.audio.where((x) => x.id != 'auto' && x.id != 'no').toList();
    final s = t.subtitle.where((x) => x.id != 'auto' && x.id != 'no').toList();
    String lab(String? lang, String? title, int i) => [if (lang != null && lang.isNotEmpty) lang.toUpperCase(), if (title != null && title.isNotEmpty) title].join(' · ').isEmpty ? 'Piste ${i + 1}' : [if (lang != null && lang.isNotEmpty) lang.toUpperCase(), if (title != null && title.isNotEmpty) title].join(' · ');
    final ca = player.state.track.audio, cs = player.state.track.subtitle;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1D26),
      builder: (_) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), children: [
          Text('Audio', style: T(18, w: 750)),
          if (a.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text('Une seule piste', style: T(14, color: kMut))),
          for (var i = 0; i < a.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(lab(a[i].language, a[i].title, i) + (a[i].id == ca.id ? '  ✓' : ''), style: T(15.5, w: 600)),
              onTap: () {
                player.setAudioTrack(a[i]);
                Store.setStr('pref_aud', (a[i].language ?? '').toLowerCase());
                Navigator.pop(context);
              },
            ),
          const SizedBox(height: 10),
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
              title: Text(lab(s[i].language, s[i].title, i) + (s[i].id == cs.id ? '  ✓' : ''), style: T(15.5, w: 600)),
              onTap: () {
                player.setSubtitleTrack(s[i]);
                Store.setStr('pref_sub', (s[i].language ?? '').toLowerCase());
                Navigator.pop(context);
              },
            ),
        ]),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showTitle = false);
    });
    if (!kIsWeb && Platform.isAndroid && Device.touch) _pip.invokeMethod('arm', true).catchError((_) {});
    _tr = player.stream.tracks.listen(_applyPrefs);
    if (widget.zap.isNotEmpty) {
      final e = widget.zap[_zi].epg.isEmpty ? null : Epg.now(widget.zap[_zi].epg);
      if (e != null) _epgLine = '${e.title} · encore ${e.leftMin} min';
      final c0 = widget.zap[_zi];
      Epg.want(c0.epg, [c0.sid]).then((_) {
        final n = c0.epg.isEmpty ? null : Epg.now(c0.epg);
        if (mounted && n != null) setState(() => _epgLine = '${n.title} · encore ${n.leftMin} min');
      });
    }
    _errSub = player.stream.error.listen((e) {
      Journal.add('Lecteur', e);
      // certaines erreurs ne sont pas bloquantes : échec seulement si la lecture avait démarré et n'avance plus
      // (au démarrage, c'est la surveillance des 15 s qui tranche)
      final at = player.state.position;
      Timer(const Duration(seconds: 4), () {
        if (mounted && at > Duration.zero && player.state.position == at) _failed('Le flux a été interrompu.');
      });
    });
    _endSub = player.stream.completed.listen((c) {
      if (c && _live) _failed('Le direct s\'est interrompu.');     // un direct ne « finit » pas : c'est une coupure
    });
    if (_live) _bufferLive();
    _posSub = player.stream.position.listen(_onPos);
    Connect.inPlayer = true;
    Connect.player.addListener(_remoteCtl);
    unawaited(_loadSegs());
    _vp = player.stream.videoParams.listen((_) => _matchFps());
    _open(widget.url);
    if (widget.next.isNotEmpty && Store.flag('autonext')) _done = player.stream.completed.listen((c) { if (c) _playNext(); });
    final p = _prog;
    if (p != null) {
      if (p.pos > 20000) {
        final start = p.pos;
        // le flux peut se fermer avant (écran quitté) : pas d'erreur non gérée
        player.stream.duration.firstWhere((d) => d > Duration.zero).then((_) => player.seek(Duration(milliseconds: start))).catchError((_) {});
      }
      _t = Timer.periodic(const Duration(seconds: 10), (_) => _save());
    }
  }

  void _save() {
    final p = _prog;
    if (p == null) return;
    final pos = player.state.position.inMilliseconds, dur = player.state.duration.inMilliseconds;
    if (pos > 20000) {
      p.pos = pos;
      p.dur = dur;
      p.t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      p.hidden = false;
      Store.saveProg(p);
    }
  }

  @override
  void dispose() {
    _vp?.cancel();
    _posSub?.cancel();
    Connect.inPlayer = false;
    Connect.player.removeListener(_remoteCtl);
    _skipNode.dispose();
    if (!kIsWeb && Platform.isAndroid && Device.tv) _fpsCh.invokeMethod('set', 0.0).catchError((_) {});
    _save();
    _t?.cancel();
    _done?.cancel();
    _errSub?.cancel();
    _endSub?.cancel();
    _watch?.cancel();
    _retryNode.dispose();
    _main.dispose();
    _tr?.cancel();
    _banner?.cancel();
    _first.dispose();
    if (!kIsWeb && Platform.isAndroid && Device.touch) _pip.invokeMethod('arm', false).catchError((_) {});
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
        focusNode: _main,
        autofocus: true,
        onKeyEvent: (node, e) {
          if (e is! KeyDownEvent) return KeyEventResult.ignored;
          final k = e.logicalKey;
          final onBar = FocusManager.instance.primaryFocus != node;
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
      );

  Widget _scaffold(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Video(controller: controller),
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
                    child: Text('${_fail!} Vérifie ta connexion ; le serveur peut aussi être saturé.', textAlign: TextAlign.center, style: T(15, color: kMut, h: 1.4)),
                  ),
                  const SizedBox(height: 20),
                  Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
                    _OvBtn(node: _retryNode, label: 'Réessayer', primary: true, onTap: _retryNow),
                    if (_alts.length > 1) _OvBtn(label: 'Autre qualité', onTap: _otherQuality),
                    _OvBtn(label: 'Retour', onTap: () => Navigator.maybePop(context)),
                  ]),
                ]),
              ),
            ),
          if (_skipLabel != null && _fail == null)
            Positioned(right: 28, bottom: 110, child: _OvBtn(node: _skipNode, label: _skipLabel!, primary: true, onTap: _doSkip)),
          // titre, affiché quelques secondes au démarrage
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 64,
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
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: _TopBtn(node: _first, icon: CupertinoIcons.chevron_back, tip: 'Retour', onTap: () => Navigator.maybePop(context)),
          ),
          Positioned(
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
              _TopBtn(icon: CupertinoIcons.captions_bubble, tip: 'Audio et sous-titres', onTap: _tracks),
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
