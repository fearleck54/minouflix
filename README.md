# MinouFlix (autonome)

Appli IPTV sans serveur : iOS/iPadOS (IPA via SideStore) et Android TV (APK). Flutter + libmpv (media_kit).

- Identifiants saisis par l'utilisateur, chiffrés sur l'appareil (Keychain / Keystore). Aucun code en dur.
- Après la connexion : choix des catégories (direct / films / séries), pré-cochage des catégories françaises.
  Seules les catégories cochées sont téléchargées (`get_*_streams&category_id=…`), le reste n'est jamais chargé.
- Compilation : GitHub Actions (`.github/workflows/build.yml`) génère `minouflix-apk` et `minouflix-ipa` (non signée).
  Les dossiers `android/` et `ios/` sont créés par la CI (`flutter create`), seul `lib/` est versionné.

Étapes suivantes : compte + synchronisation de la reprise entre appareils, profils, guide TV, sport, affiches TMDB, mode D-pad soigné.

## Version « store » (Play Store / App Store)

Même code, compilé avec `--dart-define=STORE=true` (constante `kStore` de `lib/version.dart`) :
pas de mise à jour par APK, pas de rangée « Plateformes » ni de logos de plateformes/studios, le Sport reste un calendrier
(aucune chaîne lancée depuis un match), pas de pré-cochage d'après les noms de chaînes payantes.

- Android : `flutter build appbundle --release --dart-define=STORE=true`
- iOS : `flutter build ipa --release --dart-define=STORE=true` (signature App Store requise)

Les compilations habituelles (`build.yml`) restent la version famille (`STORE` absent = faux).

## Tests

`flutter test` (dossier `test/` : noms des fournisseurs, code enfant, journal sans identifiants). En CI, l'étape de tests
du job Android ne bloque pas la compilation.
