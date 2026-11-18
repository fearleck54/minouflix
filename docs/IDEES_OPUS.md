# MinouFlix : idées « game changer » (recherche du 14/11/2026)

Classement de la plus forte à la plus faible. Pour chaque idée : **[Confirmé]** = vérifié dans la source citée ; **[Hypothèse]** = mon estimation, à vérifier.
Exclu car déjà prévu : notifications, anglais, AirPlay/Chromecast, rapport de plantage, widgets, stats, « similaires ».

---

## 1. Passer le générique, le récap et l'intro, puis enchaîner sur l'épisode suivant
- **Pour l'utilisateur** : boutons « Passer l'intro », « Passer le récap » et « Épisode suivant » qui apparaissent au bon moment, avec une option de saut automatique. Zéro geste pendant une soirée de série.
- **Pourquoi c'est un game changer** : c'est la fonction phare de Netflix, Plex et Infuse, mais ces applis ont besoin d'un serveur qui analyse les fichiers. Les applis IPTV ne l'ont pas. Ici, une simple requête par ID TMDB suffit, sans serveur.
- **Sources** :
  - TheIntroDB : base communautaire de segments intro / récap / générique / aperçu, lecture publique sans clé [Confirmé] : https://theintrodb.github.io/theintrodb-npm/getting-started.html (API `https://api.theintrodb.org/v4`, identifiants tvdbId, tmdbId ou imdbId).
  - Plugin Jellyfin officiel (GPL-3.0) qui s'en sert : https://github.com/TheIntroDB/jellyfin-plugin
  - Infuse utilise TheIntroDB et introdb.app ; des écarts de quelques secondes sont signalés selon le fichier [Confirmé] : https://community.firecore.com/t/support-for-theintrodb-org/58939
  - Repli possible : détection locale par empreinte audio Chromaprint, comme le plugin Intro Skipper (GPL-3.0) : https://github.com/intro-skipper/intro-skipper
- **Bibliothèque / service** : API TheIntroDB (gratuite, sans clé en lecture) ; repli Chromaprint (LGPL-2.1, via FFI) [Hypothèse].
- **Effort** : petit (API + boutons). Gros pour le repli Chromaprint.
- **Risques** : les fichiers VOD IPTV peuvent avoir un décalage (montage, logos), d'où un bouton « Ajuster » et un saut automatique seulement si la durée colle à ±30 s [Hypothèse]. Couverture des séries françaises inconnue [Hypothèse]. Aucun risque légal ni store.

