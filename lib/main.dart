import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:media_kit/media_kit.dart';
import 'pairing.dart';
import 'rights.dart';
import 'account_ui.dart';
import 'auth.dart';
import 'connect.dart';
import 'epg.dart';
import 'ui.dart';
import 'extras.dart';
import 'journal.dart';
import 'perf_log.dart';
import 'screens.dart';
import 'sync.dart';
import 'tmdb.dart';
import 'store.dart';
import 'names.dart';
import 'intro.dart';
import 'onboarding.dart';
import 'xtream.dart';

void main() {
  // erreurs non gérées : notées dans le journal local (sans identifiants), l'appli continue
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Journal.init();
    await ChanLogos.load();
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      Journal.add('Erreur d\'affichage', d.exception, d.stack);
      prev?.call(d);
    };
    if (!kIsWeb) MediaKit.ensureInitialized();
    await Store.init();
    await Perf.detect();
    PerfLog.start();
    unawaited(Rights.load());
    L.init();
    Device.tv = await Connect.isTv() || (kIsWeb && Uri.base.queryParameters['tv'] == '1');     // télé Android : mode léger (sans flou, sans défilement automatique) et mises en page de salon
    if (Perf.lite) {
      PaintingBinding.instance.imageCache
        ..maximumSizeBytes = (Perf.tight ? 20 : 36) << 20     // 36 Mo d'images décodées au lieu de 100 (20 Mo si moins de 1,3 Go de mémoire)
        ..maximumSize = Perf.tight ? 70 : 120;
    }
    Journal.add('Appareil : ${Perf.ramMb} Mo de mémoire, mode ${Perf.tight ? 'très léger' : (Perf.lite ? 'léger' : 'complet')}');
    Store.onSettingsApplied = () => Aurora.tick.value++;
    Store.onSourceChanged = () {
      Tmdb.reset();
      Calendar.reset();
      Epg.reset();
      CachedFuture.clear();
    };
    await Account.load();
    await Downloads.init();
    await demoSetup();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    runApp(const MinouFlix());
    MinouFlix.listenLinks();
  }, (e, st) => Journal.add('Erreur', e, st));
}

