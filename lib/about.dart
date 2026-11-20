import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'ui.dart';

/// mention exigée par les conditions d'utilisation de TMDB
const kTmdbNotice = 'Ce produit utilise l\'API TMDB mais n\'est ni approuvé ni certifié par TMDB.';

/// texte de « Confidentialité » (même contenu que docs/PRIVACY.md)
const kPrivacy = [
  ('En bref', 'MinouFlix est un lecteur : il ne fournit aucun contenu. Aucune publicité, aucun pistage, aucune donnée vendue ni partagée à des fins commerciales.'),
  ('Ce qui reste sur cet appareil', 'Les identifiants de ton abonnement (chiffrés par le trousseau de l\'iPhone ou le Keystore Android), le catalogue et les images en cache, les téléchargements, tes réglages, le code du mode enfant et le journal d\'erreurs. Le journal ne contient ni identifiants ni adresses complètes, et ne quitte jamais l\'appareil (sauf si tu le copies toi-même).'),
  ('Avec un compte MinouFlix (facultatif)', 'Ton e-mail et ton mot de passe servent à te connecter (hébergement du compte : Supabase). Selon tes choix dans « Compte et synchronisation » : Ma liste, la reprise de lecture, ton prénom et tes championnats. Les identifiants IPTV, si tu choisis de les synchroniser, sont chiffrés sur l\'appareil avec une clé tirée de ton mot de passe : le serveur ne peut pas les lire.'),
  ('Services contactés', 'Ton fournisseur IPTV (directement depuis l\'appareil), TMDB pour les affiches et résumés (seul le titre recherché est envoyé), le calendrier sportif si tu l\'utilises, et YouTube pour les bandes-annonces.'),
  ('Tes choix', '« Effacer mes données » supprime tout ce que l\'appli garde sur cet appareil. « Supprimer mon compte » efface définitivement ton compte et sa copie synchronisée sur le serveur.'),
  ('TMDB', kTmdbNotice),
];

/// page de texte lisible au doigt et à la télécommande (haut / bas font défiler)
class TextPage extends StatefulWidget {
  final String title;
  final List<(String, String)> sections;     // titre, texte
  final String mono;                         // texte brut (journal) : police à chasse fixe
  final String? action;                      // bouton en haut à droite (ex. « Copier »)
  final VoidCallback? onAction;
  const TextPage({super.key, required this.title, this.sections = const [], this.mono = '', this.action, this.onAction});
  @override
  State<TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<TextPage> {
  final sc = ScrollController();

  @override
  void dispose() {
    sc.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (!sc.hasClients) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final p = sc.position;
    if (k == LogicalKeyboardKey.arrowDown && p.pixels < p.maxScrollExtent) {
      sc.animateTo(math.min(p.pixels + 240, p.maxScrollExtent), duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowUp && p.pixels > 0) {
      sc.animateTo(math.max(p.pixels - 240, 0), duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;     // tout en haut : le focus peut remonter vers « Retour »
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return DsBg(child: Scaffold(backgroundColor: Colors.transparent, 
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16 + pad.left, pad.top + 8, 16 + pad.right, 6),
              child: Row(children: [
                RoundButton(size: 44, label: 'Retour', onTap: () => Navigator.pop(context), child: const Ic('back', size: 20)),
                const SizedBox(width: 14),
                Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(26, w: 750, ls: -0.035))),
                if (widget.action != null && widget.onAction != null) PillButton(label: widget.action!, height: 40, onTap: widget.onAction!),
              ]),
            ),
            Expanded(
              child: Focus(
                autofocus: true,
                onKeyEvent: _key,
                child: ListView(controller: sc, padding: EdgeInsets.fromLTRB(22 + pad.left, 10, 22 + pad.right, 40 + pad.bottom), children: [
                  for (final s in widget.sections) ...[
                    Text(s.$1, style: T(18, w: 750, ls: -0.02)),
                    const SizedBox(height: 6),
                    Text(s.$2, style: T(15, color: const Color(0xFFDFE5F0), h: 1.45)),
                    const SizedBox(height: 20),
                  ],
                  if (widget.mono.isNotEmpty) Text(widget.mono, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.35, color: Color(0xFFDFE5F0))),
                ]),
              ),
            ),
          ]),
        ),
      ),
    ));
  }
}