## 2. « Ce soir, on regarde quoi ? » : recherche en langage naturel dans SON catalogue
- **Pour l'utilisateur** : il tape ou dicte « un thriller de moins de 1 h 45 avec Omar Sy » ou « un dessin animé pas trop effrayant pour 6 ans ». L'appli renvoie uniquement des titres disponibles dans ses sources, avec une phrase « pourquoi ce choix ».
- **Pourquoi c'est un game changer** : aucune appli IPTV ne le fait. Croiser l'intention (via un LLM) avec les métadonnées TMDB déjà en cache (durée, casting, classification d'âge) puis filtrer sur le catalogue Xtream donne des résultats jouables tout de suite, pas une liste de films introuvables.
- **Sources** :
  - CineGuide : humeur en langage courant → filtres TMDB via Gemini [Confirmé, dépôt public sans licence] : https://github.com/nperry248/CineGuide
  - stremio-ai-search : addon Stremio de recherche en langage naturel (Gemini ou API compatible OpenAI) + TMDB : https://github.com/itcon-pty-au/stremio-ai-search
  - SuggestArr, « AI Search » avec repli sur l'algorithme TMDB si le LLM échoue : https://github.com/giuseppe99barchetta/suggestarr
- **Bibliothèque / service** :
  - Sur l'iPhone : `flutter_foundation_models` 0.3.0 (MIT), modèle Apple sur l'appareil, gratuit, avec appels d'outils, iOS 26+ et appareil Apple Intelligence [Confirmé] : https://pub.dev/packages/flutter_foundation_models
  - Google TV et vieux iPhone : Gemini Flash appelé depuis une Edge Function Supabase (la clé reste côté serveur) ; quotas gratuits flous en 2026 [Confirmé que c'est flou].
  - Recherche par mots-clés en repli.
- **Effort** : moyen.
- **Risques** : coût et quota du LLM si l'appli est publiée. Dans ce cas, prévoir une limite par jour ou une option premium [Hypothèse]. Pas de risque légal.

## 3. « MinouFlix Connect » : l'iPhone devient télécommande, clavier et bouton « continuer sur la télé »
- **Pour l'utilisateur** : il cherche sur l'iPhone et la Google TV lance la lecture. Il tape au clavier du téléphone au lieu de la télécommande. Il commence un épisode dans le lit et un bouton « Continuer sur la télé » reprend à la seconde près, comme Spotify Connect.
- **Pourquoi c'est un game changer** : différent de Chromecast (déjà prévu), car la TV lit elle-même son flux avec MinouFlix, sans perte de qualité. La saisie à la télécommande est la plainte n° 1 sur les applis TV.
- **Sources** :
  - Plainte « chercher lettre par lettre » sur Plex Android TV [Confirmé] : https://forums.plex.tv/t/search-using-keyboard-on-android-tv/818707
  - Supabase Realtime Broadcast / Presence : « low-latency messages between clients » et suivi des appareils connectés [Confirmé] : https://supabase.com/docs/guides/realtime/presence
- **Bibliothèque / service** : `supabase_flutter` (déjà là, MIT), canaux Broadcast + Presence par compte. Pas de nouveau service.
- **Effort** : moyen.
- **Risques** : faibles. Il faut un canal privé (politiques RLS sur `realtime.messages`) pour qu'un tiers ne pilote pas la TV [Hypothèse à vérifier dans la doc d'autorisation].

## 4. Mode cinéma domotique (Home Assistant)
- **Pour l'utilisateur** : il lance un film et le salon passe en ambiance ciné (lumières à 10 %, volets baissés). Pause : lumière douce. Générique de fin (grâce à l'idée 1) : les lumières remontent. Aucune action à faire.
- **Pourquoi c'est un game changer** : effet waouh immédiat chez Romain (HA déjà en place). Aucune appli IPTV ne le propose nativement. Pour la publication, c'est un réglage générique « URL de webhook » optionnel.
- **Sources** :
  - Photon, appli gratuite qui fait ça pour Plex, Jellyfin et Emby et gère Home Assistant [Confirmé] : https://forums.plex.tv/t/photon-lighting-app/944856
  - Discussions HA sur le même besoin : https://community.home-assistant.io/t/dim-lights-when-playing-a-movie-from-plex-solved/92972
  - Déclencheur webhook HA : https://www.home-assistant.io/docs/automation/trigger/
- **Bibliothèque / service** : `http` (déjà là). Envoi en POST de `{event: play|pause|stop|credits, type: film|serie|live|sport, titre}` au webhook. Côté HA, une automation ou un blueprint fourni.
- **Effort** : petit.
- **Risques** : quasi nuls. L'URL du webhook est un secret, à garder dans `flutter_secure_storage`. Pour le store, préciser que c'est optionnel et local.

## 5. « Précédemment dans… » : résumé sans spoiler avant de reprendre une série
- **Pour l'utilisateur** : en reprenant une série après trois semaines, il reçoit un résumé de 5 lignes de ce qui s'est passé jusqu'à son dernier épisode vu, jamais au-delà.
- **Pourquoi c'est un game changer** : Amazon en a fait une fonction phare (X-Ray Recaps, IA générative, garde-fous anti-spoiler), limitée à ses propres séries. MinouFlix peut le faire pour toutes les séries TMDB.
- **Sources** : TechCrunch, X-Ray Recaps (04/11/2024) [Confirmé] : https://techcrunch.com/2024/11/04/amazon-brings-generative-ai-powered-recaps-to-prime-video
- **Bibliothèque / service** : résumés d'épisodes TMDB en français (déjà utilisés), passés jusqu'à l'épisode N dans le même LLM que l'idée 2. Mise en cache dans Supabase par série et par épisode, donc un seul appel partagé par tous les utilisateurs [Hypothèse].
- **Effort** : petit, si l'idée 2 est faite.
- **Risques** : résumés TMDB parfois absents en français, avec repli sur l'anglais traduit. Contenu généré : afficher « résumé généré automatiquement ».