class MinouFlix extends StatelessWidget {
  const MinouFlix({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(valueListenable: L.changed, builder: (_, lang, __) => _app(lang));

  /// changer de langue relance l'interface (clé = langue) : tous les textes se retraduisent
  static final navKey = GlobalKey<NavigatorState>();
  static bool _linkBusy = false;

  /// minouflix://pair?c=CODE (QR de la télé) : une confirmation, puis le compte et les sources partent vers la télé
  static String _lastCode = '';
  static DateTime _lastAt = DateTime(2000);
  static String _lastReset = '';
  /// lien reçu par e-mail (minouflix://reset#access_token=…&type=recovery) : mot de passe oublié, ou confirmation du compte
  static Future<void> _onReset(Uri u, [int tries = 0]) async {
    final f = u.fragment.isNotEmpty ? u.fragment : u.query;
    final p = f.isEmpty ? <String, String>{} : Uri.splitQueryString(f);
    final ctx = navKey.currentContext;
    if (ctx == null || !Boot.ready) {
      if (tries < 30) Future.delayed(const Duration(milliseconds: 500), () => _onReset(u, tries + 1));
      return;
    }
    final key = p['access_token'] ?? p['error_code'] ?? p['type'] ?? '';
    if (key == _lastReset) return;      // le même lien arrive parfois deux fois
    _lastReset = key;
    if (p['error'] != null || p['error_description'] != null) {
      await showDialog<void>(context: ctx, builder: (c) => AppDialog(title: Text('Lien expiré', style: T(18, w: 700)), content: const Text('Ce lien n\'est plus valable (une seule utilisation, une heure). Demande-en un nouveau avec « Mot de passe oublié ? ».'), actions: [TextButton(autofocus: true, onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
    } else if (p['type'] == 'recovery' && (p['access_token'] ?? '').isNotEmpty) {
      await Navigator.push(ctx, softRoute((_) => NewPasswordScreen(token: p['access_token']!)));
    } else if (p['type'] == 'signup' || p['type'] == 'email_change') {
      await showDialog<void>(context: ctx, builder: (c) => AppDialog(title: Text('Adresse confirmée', style: T(18, w: 700)), content: const Text('Ton adresse e-mail est confirmée. Tu peux te connecter.'), actions: [TextButton(autofocus: true, onPressed: () => Navigator.pop(c), child: const Text('OK'))]));
    }
  }

  static Future<void> _onLink(Uri u, [int tries = 0]) async {
    if (u.scheme == 'minouflix' && u.host == 'reset') return _onReset(u);
    if (u.scheme == 'minouflix' && u.host == 'resume') {
      Store.pendingResume = u.queryParameters['k'];
      Store.resumeTick.value++;
      return;
    }
    if (u.scheme != 'minouflix' || u.host != 'pair') return;
    final code = Pairing.norm(u.queryParameters['c'] ?? '');
    if (code.length != 8) return;
    if (tries == 0) Journal.add('Lien reçu');
    if (_linkBusy) {
      if (tries < 30) Future.delayed(const Duration(milliseconds: 500), () => _onLink(u, tries + 1));
      return;
    }
    // démarrage à froid : l'appli n'est pas encore prête (écran d'accueil, compte) ; on réessaie jusqu'à 15 s
    final ctx = navKey.currentContext;
    if (ctx == null || !Boot.ready) {
      if (tries < 30) Future.delayed(const Duration(milliseconds: 500), () => _onLink(u, tries + 1));
      return;
    }
    if (_lastCode == code && DateTime.now().difference(_lastAt) < const Duration(seconds: 4)) return;      // le même lien arrive parfois deux fois
    _linkBusy = true;
    try {
      String? e;
      if (!Account.signedIn) {
        e = 'Connecte-toi d\'abord à ton compte MinouFlix, puis scanne à nouveau le code.';
      } else {
        final ok = await showDialog<bool>(
          context: ctx,
          builder: (c) => AppDialog(
            title: Text('Connecter la télé ?', style: T(18, w: 700)),
            content: Text('Ton compte et tes sources seront envoyés à la télé (${Pairing.show(code)}).'),
            actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Connecter'))],
          ),
        );
        if (ok != true) return;
        e = await Pairing.send(code);
        _lastCode = code;
        _lastAt = DateTime.now();
      }
      final c2 = navKey.currentContext;
      // résultat toujours visible (une petite fenêtre, pas un message qui disparaît) : on sait si ça a marché
      if (c2 != null && c2.mounted) {
        await showDialog<void>(
          context: c2,
          builder: (c) => AppDialog(
            title: Text(e == null ? 'Envoyé ✓' : 'Envoi impossible', style: T(18, w: 700)),
            content: Text(e ?? 'La télé se connecte, quelques secondes.'),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
      }
    } finally {
      _linkBusy = false;
    }
  }

  static void listenLinks() {
    if (kIsWeb) return;
    try {
      final al = AppLinks();
      al.uriLinkStream.listen((u) => _onLink(u), onError: (_) {});
      Future.delayed(const Duration(seconds: 2), () async {
        final first = await al.getInitialLink();
        if (first != null) _onLink(first);
      });
    } catch (_) {}
  }

  Widget _app(String lang) => MaterialApp(
        key: ValueKey(lang),
        locale: Locale(lang),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        title: 'MinouFlix',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          fontFamily: kFont,
          scaffoldBackgroundColor: const Color(0xFF06080D),
          canvasColor: const Color(0xFF06080D),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B8CFF), brightness: Brightness.dark, surface: const Color(0xFF0E121B)),
          focusColor: const Color(0x40FFFFFF),
          listTileTheme: const ListTileThemeData(minVerticalPadding: 10),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0x2EFFFFFF),
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: Device.tv ? 20 : 15),
            labelStyle: const TextStyle(color: Color(0xFF9AA3B5)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF5B8CFF), width: 2.5)),
          ),
          // menus et messages façon iOS : angles larges, fond sombre translucide, filet fin
          popupMenuTheme: PopupMenuThemeData(
            color: const Color(0xF01B1F2A),
            elevation: 8,
            shadowColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0x1FFFFFFF), width: .6)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFFEEF2F8)),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xF0222736),
            contentTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFEEF2F8)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        // la télécommande Android TV : la touche OK (select) active l'élément sélectionné
        // taille de texte du système respectée, bornée pour ne rien casser
        builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: MediaQuery.of(ctx).textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3)), child: child ?? const SizedBox.shrink()),
        shortcuts: {...WidgetsApp.defaultShortcuts, const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent()},
        navigatorKey: navKey,
        home: const Boot(),
      );
}

