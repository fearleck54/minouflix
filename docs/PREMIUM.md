# MinouFlix : ce qui reste pour être digne d'un store

## État au 13/11/2026 (« Go tout pour premium »)

Légende : ✅ fait · 🟡 en partie · ⏳ à faire (code) · 👤 à faire par Romain

| # | Chantier | État |
|---|---|---|
| §0 | Variante store (`--dart-define=STORE=true`, voir README) : sans mise à jour APK, sans plateformes ni logos, Sport = calendrier, pré-cochage sans noms de chaînes | ✅ |
| §0 | Mention TMDB dans Réglages › À propos et dans Confidentialité | ✅ |
| §0 | Serveur de démonstration (flux libres) pour la review, captures neutres, retrait ESPN avant publication | 👤 |
| 1 | Journal d'erreurs local (Réglages › À propos : voir / copier), sans identifiants ni URL complètes | ✅ |
| 1 | Crash reporting externe (Sentry, Crashlytics) | ⏳ (compte externe) |
| 2 | Tests unitaires (`test/` : names, code enfant, journal) + étape `flutter test` non bloquante dans le job Android | 🟡 (pas de tests de widgets ni `flutter analyze`) |
| 3 | Session expirée en un geste, plus de mot de passe en clair pour l'appairage | ⏳ |
| 4 | Lecteur : message lisible + « Réessayer » / « Autre qualité » au lieu d'un écran noir, 1 reconnexion silencieuse du direct | ✅ (choix de piste par titre : ⏳) |
| 5 | Bannière « Hors ligne » sur l'accueil (échec réseau récent, bouton Réessayer) | ✅ |
| 6 | États vides illustrés (Ma liste, collections, recherche, Direct, Films/Séries) | ✅ |
| 7 | Squelettes fiche et recherche ; fondu des images (déjà présent) | ✅ (transition Hero : ⏳) |
| 8 | Haptique iPhone (onglets, favoris, boutons principaux) | ✅ |
| 9 | Commandes du lecteur repensées pour la télé | ⏳ |
| 10 | Icône, écran de lancement, captures | 👤 |
| 11 | Onboarding : étapes Compte → Source → Catégories, durée estimée (avant) puis mesurée (pendant le chargement) | ✅ |
| 12 | Import M3U/M3U8 | ⏳ (demande de découpler `Xtream` : pas fait pour ne rien casser) |
| 13 | Profils multiples | ⏳ |
| 14 | Guide TV en grille (Direct › Guide TV ; favoris puis TNT ; OK = regarder) | ✅ (rappels : ⏳) |
| 15–18 | Notifications, widgets, Live Activity, Siri/Assistant, AirPlay/Chromecast | ⏳ (natif ou comptes) |
| 19 | Téléchargements avancés | ⏳ |
| 20 | Filtre enfant par classification TMDB | ⏳ (une requête TMDB par titre, milliers : trop lourd sans serveur) |
| 21 | Code enfant : 3 essais puis 5 min ; « Code oublié » = mot de passe du compte | ✅ |
| 22 | « Supprimer mon compte » dans l'appli (RPC `delete_account`) | ✅ code · 👤 exécuter `docs/supabase_delete_account.sql` dans Supabase |
| 23 | Écran Confidentialité + `docs/PRIVACY.md` | ✅ · 👤 adresse de contact, URL publique de la politique |
| 24–25 | ATS / cleartext justifiés, serveur d'appairage, clé TMDB côté serveur | ⏳ |
| 26–28 | Performance (isolat, images, démarrage) | ⏳ |
| 29 | Libellés VoiceOver (affiches, boutons ronds, favoris, recherche) | 🟡 |
| 30 | Contraste de `kMut` relevé (8B96AA → 95A0B4) | ✅ |
| 31 | Localisation anglaise | ⏳ |

Priorité = impact pour un utilisateur exigeant ÷ effort. Impact et effort notés de 1 (faible) à 3 (fort).

## 0. À trancher avant tout : le risque store (bloquant)