## 6. Multiview sport (2 à 4 chaînes en même temps)
- **Pour l'utilisateur** : soir de Top 14 ou de multiplex foot, il affiche 2 à 4 matchs en mosaïque. Le son suit la tuile sélectionnée et un clic passe en plein écran.
- **Pourquoi c'est un game changer** : fonction très demandée pour le sport (Channels, YouTube TV, DirecTV en font un argument commercial). Elle est rare et souvent payante dans les applis IPTV (TiviMate la réserve à l'abonnement premium d'après un utilisateur).
- **Sources** :
  - Channels, multiview jusqu'à 4 chaînes, Apple TV et iPad seulement [Confirmé] : https://getchannels.com/docs/apps/usage/multiview/
  - Demande pour Android/Google TV : https://community.getchannels.com/t/multiview-on-android-tv-google-tv-why-is-this-not-being-looked-at/45748
  - Mémoire de media_kit avec plusieurs Players (16 instances vides ≈ 700-800 Mo) [Confirmé] : https://github.com/media-kit/media-kit/issues/776
- **Bibliothèque / service** : plusieurs `Player` media_kit. Flux secondaires en basse résolution si la source en propose [Hypothèse].
- **Effort** : moyen à gros.
- **Risques** : **la limite de connexions simultanées de l'abonnement Xtream** (souvent 1 ou 2, champ `max_connections` renvoyé par l'API) [Hypothèse]. Il faut la lire et limiter le nombre de tuiles en conséquence. Le décodage de 4 flux sur une Google TV d'entrée de gamme est probablement limité à 2 [Hypothèse].

## 7. Sport sans spoiler + score en direct en surimpression
- **Pour l'utilisateur** : en mode « je regarde en différé », les scores sont masqués partout (guide, rattrapage, calendrier). En direct, un bandeau discret affiche le score et le chrono, ou le score d'un autre match du multiplex.
- **Pourquoi c'est un game changer** : YouTube TV en a fait une fonction culte (masquer les scores par équipe ou ligue). Les applis IPTV affichent au contraire les résultats dans les titres EPG.
- **Sources** :
  - Aide YouTube TV « Hide sports scores » [Confirmé] : https://support.google.com/youtubetv/answer/7641863
  - API rugby couvrant le Top 14 : Highlightly https://highlightly.net/rugby-api/ , oanor https://oanor.com/api/rugby-api (gratuité du live non confirmée) ; TheSportsDB a peu de live en gratuit d'après des tiers : https://www.thesportsdb.com/documentation
- **Bibliothèque / service** : la source du calendrier sportif déjà en place, plus une API de score en direct (à choisir, souvent payante) [Hypothèse].
- **Effort** : petit pour l'anti-spoiler, moyen pour le score en direct.
- **Risques** : coût et conditions de l'API de scores en cas de publication. Masquage imparfait : les incrustations de la chaîne restent visibles.

## 8. Mode nuit / voix claires
- **Pour l'utilisateur** : un bouton « Mode nuit » égalise le volume (fini les explosions qui réveillent les enfants et les dialogues inaudibles) et met les voix en avant.
- **Pourquoi c'est un game changer** : demande très fréquente, et c'est presque gratuit car mpv embarque déjà les filtres FFmpeg. Les téléviseurs l'ont, les applis IPTV non.
- **Sources** :
  - Réglages `dynaudnorm` partagés par des utilisateurs mpv et filtre `pan` « night mode » qui renforce le canal central : https://forum.videohelp.com/showthread.php?p=2533463 et https://gist.github.com/chapmanjacobd/1b7bc9ce1d245867fe7183149a8ffc46
  - Doc mpv (filtres audio, `acompressor` recommandé, ancien `drc` retiré) : https://git.tjdev.de/mirror/mpv/src/commit/222899fbbe523320e66ae1600fabe45b58d48686/DOCS/man/af.rst