/// Choisit l'écran de départ : identifiants → sélection des catégories → catalogue.
class Boot extends StatefulWidget {
  static bool ready = false;      // l'écran de départ est affiché (les liens d'ouverture peuvent s'afficher)
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Boot.ready = true;
  }

  Creds? creds;
  bool loaded = false;
  bool _splashDone = false;      // l'écran de chargement a déjà quitté l'accueil une fois (pas de retour de l'écran à chaque changement de source)
  bool pick = false;      // « Changer les catégories » depuis les réglages
  bool restoring = false;
  bool authed = _authed();   // sinon : écran de connexion
  static bool _authed() => Account.signedIn || _demo.isNotEmpty || Store.flag('noacct', false);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    creds = await Store.creds();
    if (mounted) setState(() => loaded = true);
  }

  /// source ajoutée, activée ou supprimée : on relit les identifiants de la source active et on repart de zéro
  Future<void> _switched() async {
    final c = await Store.creds();
    if (!mounted) return;
    setState(() {
      creds = c;
      pick = false;
    });
  }

  /// compte connecté : on retrouve les identifiants IPTV chiffrés du compte, s'ils y sont
  Future<void> _afterAuth() async {
    creds ??= await Store.creds();
    if (!mounted) return;
    setState(() => authed = true);
    if (Account.signedIn) {
      // même compte = mêmes réglages : on les récupère avant de décider quoi afficher (15 s au plus)
      setState(() => restoring = true);
      try {
        final c = creds == null ? await Sync.cloudCreds() : null;
        if (c != null) {
          await Store.saveCreds(c);
          creds = c;
        }
        final first = !Store.flag('acct_known', false);
        await Sync.run(fresh: first).timeout(const Duration(seconds: 40), onTimeout: () => false);
        // compte déjà configuré sur un autre appareil : jamais de configuration d'office, on garde exactement ses réglages
        if (Store.flag('acct_known', false) && !Store.flag('onb_done', false)) await Store.setFlag('onb_done', true);
      } catch (_) {}
      if (mounted) setState(() => restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const BrandIntro();
    if (restoring) return const BrandIntro();
    if (!authed) return AuthScreen(onDone: _afterAuth);
    if (creds == null) return LoginScreen(onDone: (c) => setState(() => creds = c));
    if (Account.signedIn && !Store.syncAsked) return SyncChoiceScreen(onDone: () => setState(() {}));
    // nouveau compte : parcours de configuration (langue, version, goûts) avant le choix des catégories ; reprise si interrompu
    // compte déjà connu du serveur : jamais de configuration d'office (elle reste dans Réglages)
    // connecté : configuration seulement si le serveur a répondu et que le compte est vide (réseau lent ou absent : jamais)
    final fresh = Account.signedIn ? (Sync.pulled && !Store.flag('acct_known', false)) : Store.settingsT == 0;
    if (!Store.hasSelection && !pick && !Store.flag('onb_done', false) && (fresh || Store.str('onb_state').isNotEmpty)) {
      return OnboardingFlow(onDone: () => setState(() {}));
    }
    if (!Store.hasSelection || pick) {
      // la sélection actuelle reste en place tant que la nouvelle n'est pas validée (Retour = annuler)
      return CategoriesScreen(creds: creds!, onDone: () => setState(() => pick = false), onCancel: Store.hasSelection ? () => setState(() => pick = false) : null, onEditSource: Store.hasSelection ? null : () => setState(() => creds = null));
    }
    final home = HomeScreen(
      key: ValueKey('h${Store.activeId}_${Store.profId}'),
      creds: creds!,
      onSwitch: _switched,
      onReset: () => setState(() => creds = null),
      onChangeSelection: () => setState(() => pick = true),
      onWipe: () => setState(() {
        creds = null;
        authed = _authed();
      }),
    );
    // animation d'ouverture à durée fixe par-dessus l'accueil, qui se prépare derrière : il apparaît d'un coup, sans se remplir à vue d'œil
    return Stack(fit: StackFit.expand, children: [
      home,
      if (!_splashDone) LaunchIntro(onDone: () => mounted ? setState(() => _splashDone = true) : null),
    ]);
  }
}

/// Version de contrôle (compilation web, serveur de démonstration local) : connexion et catégories automatiques.
const _demo = String.fromEnvironment('DEMO_SERVER');

Future<void> demoSetup() async {
  if (_demo.isEmpty || Store.hasSelection) return;
  final c = Creds(_demo, 'demo', 'demo');
  await Store.saveCreds(c);
  await Store.setName('Romain');
  final x = Xtream(c);
  for (final k in Kind.values) {
    final cs = await x.categories(k);
    await Store.saveSelection(k, [for (final e in cs) e.id]);
    await Store.saveCatNames(k, {for (final e in cs) e.id: e.name});
  }
}