| Point | Constat honnête | Ce qu'il faut faire |
|---|---|---|
| Positionnement « lecteur » | Apple (règles 5.2.1, 5.2.3) et Google (Propriété intellectuelle, « Unauthorized use ») refusent ou retirent souvent les applis IPTV, même sans contenu fourni, dès qu'un indice suggère du contenu piraté. | Aucune source préchargée, aucun lien vers des vendeurs d'abonnements, aucun logo de chaîne/plateforme dans les captures et la fiche du store, aucun mot « Netflix », « beIN », « Canal+ », « gratuit », « toutes les chaînes ». Captures avec une source de démonstration libre (flux publics, Blender Open Movies). |
| Rangées « Plateformes » et logos | Les logos Netflix/Disney+/Prime (TMDB) et les noms de chaînes payantes sur l'accueil sont le premier motif de rejet. | Version store : rangées neutres (« Collections », « Genres »), logos de plateformes retirés ou désactivés par défaut. |
| Sport Center | Les matchs ESPN qui ouvrent directement « la chaîne qui diffuse » = incitation explicite. | Garder le calendrier, supprimer le lancement automatique de chaîne dans la version store. |
| Compte de démonstration | Apple exige un accès de test fonctionnel. | Fournir un serveur de démo (flux libres) et ses identifiants dans les notes de review. |
| Mise à jour hors store | Le téléchargement d'APK depuis le Pi (kUpdateBase) est interdit sur Play Store. | Désactiver `newerBuild()` dans la version store (indicateur de compilation). |
| TMDB | Usage commercial soumis à accord ; mention obligatoire. | Mention « Ce produit utilise l'API TMDB mais n'est ni approuvé ni certifié par TMDB » dans À propos ; vérifier la licence si l'appli devient payante. |
| ESPN | API non documentée, sans licence d'usage. | Remplacer par une source licenciée (ou retirer) avant publication. |

Réaliste : Play Store possible avec ce positionnement strict ; App Store incertain (rejets fréquents). TestFlight/SideStore restent la voie sûre pour la famille.

## 1. Fiabilité et confiance (impact 3)

| # | Chantier | Impact | Effort |
|---|---|---|---|
| 1 | Crash reporting (Sentry ou Firebase Crashlytics) + journal des erreurs réseau, sans identifiants dans les traces | 3 | 1 |
| 2 | Tests : unitaires sur `names.dart` (parseTitle, splitChannel, dedupe), `parseStreams`, `readCats` ; un test de widget par écran ; CI qui lance `flutter analyze` + `flutter test` | 3 | 2 |
| 3 | Session Supabase : écran clair quand `Account.expired` (reconnexion en un geste) ; ne plus garder le mot de passe en clair dans le trousseau (`acct_pw`) : appairage télé par jeton à usage unique côté serveur | 3 | 2 |
| 4 | Lecteur : reprise réseau (reconnexion auto du direct), message d'erreur lisible au lieu d'un écran noir, choix de piste mémorisé par titre | 3 | 2 |
| 5 | Hors ligne : bannière « Hors ligne », catalogue en cache et téléchargements utilisables sans erreurs en cascade | 2 | 1 |

## 2. Design et finition (impact 3)

| # | Chantier | Impact | Effort |
|---|---|---|---|
| 6 | Direction artistique : une palette et une échelle typographique écrites (jetons existants kBg…kAccent, T()), icônes d'un seul jeu (Material arrondi ou SF Symbols), états vides illustrés | 3 | 2 |
| 7 | Animations : transition « affiche → fiche » (Hero), fondu des images, ressort au focus TV déjà présent, squelettes partout (fiche, recherche) | 2 | 2 |
| 8 | Haptique iPhone (`HapticFeedback.selectionClick` sur onglets, favoris, glisser pour zapper) | 2 | 1 |
| 9 | Commandes du lecteur repensées pour la télé (boutons du haut actuellement non atteignables à la télécommande, favori « étoile » des chaînes non plus, suppression « appui long » impossible à la télécommande) | 3 | 2 |
| 10 | Icône, écran de lancement natif, captures et vidéo de présentation propres | 3 | 1 |

## 3. Onboarding (impact 3)

