import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:media_kit/media_kit.dart';
import 'pairing.dart';
import 'account_ui.dart';
import 'auth.dart';
import 'connect.dart';
import 'epg.dart';
import 'ui.dart';
import 'extras.dart';
import 'journal.dart';
import 'screens.dart';
import 'sync.dart';
import 'tmdb.dart';
import 'store.dart';
import 'xtream.dart';

void main() {
  // erreurs non gérées : notées dans le journal local (sans identifiants), l'appli continue
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Journal.init();
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      Journal.add('Erreur d\'affichage', d.exception, d.stack);
      prev?.call(d);
    };
    if (!kIsWeb) MediaKit.ensureInitialized();
    await Store.init();
    L.init();
    Device.tv = await Connect.isTv() || (kIsWeb && Uri.base.queryParameters['tv'] == '1');     // télé Android : mode léger (sans flou, sans défilement automatique) et mises en page de salon
    if (Perf.lite) {
      PaintingBinding.instance.imageCache
        ..maximumSizeBytes = 36 << 20     // 36 Mo d'images décodées au lieu de 100
        ..maximumSize = 120;
    }
    Store.onSourceChanged = () {
      Tmdb.reset();
      Calendar.reset();
      Epg.reset();
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
  static Future<void> _onLink(Uri u) async {
    if (u.scheme != 'minouflix' || u.host != 'pair' || _linkBusy) return;
    final code = Pairing.norm(u.queryParameters['c'] ?? '');
    final ctx = navKey.currentContext;
    if (code.length != 8 || ctx == null) return;
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
      }
      final c2 = navKey.currentContext;
      if (c2 != null && c2.mounted) ScaffoldMessenger.maybeOf(c2)?.showSnackBar(SnackBar(content: Text(e ?? 'Envoyé : la télé se connecte.')));
    } finally {
      _linkBusy = false;
    }
  }

  static void listenLinks() {
    if (kIsWeb) return;
    try {
      final al = AppLinks();
      al.uriLinkStream.listen(_onLink, onError: (_) {});
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
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  Creds? creds;
  bool loaded = false;
  bool pick = false;      // « Changer les catégories » depuis les réglages
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
    if (Account.signedIn && creds == null) {
      final c = await Sync.cloudCreds();
      if (c != null) {
        await Store.saveCreds(c);
        await Sync.run();      // nouvel appareil : retrouve aussi les autres sources, les catégories choisies, les réglages et les playlists
        if (mounted) setState(() => creds = c);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Scaffold(body: Center(child: Spinner()));
    if (!authed) return AuthScreen(onDone: _afterAuth);
    if (creds == null) return LoginScreen(onDone: (c) => setState(() => creds = c));
    if (Account.signedIn && !Store.syncAsked) return SyncChoiceScreen(onDone: () => setState(() {}));
    if (!Store.hasSelection || pick) {
      // la sélection actuelle reste en place tant que la nouvelle n'est pas validée (Retour = annuler)
      return CategoriesScreen(creds: creds!, onDone: () => setState(() => pick = false), onCancel: Store.hasSelection ? () => setState(() => pick = false) : null, onEditSource: Store.hasSelection ? null : () => setState(() => creds = null));
    }
    return HomeScreen(
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
