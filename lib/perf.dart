/// mode léger : activé sur les boîtiers Android TV modestes (1 Go de mémoire) — images décodées plus petites, caches plus courts,
/// pas de flou ni d'ombres portées ni d'animations d'ambiance, lectures du catalogue et du guide plafonnées
/// Famille d'appareil. « tv » = Android TV / Google TV / Fire TV (télécommande, mode léger, mises en page de salon) ;
/// tout le reste (iPhone, iPad, téléphones et tablettes Android) est tactile et reçoit exactement le même traitement et les mêmes fonctions.
class Device {
  static bool tv = false;
  static bool get touch => !tv;
}

class Perf {
  static bool get lite => Device.tv;

  /// largeur de décodage d'une image (pixels)
  static int img(int w) => lite ? (w * 0.6).round() : w;
}