| # | Chantier | Impact | Effort |
|---|---|---|---|
| 11 | Premier lancement en 3 écrans : compte (facultatif) → source (formulaire, QR depuis le téléphone, ou M3U) → catégories suggérées, avec durée estimée | 3 | 2 |
| 12 | Import M3U / M3U8 en plus d'Xtream (beaucoup d'utilisateurs n'ont que ça) | 2 | 2 |
| 13 | Plusieurs profils par compte (avatar, liste, reprise, mode enfant par profil) | 3 | 3 |

## 4. Fonctions qui font « premium » (impact 2)

| # | Chantier | Impact | Effort |
|---|---|---|---|
| 14 | Guide TV en grille (EPG déjà chargé) + rappels de programme | 3 | 2 |
| 15 | Notifications : nouvel épisode d'une série suivie (le calendrier existe), début d'un match suivi | 2 | 2 |
| 16 | Widgets iOS/Android (« Continuer à regarder », prochain match) et Live Activity pendant un match | 2 | 3 |
| 17 | Siri / Raccourcis / Google Assistant : « Mets TF1 », « Reprends ma série » (App Intents) | 2 | 3 |
| 18 | AirPlay et Chromecast depuis le téléphone ; PiP sur iPhone (déjà sur Android) | 3 | 2 |
| 19 | Téléchargements : file d'attente, reprise après coupure, épisodes de séries, limite de stockage | 2 | 2 |

## 5. Contrôle parental (impact 2)

| # | Chantier | Impact | Effort |
|---|---|---|---|
| 20 | Filtre enfant par classification (TMDB `certification` FR) plutôt que par nom de catégorie ; liste blanche de chaînes jeunesse | 3 | 2 |
| 21 | Code oublié : réinitialisation via le compte (aujourd'hui impossible sans « Effacer mes données ») ; limite d'essais | 2 | 1 |

## 6. Sécurité, confidentialité, RGPD (impact 3, obligatoire store)

| # | Chantier | Impact | Effort |
|---|---|---|---|
| 22 | Suppression de compte dans l'appli (obligatoire Apple 5.1.1(v)) : fonction serveur Supabase qui efface `auth.users` + `user_data` ; « Effacer mes données » ne fait aujourd'hui que l'appareil + la ligne `user_data` si la règle d'accès le permet | 3 | 1 |
| 23 | Politique de confidentialité + fiche « Confidentialité » App Store / « Sécurité des données » Play (données : e-mail, liste, reprise ; identifiants IPTV chiffrés de bout en bout) | 3 | 1 |
| 24 | HTTPS : beaucoup de fournisseurs sont en http → exceptions ATS / `usesCleartextTraffic` à justifier ; serveur d'appairage local (port 8080) à fermer dès la saisie faite | 2 | 1 |
| 25 | Clés : la clé TMDB est dans l'appli (extractible) ; passer par une petite fonction serveur si l'usage grossit | 1 | 1 |

## 7. Performance (impact 2)

| # | Chantier | Impact | Effort |
|---|---|---|---|
| 26 | Bibliothèque construite dans un isolat (dédoublonnage de dizaines de milliers de titres) et index de recherche prêt d'avance | 2 | 2 |
| 27 | Images : tailles adaptées (`memCacheWidth`), préchargement de la rangée suivante, plafond du cache disque | 2 | 1 |
| 28 | Démarrage : mesurer (DevTools) et viser < 1,5 s jusqu'à l'accueil avec cache | 2 | 1 |

## 8. Accessibilité et langues (impact 2)

| # | Chantier | Impact | Effort |
|---|---|---|---|
| 29 | VoiceOver/TalkBack : libellés sur les affiches, boutons ronds et icônes (partiel aujourd'hui) ; tailles de texte dynamiques sans débordement | 2 | 2 |
| 30 | Contrastes (texte gris kMut sur fond sombre limite pour AA) | 1 | 1 |
| 31 | Localisation (intl/ARB) : anglais d'abord ; aujourd'hui tout est en dur en français | 2 | 2 |

## Ordre conseillé

1. Trancher le positionnement store (§0) : il conditionne le reste.
2. Crash reporting, tests, suppression de compte, confidentialité (1, 2, 22, 23).
3. Commandes TV du lecteur et onboarding (9, 11).
4. Guide TV, AirPlay/Chromecast, notifications (14, 18, 15).
