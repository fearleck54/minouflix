# MinouFlix : politique de confidentialité

Dernière mise à jour : 20 novembre 2026. Même texte que l'écran « Confidentialité » de l'appli (Réglages > À propos).

## En bref

MinouFlix est un lecteur : il ne fournit aucun contenu. Aucune publicité, aucun pistage, aucune donnée vendue ni partagée à des fins commerciales.

## Ce qui reste sur l'appareil

- Identifiants de l'abonnement IPTV : chiffrés par le trousseau de l'iPhone (Keychain) ou le Keystore Android.
- Catalogue et images en cache, téléchargements, réglages, code du mode enfant.
- Journal d'erreurs local : sans identifiants ni adresses complètes (les adresses sont réduites au nom du serveur). Il ne quitte jamais l'appareil, sauf si l'utilisateur le copie lui-même.

## Avec un compte MinouFlix (facultatif)

- E-mail et mot de passe : servent à la connexion (hébergement du compte : Supabase).
- Selon les choix de l'utilisateur (« Compte et synchronisation ») : Ma liste, reprise de lecture, prénom et championnats suivis.
- Identifiants IPTV (option désactivée par défaut) : chiffrés sur l'appareil (AES-256-GCM) avec une clé dérivée du mot de passe ; le serveur ne peut pas les lire.

## Services contactés

| Service | Pourquoi | Ce qui est envoyé |
|---|---|---|
| Fournisseur IPTV de l'utilisateur | Catalogue et lecture | Identifiants saisis par l'utilisateur, directement depuis l'appareil |
| TMDB | Affiches, résumés, distribution | Titre recherché (aucune donnée personnelle) |
| Calendrier sportif | Matchs des championnats choisis | Championnats demandés |
| YouTube | Bandes-annonces | Identifiant de la vidéo |
| Supabase | Compte et synchronisation (si compte) | E-mail, données synchronisées choisies |
| Reconnaissance vocale du système (Apple ou Google) | Dicter une recherche, seulement si l'utilisateur appuie sur le micro | La voix, traitée par le service du système ; MinouFlix n'enregistre rien |

## Durée de conservation et suppression

- « Effacer mes données » : supprime tout ce que l'appli garde sur l'appareil.
- « Supprimer mon compte » : efface définitivement le compte et sa copie synchronisée sur le serveur.
- Sans action de l'utilisateur, les données du compte sont conservées tant que le compte existe.

## Fiches des stores

- App Store (« Confidentialité de l'app ») : Coordonnées (e-mail) et Contenu utilisateur (liste, reprise), liés à l'utilisateur, non utilisés pour le suivi.
- Play Store (« Sécurité des données ») : e-mail, activité dans l'appli (liste, reprise) ; chiffrées en transit ; suppression possible depuis l'appli.

## TMDB

Ce produit utilise l'API TMDB mais n'est ni approuvé ni certifié par TMDB.

## Contact

contact@fearleck.org
