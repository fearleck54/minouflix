# Publication App Store / Google Play : liste de contrôle

À relire avec les règles en vigueur au moment du dépôt (je ne les ai pas lues en entier : rien ci-dessous ne remplace Apple « App Review Guidelines » et Google « Developer Program Policy »).

## Positionnement (le point décisif)
- L'appli est **un lecteur** : aucune chaîne, aucun film, aucune liste fournis. L'utilisateur ajoute sa propre source (Xtream / M3U).
- Aucun nom de bouquet ou de fournisseur dans l'appli, les captures ou le texte du magasin. Pas de mot « gratuit », « pirate », « TV illimitée ».
- Les affiches / résumés viennent de TMDB : afficher la mention et le logo TMDB (obligation de leurs conditions).
- Le sport (ESPN) : données publiques, aucune retransmission fournie.

## Dossier commun
- Politique de confidentialité en ligne (compte e-mail, synchronisation, journal local, TMDB). Page à héberger (ex. ha.fearleck.org ou GitHub Pages).
- Adresse d'assistance, nom du développeur, icône 1024 px sans transparence.
- Comptes : Apple Developer (99 $/an), Google Play (25 $ une fois) : montants à vérifier.
- Compte de démonstration pour le relecteur + **une source de test légale** (flux libres de droits) à fournir dans les notes de relecture.
- Suppression du compte dans l'appli (déjà présente : Réglages) : exigée par Apple et Google.

## Apple (iPhone / iPad ; Apple TV = autre projet)
- Signature réelle (certificat distribution) à la place de SideStore ; build via CI macOS (déjà en place pour l'IPA).
- Notes de relecture : expliquer « lecteur, sans contenu », fournir identifiants de démo et source de test.
- Captures : iPhone 6,9" et 6,5", iPad 13" si compatible.
- Étiquettes de confidentialité (App Privacy) : e-mail, identifiant, données d'usage (si journal envoyé).
- Éviter : NSAllowsArbitraryLoads sans justification (nécessaire pour les serveurs IPTV en http : le justifier dans les notes), références à des contenus protégés.

## Google Play (téléphone + Android TV)
- Android App Bundle (.aab) signé avec la clé de dépôt (Play App Signing), pas l'APK.
- Questionnaires : classification du contenu, sécurité des données, public cible (pas « enfants » seulement).
- Android TV : bannière 320×180 (déjà générée), déclaration « leanback », navigation 100 % télécommande (banc d'essai : scripts/outils/tv_parcours.py), captures TV 1920×1080.
- Trafic http clair : justifier (serveurs IPTV des utilisateurs).
- Niveau d'API cible à jour (exigence annuelle de Google).

## À faire avant dépôt
1. Page de confidentialité + adresse d'assistance.
2. Mention TMDB dans Réglages › À propos.
3. Jeu de captures sans aucun nom de chaîne ou de bouquet réel.
4. Source de test légale + compte de démonstration.
5. Passage Apple : retirer SideStore de la chaîne de build ; Google : produire le .aab.

## Vérifié sur les sources officielles (19/11/2026)
- Google Play : 25 USD une fois. Compte personnel créé après le 13/11/2023 : test fermé avec ≥ 12 testeurs inscrits en continu pendant 14 jours avant l'accès à la production (https://support.google.com/googleplay/android-developer/answer/14151465). Compte organisation : exempté (D-U-N-S requis).
- Apple : 99 USD/an, identité légale, double authentification, nom légal affiché comme vendeur (https://developer.apple.com/programs/enroll/).
- Règle Apple 5.2.3 (streaming tiers) : refus fréquent si l'app « donne accès à des flux non autorisés ». Parades : notes de revue disant que l'app ne contient AUCUNE chaîne/catalogue et lit seulement les liens fournis par l'utilisateur ; aucun contenu fourni par défaut ; captures sans noms de chaînes.
- Google, politique propriété intellectuelle : pas de règle IPTV explicite ; cas Perfect Player / IPTV Smarters retirés sur plainte. Fiche et captures neutres.
