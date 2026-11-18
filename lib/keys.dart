/// clé TMDB : fournie à la compilation (--dart-define=TMDB_KEY=…), jamais écrite dans le code ; vide = pas d'affiches TMDB
const kTmdbKey = String.fromEnvironment('TMDB_KEY');

/// Supabase (synchronisation entre appareils) : clé publique, faite pour être dans l'appli
const kSbUrl = 'https://huvxeflutvbmjryvmyzg.supabase.co';
const kSbKey = 'sb_publishable_54QMEMeqIcD33p-akCzsdw_V_YJNDLm';
