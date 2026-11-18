# Familles d'appareils

Le code distingue deux familles, via `Device` (lib/perf.dart), fixée au démarrage (lib/main.dart) :

| Famille | Appareils | Traitement |
|---|---|---|
| **Tactile** (`Device.touch`) | iPhone, iPad, téléphones et tablettes Android, web | Mêmes fonctions et même comportement partout. Seule la mise en page s'adapte à la largeur (barre d'onglets en bas ou en haut). |
| **Télé** (`Device.tv`) | Android TV, Google TV, Fire TV (APK) | Mode léger (`Perf.lite`) : pas de flou, pas d'ombres, images plus petites, caches courts, pas de défilement automatique. Mises en page « salon » : réglages en deux colonnes, fiche film plein écran, écran de démarrage en deux colonnes, accueil à un seul bouton (OK = lecture, appui long = détails). Saisie des identifiants depuis le téléphone (QR), reçoit les commandes de Connect, adaptation de la cadence d'images. |

Fonctions **réservées au tactile** : mini-fenêtre (PiP), « Connecter une télé » (saisie du code), Télécommande (Connect), Envoyer sur la télé.
Fonctions **réservées à la télé** : QR de saisie depuis le téléphone, réception des commandes par défaut, cadence d'images (Android 6+), mode léger.

Détection (`Connect.isTv`, canal `minou/pip` côté Android) : mode d'interface télévision, ou fonction « leanback », ou matériel télévision. Tout le reste est tactile.
Ne pas utiliser la largeur d'écran pour décider d'un comportement télé : un iPad ou une tablette Android ne doit pas recevoir les mises en page de la télé.
