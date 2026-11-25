import 'dart:io';
import 'package:flutter/foundation.dart';

/// mode léger : activé sur les boîtiers Android TV modestes (1 Go de mémoire) — images décodées plus petites, caches plus courts,
/// pas de flou ni d'ombres portées ni d'animations d'ambiance, lectures du catalogue et du guide plafonnées
/// Famille d'appareil. « tv » = Android TV / Google TV / Fire TV (télécommande, mode léger, mises en page de salon) ;
/// tout le reste (iPhone, iPad, téléphones et tablettes Android) est tactile et reçoit exactement le même traitement et les mêmes fonctions.
class Device {
  static bool tv = false;
  static bool get touch => !tv;
}

class Perf {
  /// mémoire totale de l'appareil en Mo (0 = inconnue) : lue au démarrage ; sous 1,6 Go, mode léger même sur un téléphone ; sous 1,3 Go, caches réduits
  static int ramMb = 0;
  static bool get tight => ramMb > 0 && ramMb < 1300;
  static bool get lite => Device.tv || (ramMb > 0 && ramMb < 1600);

  static Future<void> detect() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      for (final l in await File('/proc/meminfo').readAsLines()) {
        if (l.startsWith('MemTotal:')) {
          ramMb = (int.parse(l.replaceAll(RegExp(r'[^0-9]'), '')) / 1024).round();
          break;
        }
      }
    } catch (_) {}
  }

  /// largeur de décodage d'une image (pixels)
  static int img(int w) => lite ? (w * 0.6).round() : w;
}