- **Bibliothèque / service** : media_kit `NativePlayer.setProperty('af', 'lavfi=[dynaudnorm=f=75:g=25:p=0.55]')`. Fonctionne si la build libmpv de media_kit inclut ces filtres [Hypothèse, à tester].
- **Effort** : petit.
- **Risques** : faibles. Le passthrough Dolby/DTS est incompatible avec le filtrage, donc le désactiver en mode nuit.

## 9. Live Activities / Dynamic Island
- **Pour l'utilisateur** : sur l'écran verrouillé, le match en cours avec son score, le compte à rebours du minuteur de sommeil, la progression d'un téléchargement ou « Épisode suivant dans 2 min » (lecture sur la TV).
- **Pourquoi c'est un game changer** : très « Apple », très visible, et différent des widgets déjà prévus. Les applis IPTV ne l'utilisent pas.
- **Sources** : `live_activities` 2.6.0 (MIT, éditeur vérifié, iOS 16.1+, Android en bêta) [Confirmé] : https://pub.dev/packages/live_activities
- **Bibliothèque / service** : `live_activities`, avec extension widget + App Group à configurer dans Xcode.
- **Effort** : moyen.
- **Risques** : avec SideStore et un compte gratuit, chaque extension consomme un App ID (limite basse) [Hypothèse, à vérifier]. Les mises à jour à distance (score) demandent des push APNs, donc un compte développeur payant.

## 10. Siri, Raccourcis et Spotlight
- **Pour l'utilisateur** : « Dis Siri, mets France 2 sur MinouFlix », « Reprends ma série », ou une recherche Spotlight qui ouvre directement la fiche. Les Raccourcis permettent des automatisations, par exemple « 21 h le vendredi → soirée film ».
- **Pourquoi c'est un game changer** : le pilotage à la voix sans ouvrir l'appli colle au besoin « zéro effort ». Les App Intents rendent aussi l'appli visible par Apple Intelligence.
- **Sources** : `intelligence` (Monterail, MIT, iOS 16+) : Siri, Raccourcis, Spotlight, Apple Intelligence [Confirmé] : https://pub.dev/packages/intelligence. Autre option iOS + Android AppFunctions : https://pub.dev/packages/app_intents
- **Bibliothèque / service** : `intelligence` ou `app_intents`.
- **Effort** : moyen.
- **Risques** : peu de risques. Côté Google TV, l'Assistant ne permet pas des actions personnalisées aussi simples [Hypothèse].

## 11. Rangée « Continuer à regarder » sur l'accueil de Google TV
- **Pour l'utilisateur** : son épisode en cours apparaît directement sur l'accueil de la Google TV et un clic reprend la lecture.
- **Pourquoi c'est un game changer** : les grandes applis le font. Pour une appli IPTV, ce serait une première.
- **Sources** : Engage SDK, obligatoire pour les nouvelles intégrations « Continue watching » ; publication soumise à une certification Google [Confirmé] : https://developer.android.com/guide/playcore/engage/faq et https://developer.android.com/training/tv/discovery/watch-next-add-programs
- **Bibliothèque / service** : Engage SDK (Google, gratuit) via un canal natif Kotlin.
- **Effort** : moyen.
- **Risques** : la certification exige une appli publiée sur le Play Store, donc pas d'effet tant que l'appli est installée par APK [Hypothèse probable]. À garder pour la publication.

## 12. Pause « InSight » : qui joue et quelle est cette musique ?
- **Pour l'utilisateur** : à la pause, un panneau montre les acteurs de la scène (casting TMDB) et un bouton « Quelle est cette musique ? » reconnaît la chanson.
- **Pourquoi c'est un game changer** : c'est la fonction la plus appréciée d'Apple TV+ (InSight) et de Prime Video (X-Ray), réservée à leurs propres contenus.
- **Sources** :
  - InSight (WWDC 2024) [Confirmé] : https://techcrunch.com/2024/06/10/apple-tv-insight-feature-wwdc-2024
  - `flutter_shazam_kit` 1.0.2 (BSD-3, iOS 15+ / Android 23+, non mis à jour depuis 2022) : https://pub.dev/packages/flutter_shazam_kit
