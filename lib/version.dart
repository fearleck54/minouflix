/// numéro de version (mis à jour à chaque compilation) ; l'appli Android compare avec version.json du Pi
const kBuild = 204;
/// adresse des mises à jour hors store : fournie à la compilation (`--dart-define=UPDATE_URL=...`), vide = aucune
const kUpdateBase = String.fromEnvironment('UPDATE_URL');
/// version « store » (Play Store / App Store) : `--dart-define=STORE=true` à la compilation
/// pas de mise à jour par APK, pas de plateformes ni de logos, pas de lancement de chaîne depuis un match
const kStore = bool.fromEnvironment('STORE');
