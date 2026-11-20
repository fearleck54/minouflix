# Fiche store MinouFlix (iPhone/iPad, Android, Android TV)

Textes prêts à coller. Rien ici ne cite de chaîne, de bouquet ni de fournisseur (voir docs/publication_stores.md).

## Identité
- Nom : MinouFlix. Sous-titre (Apple, 30 car.) : « Ton lecteur IPTV et sport ».
- Identifiant : fr.maison.minouflix. Catégorie : Divertissement (Google : Lecteurs et éditeurs vidéo).
- Langues de la fiche : français (principal), anglais. L'appli existe en fr, en, es, de, pt.

## Description courte (Google, 80 car.)
FR : Un lecteur élégant pour ton abonnement IPTV, avec sport en direct et reprise.
EN : A sleek player for your own IPTV subscription, with live sport and resume.

## Description longue
FR :
MinouFlix est un lecteur : il ne fournit aucune chaîne, aucun film, aucune liste. Tu ajoutes ta propre source (Xtream Codes ou playlist M3U) et MinouFlix la présente avec une interface soignée.

• Films, séries et direct réunis, avec affiches et résumés
• Onglet Sport : matchs, scores, classements et statistiques, avec les chaînes qui diffusent selon ton pays
• Guide des programmes (EPG), retour en arrière sur le direct
• Reprendre où tu t'es arrêté, sur tous tes appareils (compte facultatif)
• Épisode suivant automatique, passer l'intro, bandes-annonces
• Plusieurs profils, mode enfant avec code
• Synchro audio, mode nuit et dialogues renforcés, sous-titres en ligne
• Recherche par titre, acteur ou à la voix
• Pensé pour la télécommande sur Android TV, fluide même sur un petit boîtier

Aucune publicité, aucun pistage. Tes identifiants restent chiffrés sur ton appareil.
Ce produit utilise l'API TMDB mais n'est ni approuvé ni certifié par TMDB.

EN :
MinouFlix is a player: it provides no channels, movies or playlists. You add your own source (Xtream Codes or M3U playlist) and MinouFlix presents it in a polished interface.

• Movies, series and live TV in one place, with posters and summaries
• Sport tab: fixtures, scores, standings and stats, with the channels airing them in your country
• Programme guide (EPG), live rewind
• Resume where you left off on every device (optional account)
• Auto-play next episode, skip intro, trailers
• Several profiles, kids mode with a PIN
• Audio sync, night mode and boosted dialogue, online subtitles
• Search by title, actor or voice
• Built for the Android TV remote, smooth even on small boxes

No ads, no tracking. Your credentials stay encrypted on your device.
This product uses the TMDB API but is not endorsed or certified by TMDB.

## Notes pour le relecteur (Apple « Notes de relecture » / Google « Accès à l'appli »)
MinouFlix is an IPTV player. It contains NO channels, films or playlists; the user supplies their own provider details. To review, add a source with the demo details below (a legal, free-to-air test playlist) in the first screen.
- Demo source (M3U playlist, add it as a source in the first screen): https://ha.fearleck.org/local/appli/demo.m3u (public news channels from official broadcasters and two Creative Commons films by the Blender Foundation).
- Demo account (optional, for sync): À CRÉER (e-mail de démo sur fearleck.org + mot de passe)
- HTTP: IPTV servers chosen by users are often plain http, hence NSAllowsArbitraryLoads / usesCleartextTraffic. The app never contacts any server other than the user's provider, TMDB, a public sports calendar, YouTube (trailers) and the account service.
- Microphone / speech recognition: only when the user taps the mic in Search, to dictate a query (system recognizer; nothing recorded by the app).
- Account deletion: Réglages > « Supprimer mon compte » (visible une fois connecté).
- Content rights: the app does not host, stream or index third-party content.

## Questionnaires
- Classification : pas de contenu fourni par l'appli ; le contenu dépend de la source de l'utilisateur. Mode enfant disponible. Pas d'achats, pas de publicité, pas de contenu généré par les utilisateurs partagé.
- Google « Sécurité des données » : e-mail (compte, facultatif) ; activité dans l'appli (Ma liste, reprise) ; voix non collectée par l'appli. Chiffré en transit ; suppression possible dans l'appli + URL de suppression. Pas de partage avec des tiers à des fins commerciales.
- Apple « Confidentialité de l'app » : Coordonnées (e-mail) et Contenu utilisateur (liste, reprise), liés à l'utilisateur, pas de suivi. Pas d'ATT (aucun traceur).
- Public cible : 13+ / tout public sans cibler les enfants (éviter Families).
- Permissions Android : INTERNET, RECORD_AUDIO (dictée, demandée à l'usage). Android TV : leanback, touchscreen non requis, bannière 320×180.

## Visuels à produire
- Icône 1024 px sans transparence (assets : icon.png).
- iPhone 6,9" et 6,5", iPad 13" ; Android téléphone ; Android TV 1920×1080 (4 à 8 captures). Sans nom de chaîne, de bouquet ni de fournisseur réel : utiliser la source de démonstration.
- Bannière Play 1024×500.

## Reste à faire côté humain
1. Créer contact@fearleck.org (Cloudflare Email Routing), puis héberger /confidentialite et /suppression-compte.
2. Comptes développeur Apple (99 $/an) et Google Play (25 $, test fermé 12 testeurs / 14 jours).
3. Compte de démo (la source de démonstration est prête : www/appli/demo.m3u).
4. Clé de téléversement Play (keystore de publication distinct de la clé de test) puis `[aab]` dans le commit pour produire le .aab.
5. Apple : certificat de distribution et profil, remplace SideStore (secrets CI).
