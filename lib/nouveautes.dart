/// nouveautés affichées dans Réglages › Aide › À propos › Version (la plus récente d'abord) : une entrée par groupe de versions,
/// à compléter à chaque publication
const kNews = <(String, List<String>)>[
  ('Version 221', [
    'Réglages › Refaire la configuration : une flèche de retour permet de quitter sans rien changer.',
  ]),
  ('Version 220', [
    'Connexion au fournisseur : l\'appli se présente comme un lecteur IPTV courant (certains serveurs refusent les clients inconnus).',
  ]),
  ('Version 219', [
    'Lecteur : commandes et statistiques décalées pour ne plus passer sous l\'encoche de l\'iPhone.',
    'Le journal note le temps de démarrage de chaque lecture.',
    'Source à un seul écran : si un autre appareil est déjà en lecture, un message demande de confirmer avant de lancer ; une fois validé, l\'autre s\'arrête.',
  ]),
  ('Version 218', [
    'Lecteur iPhone / iPad : mêmes commandes que sur la télé (toucher l\'écran pour les afficher, barre de progression tactile).',
    'Boutons « Sur la télé » retirés.',
    'Si ta source n\'autorise qu\'un écran, un message propose de remplacer l\'autre appareil en lecture.',
  ]),
  ('Version 217', [
    'Réglages › Contenu : « Actualisation automatique » (12 h, 1 jour, 3 jours, 1 semaine, ou à la main). Le catalogue en cache s\'affiche tout de suite, la mise à jour n\'a lieu que passé ce délai.',
    'Appareils à peu de mémoire : l\'appli adapte seule son niveau (léger, très léger) et réduit ses caches.',
    'Le journal note maintenant la fluidité et la mémoire (Aide › Voir le journal) pour repérer les lenteurs.',
  ]),
  ('Version 216', [
    'Fond d\'écran : même rendu sur iPhone, Android et PC.',
  ]),
  ('Version 215', [
    'Compte : « Mot de passe oublié ? » sur l\'écran de connexion (lien reçu par e-mail : l\'appli s\'ouvre pour choisir le nouveau mot de passe).',
  ]),
  ('Version 213', [
    'Retirer un titre de « Continuer à regarder » se synchronise maintenant avec tes autres appareils.',
    'Synchronisation : la liste, la reprise et les playlists de chaque profil et de chaque source suivent maintenant (avant, seul le profil d\'origine).',
    'Synchronisation : les réglages partent dès que tu quittes les Réglages ou que l\'appli passe en arrière-plan.',
  ]),
  ('Version 212', [
    'Télé : retirer un titre de « Continuer à regarder » place la sélection sur le titre suivant (plus de retour à l\'accueil).',
    'Plateformes : fin du clignotement des logos (HBO Max, Starz).',
  ]),
  ('Version 211', [
    'Direct (télé) : ↑ ne fait plus perdre la sélection (les commandes cachées du lecteur la volaient).',
    'Sélection à deux tons (blanc et noir, lisible même en cas de daltonisme) : visible sur les affiches et logos clairs.',
    'Plateformes : plus de clignotement sur HBO Max et Starz ; « Tout voir » toujours présent.',
    'Démarrage : le chat bouge (respire, cligne des yeux, remue la queue et l\'oreille).',
  ]),
  ('Version 210', [
    'Télé : la sélection est maintenant visible sur les studios (logos clairs) et sur « Reprendre ».',
    'Studios : Marvel et DC toujours dans la liste rapide.',
    'Direct (télé) : ↑ garde la sélection sur le lecteur.',
    'Reprise : le lecteur surveille 25 s et replace la lecture au temps enregistré si le flux repart de zéro.',
    'Nouvel écran de démarrage : chat animé, barre de chargement et petites phrases.',
  ]),
  ('Versions 207 à 209', [
    'Films et séries : les 10 principales plateformes et les 10 principaux studios, avec leur logo ; « Tout voir » ouvre la liste complète (plus de 40 plateformes : Max, OCS, Crunchyroll, Hulu, Arte, France.tv, M6+…).',
    'La recherche trouve aussi les plateformes et les studios ; la recherche d\'un acteur est plus rapide.',
    'Changer de version (4K, HD…) reprend au même endroit.',
    'Affiche absente chez le fournisseur : remplacée par celle de TMDB.',
    'Direct (télé) : ↑ ne fait plus disparaître la sélection ni la barre.',
    'Sport (télé) : plus de flèches devant les compétitions.',
    'Reprise de lecture corrigée : le film repart bien à l\'endroit enregistré, sans faux message « Lecture impossible » pendant le chargement.',
    'Fiche du film : « Depuis le début » à côté de « Reprendre », bouton Version plus compact.',
    'Tampon réglable directement depuis « Plus » dans le lecteur.',
    'Télé : plus d\'envoi par e-mail ni de copie du journal (inutiles sans clavier ni messagerie).',
    'Nouveautés dans À propos.',
  ]),
  ('Versions 205 et 206', [
    'Aide › Ton avis : envoie un problème, une idée ou une recommandation (avec les infos techniques si tu veux).',
    'Télé : la barre d\'avancement se sélectionne (↑ depuis les boutons) et se règle avec ← →.',
    'Télé : le bouton Retour de la barre quitte vraiment le lecteur ; → sur l\'engrenage ne descend plus ; → dans Réglages arrive en haut du panneau.',
    'Son : les films dont la piste par défaut est en Dolby TrueHD (souvent les 4K) n\'ont plus un silence complet : une piste lisible est choisie seule.',
    'Son : les modes Cinéma, Nuit et Dialogues sont refaits ; ils coupaient le son sur certains appareils.',
    'Le journal s\'ouvre sur les lignes les plus récentes.',
  ]),
  ('Version 204', [
    'Compte : les réglages de chaque profil et la version choisie pour chaque film sont synchronisés.',
  ]),
  ('Versions 202 et 203', [
    'Lecteur iPhone : les commandes (lecture, pause, avance, barre) sont de retour.',
    'Fond de l\'appli au choix (Réglages › Personnaliser), identique sur tous les écrans et synchronisé.',
    '« Continuer à regarder » ouvre d\'abord la fiche ; l\'appui long demande confirmation avant de retirer.',
    'Titres en thaï, arabe, chinois… remplacés par leur nom dans ta langue quand il existe.',
    'Doublons de films (même affiche, noms différents) fusionnés.',
    'Lecteur : « Son » regroupe audio, sous-titres, mode son et synchro ; les statistiques sont dans « Plus ».',
  ]),
  ('Version 201', [
    'Lecture en plein écran dès le lancement (iPhone, iPad, Android).',
    'Statistiques de lecture : réseau, tampon, images perdues…',
    'Le calage du son est retenu d\'un film à l\'autre.',
    'Choix de la version (4K, HD, langue, source) pour les films et les séries ; « Wonka » et « Wonka 4K » ne font plus qu\'un.',
  ]),
];