- **Bibliothèque / service** : ShazamKit (Apple, gratuit). Le casting TMDB est déjà là. Sur Android, il faut un jeton développeur Apple valable 3 mois maximum [Confirmé].
- **Effort** : petit à moyen.
- **Risques** : reconnaissance par le micro (permission à demander) ; savoir « qui est à l'écran » à l'instant précis est impossible sans reconnaissance faciale, donc on affiche le casting principal [Hypothèse]. Le paquet n'est plus maintenu.

## 13. Sous-titres générés ou traduits sur l'appareil
- **Pour l'utilisateur** : un film VO sans sous-titres français ? Sur un contenu téléchargé, l'appli génère les sous-titres (Whisper) puis les traduit en français, sans aucun service externe. En ligne, la recherche OpenSubtitles sert de repli.
- **Pourquoi c'est un game changer** : c'est la promesse « IA » la plus concrète, et aucune appli IPTV ne la tient.
- **Sources** :
  - `whisper_kit` 0.3.1 (MIT, Android OK, iOS bêta, traduction vers l'anglais) [Confirmé] : https://pub.dev/packages/whisper_kit
  - `google_mlkit_translation` 1.0.3 (MIT, traduction sur l'appareil, plus de 50 langues dont le français) [Confirmé] : https://pub.dev/packages/google_mlkit_translation
  - OpenSubtitles : environ 20 téléchargements par jour pour un compte gratuit [Confirmé] : https://opensubtitles.tawk.help/article/about-the-api
- **Bibliothèque / service** : whisper.cpp via `whisper_kit` ou `whisper_ggml`, ML Kit Translation, API OpenSubtitles.
- **Effort** : gros.
- **Risques** : très lent sur téléphone pour un film de 2 h (des dizaines de minutes) et irréaliste sur Google TV [Hypothèse]. Traduction ML Kit moyenne. Modèles de 75 à 500 Mo. Réserver la fonction aux téléchargements.

## 14. Soirée film à distance (synchro de la lecture)
- **Pour l'utilisateur** : il regarde le même film en même temps qu'un proche, avec lecture, pause et avancée synchronisées, et des réactions emoji. Via FaceTime (SharePlay) ou un code de salon.
- **Pourquoi c'est un game changer** : Plex a retiré Watch Together de ses nouvelles applis en 2025 et ses utilisateurs l'ont très mal pris, donc la demande existe.
- **Sources** :
  - Retrait par Plex : https://www.androidauthority.com/plex-watch-together-removed-3529939/
  - Jellyfin SyncPlay : https://www.androidauthority.com/jellyfin-syncplay-explained-3530437/
  - Paquet `shareplay` (iOS 15+, peu maintenu) : https://pub.dev/packages/shareplay
- **Bibliothèque / service** : Supabase Realtime (déjà là) pour la synchro ; `shareplay` en option sur iOS.
- **Effort** : gros.
- **Risques** : **légal et store** : ne synchroniser que des commandes (position, pause), jamais relayer le flux. Chaque participant lit le contenu depuis sa propre source, sinon c'est du partage d'abonnement. Utilité familiale moindre que les idées 1 à 5 [Hypothèse].

---

## Pistes écartées
- **Saut automatique des pubs (Comskip, GPL-2)** : techniquement possible sur le rattrapage, mais risqué pour la conformité store et l'image (contourner la publicité des chaînes).
- **Synchro Trakt** : limites du compte gratuit durcies en 2025-2026 (une seule appli connectée d'après un tiers) et recoupe les stats déjà prévues : https://alternativeto.net/news/2025/2/trakt-tv-has-set-stricter-limits-for-free-users-and-raised-vip-subscription-prices-by-100-
- **Lumières aux couleurs de l'image (façon Ambilight via HA)** : il faudrait des captures d'image régulières, et l'API de capture de media_kit n'est pas confirmée. Coût en performance et latence. Gadget par rapport à l'idée 4.
- **Super-résolution par shaders mpv** : trop lourd pour les GPU des Google TV.

## Ordre de réalisation conseillé
1 → 8 → 4 (petits efforts, gros effet), puis 3 → 2 → 5 (le même pipeline LLM sert aux idées 2 et 5), puis 6 et 7 pour la saison sportive.
