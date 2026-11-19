import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute, CupertinoIcons, CupertinoActivityIndicator;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as mat show Text;
import 'journal.dart';
import 'l10n.dart';
export 'l10n.dart' show L;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'epg.dart';
import 'extras.dart' show collectionSheet;
import 'icons_data.dart';
import 'perf.dart';
export 'perf.dart' show Perf, Device;
import 'names.dart';
import 'store.dart';
import 'tmdb.dart';
import 'xtream.dart';

// ---------- jetons de design (identiques à l'appli web MinouFlix) ----------
const kBg = Color(0xFF06080D);
const kBg2 = Color(0xFF131824);
const kBg3 = Color(0xFF1B2231);
const kLine = Color(0xFF232C3D);
const kText = Color(0xFFEEF2F8);
const kMut = Color(0xFF95A0B4);     // relevé un peu (lisibilité du texte secondaire sur fond sombre)
const kAccent = Color(0xFF5B8CFF);
const kGlass = Color(0xB8161B26);
const kEdge = Color(0x1FFFFFFF);

bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= 700;

/// style de texte Inter (police variable : graisse exacte)
/// police : celle du système sur iPhone (SF Pro), Inter ailleurs
final String? kFont = (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ? null : 'Inter';

TextStyle T(double size, {double w = 400, Color color = kText, double ls = 0, double? h}) => TextStyle(
      fontFamily: kFont,
      fontSize: size,
      fontWeight: FontWeight.values[((w / 100).round() - 1).clamp(0, 8)],
      fontVariations: [ui.FontVariation('wght', w)],
      color: color,
      letterSpacing: ls * size,
      height: h,
    );

/// icône de l'appli web (mêmes tracés)
class Ic extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  final double stroke;
  const Ic(this.name, {super.key, this.size = 22, this.color = kText, this.stroke = 1.7});

  @override
  Widget build(BuildContext context) => SvgPicture.string(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">${kIcons[name] ?? ''}</svg>',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

/// élément sélectionnable à la télécommande : zoom léger + cadre blanc au focus, OK / Entrée = action
class FocusCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double radius;
  final bool ring;
  final VoidCallback? onLong;       // appui long (OK maintenu à la télécommande)
  final bool autofocus;
  final double focusScale;      // agrandissement quand la ligne est sélectionnée (1 = aucun : lignes de liste dans un cadre)
  final VoidCallback? onFocus;      // appelé quand l'élément prend le focus (télécommande) : les onglets changent de page dès qu'on s'y arrête
  final FocusNode? focusNode;
  final bool preferred;      // télé : quand on arrive sur cette rangée avec ↑ ↓, cet élément est choisi en premier (onglet actif de la barre)
  const FocusCard({super.key, required this.child, required this.onTap, this.radius = 15, this.ring = true, this.onLong, this.autofocus = false, this.focusScale = 1.06, this.onFocus, this.focusNode, this.preferred = false});
  @override
  State<FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends State<FocusCard> {
  bool focused = false, pressed = false, _long = false, _down = false;
  FocusNode? _own;
  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'carte'));

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  /// banc d'essai (scripts/outils/tv_parcours.sh) : chaque élément qui prend le focus est noté dans le journal système (texte, position)
  void _trace() {
    String? out;
    var n = 0;
    void v(Element e) {
      if (out != null || n++ > 80) return;
      final w = e.widget;
      if (w is Text) {
        out = w.data;
        return;
      }
      if (w is mat.Text) {
        out = w.data;
        return;
      }
      e.visitChildren(v);
    }

    (context as Element).visitChildren(v);
    final r = _node.rect;
    // ignore: avoid_print
    print('TVFOCUS|${(out ?? '').replaceAll('|', ' ').replaceAll('\n', ' ')}|${r.center.dx.round()}|${r.center.dy.round()}');
  }

  /// rangée horizontale qui contient ce widget (null : hors rangée)
  static ScrollableState? _hScroll(BuildContext c) {
    ScrollableState? r;
    c.visitAncestorElements((e) {
      if (e is StatefulElement && e.state is ScrollableState) {
        final st = e.state as ScrollableState;
        if (st.axisDirection == AxisDirection.left || st.axisDirection == AxisDirection.right) r = st;
        return false;
      }
      return true;
    });
    return r;
  }

  /// dernier élément ayant eu le focus dans chaque rangée : en y revenant avec ↑ ↓, on le retrouve
  static final Map<ScrollableState, FocusNode> _mem = {};

  /// liste verticale qui contient ce widget (null : hors de toute liste, ex. barre d'onglets)
  static ScrollableState? _vScroll(BuildContext c) {
    ScrollableState? r;
    c.visitAncestorElements((e) {
      if (e is StatefulElement && e.state is ScrollableState) {
        final st = e.state as ScrollableState;
        if (st.axisDirection == AxisDirection.down || st.axisDirection == AxisDirection.up) {
          r = st;
          return false;
        }
      }
      return true;
    });
    return r;
  }

  /// télé : fait défiler chaque liste parente juste ce qu'il faut ; près du début d'une liste, on remonte tout en haut (le grand visuel redevient visible)
  void _reveal() {
    final me = context.findRenderObject();
    if (me is! RenderBox || !me.attached) return;
    context.visitAncestorElements((el) {
      if (el is StatefulElement && el.state is ScrollableState) {
        final st = el.state as ScrollableState;
        final pos = st.position;
        final vp = st.context.findRenderObject();
        if (pos is PageMetrics || vp is! RenderBox || !vp.attached || !pos.hasPixels) return true;
        final horiz = st.axisDirection == AxisDirection.left || st.axisDirection == AxisDirection.right;
        final o = me.localToGlobal(Offset.zero, ancestor: vp);
        final top = horiz ? o.dx : o.dy, len = horiz ? me.size.width : me.size.height, vpLen = horiz ? vp.size.width : vp.size.height;
        final cont = pos.pixels + top;
        // position fixe pour la rangée / la tuile active (centrage régulier) ; près du début de la liste : tout en haut
        // rangée horizontale : on ne la fait défiler que si l'élément n'est pas entièrement visible (monter / descendre ne la déplace plus)
        if (horiz && top >= 40 && top + len <= vpLen - 40) return true;
        double target = cont < vpLen * (horiz ? 0.45 : 0.8) ? pos.minScrollExtent : (horiz ? cont - vpLen * 0.2 : cont + len / 2 - vpLen * 0.42);
        target = target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
        if ((target - pos.pixels).abs() > 1) pos.animateTo(target, duration: const Duration(milliseconds: 130), curve: Curves.easeOut);
      }
      return true;
    });
  }

  /// télécommande : on choisit nous-mêmes l'élément voisin (même rangée pour ← →, rangée la plus proche pour ↑ ↓, élément le plus aligné) :
  /// jamais de saut par-dessus une rangée, jamais de changement de ligne au bout d'une rangée
  bool _nav(KeyEvent e) {
    final k = e.logicalKey;
    if (!Device.tv || e is KeyUpEvent) return false;
    final horiz = k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight;
    final vert = k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown;
    if (!horiz && !vert) return false;
    final sc = Scrollable.maybeOf(context);
    if (sc != null && sc.position is PageMetrics) return false;
    final me = _node.rect;
    final scope = _node.nearestScope;
    if (scope == null) return false;
    final cand = <FocusNode>[
      for (final n in scope.traversalDescendants)
        if (n != _node && n.context != null && n.canRequestFocus && !n.skipTraversal && n.rect.width > 0) n
    ];
    FocusNode? best;
    if (horiz) {
      final right = k == LogicalKeyboardKey.arrowRight;
      var bd = double.infinity;
      for (final n in cand) {
        final r = n.rect;
        if ((r.center.dy - me.center.dy).abs() > me.height * 0.6) continue;      // même rangée seulement
        final d = right ? r.center.dx - me.center.dx : me.center.dx - r.center.dx;
        if (d > 4 && d < bd) {
          bd = d;
          best = n;
        }
      }
      // on change de zone (grille → colonne de filtres, et inversement) : on arrive sur l'élément actif de la zone, sinon le plus proche en hauteur
      final mine = _vScroll(context);
      if (best == null || _vScroll(best.context!) != mine) {
        final others = [
          for (final n in cand)
            if (_vScroll(n.context!) != null && _vScroll(n.context!) != mine && (right ? n.rect.center.dx > me.center.dx : n.rect.center.dx < me.center.dx)) n
        ];
        final pref = others.where((n) => n.context?.findAncestorWidgetOfExactType<FocusCard>()?.preferred == true).toList();
        if (pref.isNotEmpty) {
          best = pref.first;
        } else if (best == null && others.isNotEmpty) {
          others.sort((x, y) => (x.rect.center.dy - me.center.dy).abs().compareTo((y.rect.center.dy - me.center.dy).abs()));
          best = others.first;
        }
      }
      if (best == null && sc != null && (sc.axisDirection == AxisDirection.left || sc.axisDirection == AxisDirection.right)) return true;      // bout de rangée : on ne bouge pas
      if (best == null) return false;      // pas de rangée défilante : navigation habituelle (colonne de gauche → grille…)
    } else {
      final down = k == LogicalKeyboardKey.arrowDown;
      double dist(FocusNode n) => down ? n.rect.center.dy - me.center.dy : me.center.dy - n.rect.center.dy;
      final mine = _vScroll(context);
      // 1) la même liste d'abord (rangées au-dessus / au-dessous), 2) sinon ce qui est hors de la liste (barre d'onglets…)
      var group = [for (final n in cand) if (_vScroll(n.context!) == mine && dist(n) > me.height * 0.5) n];
      if (group.isEmpty) group = [for (final n in cand) if (_vScroll(n.context!) != mine && dist(n) > me.height * 0.5) n];
      if (group.isEmpty) return false;
      List<FocusNode> row;
      if (mine == null && down) {
        // on entre dans la liste depuis la barre : toujours sa toute première rangée (même si la liste est défilée)
        double content(FocusNode n) => n.rect.center.dy + (_vScroll(n.context!)?.position.pixels ?? 0);
        final inList = group.where((n) => _vScroll(n.context!) != null).toList();
        if (inList.isNotEmpty) group = inList;
        final top = group.map(content).reduce((a, b) => a < b ? a : b);
        row = [for (final n in group) if ((content(n) - top).abs() <= 40) n];
      } else {
        final nearest = group.map(dist).reduce((a, b) => a < b ? a : b);
        row = [for (final n in group) if ((dist(n) - nearest).abs() <= 40) n];
      }
      final pref = row.where((n) => n.context?.findAncestorWidgetOfExactType<FocusCard>()?.preferred == true).toList();
      if (pref.isNotEmpty) {
        pref.first.requestFocus();
        return true;
      }
      // rangée déjà visitée : on retombe sur l'élément où l'on s'était arrêté
      for (final n in row) {
        final h = _hScroll(n.context!);
        final m = h == null ? null : _mem[h];
        if (m != null && m.context != null && row.contains(m)) {
          m.requestFocus();
          return true;
        }
      }
      var bd = double.infinity;
      for (final n in row) {
        final dx = (n.rect.center.dx - me.center.dx).abs();
        if (dx < bd) {
          bd = dx;
          best = n;
        }
      }
    }
    best?.requestFocus();
    return best != null || horiz;
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: Focus(
        focusNode: _node,
        autofocus: widget.autofocus,
        onFocusChange: (f) {
          setState(() => focused = f);
          if (f) {
            if (Device.tv) {
              _trace();
              final h = _hScroll(context);
              if (h != null) _mem[h] = _node;
            }
            if (Device.tv) {
              _reveal();
            } else {
              Scrollable.ensureVisible(context, alignment: 0.5, duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
            }
            widget.onFocus?.call();
          }
        },
        onKeyEvent: (_, e) {
          final k = e.logicalKey;
          if (_nav(e)) return KeyEventResult.handled;
          if (e is KeyDownEvent && widget.onLong != null && (k == LogicalKeyboardKey.contextMenu || k == LogicalKeyboardKey.gameButtonX)) {
            widget.onLong!();
            return KeyEventResult.handled;
          }
          final ok = k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.gameButtonA;
          if (ok && widget.onLong != null) {
            // appui bref = action, OK maintenu = action longue
            if (e is KeyDownEvent) {
              _long = false;
              _down = true;
            }
            if (e is KeyRepeatEvent) _long = true;      // l'action longue part au relâchement (sinon la fenêtre ouverte reçoit les répétitions de la touche et se referme)
            if (e is KeyUpEvent) {
              if (_down) _long ? widget.onLong!() : widget.onTap();
              _down = false;
              _long = false;
            }
            return KeyEventResult.handled;
          }
          if (e is KeyDownEvent && ok) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();     // iPhone : léger retour au doigt sur chaque appui (sans effet sur la télé)
            widget.onTap();
          },
          onLongPress: widget.onLong == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  widget.onLong!();
                },
          onTapDown: (_) => setState(() => pressed = true),
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          child: AnimatedScale(
            scale: pressed ? 0.955 : (focused ? widget.focusScale : 1),
            duration: Duration(milliseconds: Perf.lite ? 90 : 160),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: Duration(milliseconds: Perf.lite ? 0 : 150),
              foregroundDecoration: widget.ring && focused ? BoxDecoration(borderRadius: BorderRadius.circular(widget.radius), border: Border.all(color: Colors.white, width: 3)) : null,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.radius)),
              child: ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: widget.child),
            ),
          ),
        ),
        ),
      );
}

Widget _placeholder(String title) => Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF222B3D), Color(0xFF141A27)])),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Text(title, textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis, style: T(12, w: 600, color: const Color(0xFF7F8BA0))),
    );

int _imgErrs = 0;

/// les premiers échecs de chargement d'image sont notés dans le journal (adresse sans paramètres) : l'écran « Test de la source » permet de les relire
void _imgErr(String url, Object e) {
  if (_imgErrs++ >= 6) return;
  Journal.add('Image non chargée (${Uri.tryParse(url)?.host ?? '?'})', e);
}

/// w : largeur de décodage en pixels (les images ne sont plus décodées à leur taille d'origine : moins de mémoire, défilement plus fluide)
Widget netImage(String url, String title, {BoxFit fit = BoxFit.cover, Alignment alignment = Alignment.center, int w = 520}) => url.isEmpty
    ? _placeholder(title)
    : CachedNetworkImage(imageUrl: url, fit: fit, alignment: alignment, memCacheWidth: Perf.img(w), fadeInDuration: Duration(milliseconds: Perf.lite ? 0 : 200), placeholder: (_, __) => _placeholder(''), errorWidget: (_, u, e) {
      _imgErr(u, e);
      return _placeholder(title);
    });

/// précharge l'image de fond d'un titre (dès qu'on sait laquelle) pour qu'elle soit déjà là à l'ouverture
void warmBackdrop(BuildContext context, Item it) {
  if (Perf.lite || it.kind == Kind.live) return;
  Tmdb.fiche(it).then((f) {
    if (f == null || f.bg.isEmpty || !context.mounted) return;
    precacheImage(CachedNetworkImageProvider(tmImg(f.bg, 'w1280')), context).catchError((_) {});
  }).catchError((_) {});
}

/// visuel de fond d'une fiche : l'affiche floutée en dessous, puis fondu vers l'image de fond dès qu'elle est prête
/// (l'ancienne image reste affichée tant que la suivante charge : plus de clignotement)
Widget fadeBackdrop(String url, String poster, {int w = 1280}) {
  Widget img(String u, {int fade = 500}) => CachedNetworkImage(
        imageUrl: u,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        memCacheWidth: Perf.img(w),
        useOldImageOnUrlChange: true,
        fadeInDuration: Duration(milliseconds: Perf.lite ? 0 : fade),
        fadeOutDuration: Duration.zero,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      );
  return ClipRect(
      child: Stack(fit: StackFit.expand, children: [
    const ColoredBox(color: Color(0xFF0B0D12)),
    if (poster.isNotEmpty) Perf.lite ? Opacity(opacity: 0.6, child: img(poster, fade: 0)) : ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22, tileMode: TileMode.clamp), child: img(poster, fade: 200)),
    if (url.isNotEmpty) img(url),
  ]));
}

/// verre dépoli (barre d'onglets, boutons)
class Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color color;
  final double blur;
  final Color edge;
  const Glass({super.key, required this.child, this.radius = 28, this.color = kGlass, this.blur = 22, this.edge = kEdge});

  @override
  Widget build(BuildContext context) => Perf.lite
      ? Container(decoration: BoxDecoration(color: Color.alphaBlend(color, const Color(0xF20B0D12)), borderRadius: BorderRadius.circular(radius), border: Border.all(color: edge)), child: child)
      : ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius), border: Border.all(color: edge)), child: child),
        ),
      );
}

/// note : pastille « ★ 7.2 »
class RatingPill extends StatelessWidget {
  final double rating;
  const RatingPill(this.rating, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xA6000000), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0x14FFFFFF))),
        child: Text('★ ${rating == rating.roundToDouble() ? rating.toInt() : rating.toStringAsFixed(1)}', style: T(13.5, w: 700)),
      );
}

/// affiche (2:3) : coins 15, liseré fin, ombre, note, titre et sous-titre dessous
class Poster extends StatelessWidget {
  final Item item;
  final double width;
  final VoidCallback onTap;
  final VoidCallback? onLong;      // appui long (OK maintenu à la télécommande)
  final Widget? badge;             // pastille en surimpression (ex. « − » pour retirer d'une playlist)
  const Poster({super.key, required this.item, required this.width, required this.onTap, this.onLong, this.badge});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), boxShadow: Perf.lite ? null : const [BoxShadow(color: Color(0x99000000), blurRadius: 26, spreadRadius: -16, offset: Offset(0, 14))]),
            child: Semantics(
              label: item.year.isEmpty ? item.title : '${item.title}, ${item.year}',
              child: FocusCard(
              onTap: onTap,
              onLong: onLong,
              radius: 15,
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: Stack(fit: StackFit.expand, children: [
                  netImage(item.icon, item.title),
                  if (badge != null) Positioned(bottom: 8, right: 8, child: badge!),
                  if (item.rating >= 1 && item.rating < 9.5) Positioned(top: 8, right: 8, child: RatingPill(item.rating)),
                  if (item.quality.isNotEmpty) Positioned(top: 8, left: 8, child: _Badge(item.quality)),
                  if (item.isNew && item.quality.isEmpty) Positioned(top: 8, left: 8, child: _Badge(item.kind == Kind.series ? 'Nouvel épisode' : 'Nouveau', accent: true)),
                  Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0x1AFFFFFF), width: 0.6))))),
                ]),
              ),
            ),
            ),
          ),
          const SizedBox(height: 8),
          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(14, w: 600, ls: -0.01)),
          if (item.year.isNotEmpty) Text(item.year, style: T(13, w: 450, color: kMut)),
        ]),
      );
}

class _Badge extends StatelessWidget {
  final String t;
  final bool accent;
  const _Badge(this.t, {this.accent = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: accent ? kAccent : const Color(0xB30A0D14), borderRadius: BorderRadius.circular(99), border: Border.all(color: accent ? Colors.transparent : const Color(0x26FFFFFF), width: 0.5)),
        child: Text(t, style: T(9.5, w: 700, ls: 0.02)),
      );
}

Widget netLogo(String u, double s) => CachedNetworkImage(imageUrl: u, width: s, height: s, fit: BoxFit.contain, errorWidget: (_, __, ___) => SizedBox(width: s, height: s));

/// luminance d'un logo (même règle que l'appli web) : un logo sombre est posé sur une case claire
final _darkCache = <String, bool>{};

Future<bool> isDarkLogo(String url) async {
  if (_darkCache.containsKey(url)) return _darkCache[url]!;
  final c = Completer<ui.Image?>();
  final stream = CachedNetworkImageProvider(url).resolve(ImageConfiguration.empty);
  late ImageStreamListener l;
  l = ImageStreamListener((info, _) {
    if (!c.isCompleted) c.complete(info.image);
    stream.removeListener(l);
  }, onError: (_, __) {
    if (!c.isCompleted) c.complete(null);
    stream.removeListener(l);
  });
  stream.addListener(l);
  final img = await c.future.timeout(const Duration(seconds: 12), onTimeout: () => null);
  var dark = false;
  if (img != null) {
    final ByteData? bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd != null) {
      double a = 0, y = 0;
      for (var yy = 0; yy < 32; yy++) {
        for (var xx = 0; xx < 32; xx++) {
          final px = ((yy * img.height ~/ 32) * img.width + (xx * img.width ~/ 32)) * 4;
          final al = bd.getUint8(px + 3) / 255;
          a += al;
          y += al * (0.2126 * bd.getUint8(px) + 0.7152 * bd.getUint8(px + 1) + 0.0722 * bd.getUint8(px + 2));
        }
      }
      dark = a > 8 && y / a < 105;
    }
  }
  _darkCache[url] = dark;
  return dark;
}

/// case de logo de chaîne
class LogoBox extends StatelessWidget {
  final String url;
  final double w, h, radius;
  const LogoBox(this.url, {super.key, this.w = 58, this.h = 44, this.radius = 9});

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: url.isEmpty ? Future.value(false) : isDarkLogo(url),
        initialData: _darkCache[url],      // déjà connu : pas de clignotement du fond
        builder: (_, s) {
          final dark = s.data == true;
          return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: dark ? const LinearGradient(begin: Alignment(-.5, -1), end: Alignment(.5, 1), colors: [Color(0xFFF4F6FA), Color(0xFFD8DDE6)]) : null,
              color: dark ? null : kBg3,
            ),
            padding: EdgeInsets.symmetric(horizontal: w * .07, vertical: h * .09),
            child: url.isEmpty ? const Icon(Icons.tv, color: Colors.white38) : netImage(url, '', fit: BoxFit.contain),
          );
        },
      );
}

/// ligne de la liste Direct : logo, nom, programme en cours avec sa progression, 4K, favori
class ChannelRow extends StatelessWidget {
  final Chan item;
  final VoidCallback onTap;
  final bool separator;
  final VoidCallback? onLong;
  final int num;      // numéro de la chaîne dans la liste (télé, TNT) ; 0 : rien
  final bool show4k;      // masqué quand toutes les chaînes de la liste sont en 4K (information inutile)
  const ChannelRow({super.key, required this.item, required this.onTap, this.separator = true, this.onLong, this.num = 0, this.show4k = true});

  @override
  Widget build(BuildContext context) {
    final e = _epgFor(item);
    return FocusCard(
      onTap: onTap,
      onLong: onLong,
      radius: 14,
      focusScale: Device.tv ? 1.0 : 1.06,
      child: Container(
        decoration: BoxDecoration(border: separator ? const Border(bottom: BorderSide(color: Color(0x14FFFFFF), width: 0.6)) : null),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(children: [
          if (num > 0) SizedBox(width: 46, child: Text('$num', style: T(22, w: 800, color: kMut))),
          LogoBox(item.icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(16.5, w: 650, ls: -0.01)),
              if (e != null) ...[
                const SizedBox(height: 2),
                Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(14, w: 450, color: const Color(0xFFC4CBD9))),
                const SizedBox(height: 5),
                ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: e.progress, minHeight: 2.5, backgroundColor: const Color(0x26FFFFFF), color: const Color(0xFFB8C2D6))),
                const SizedBox(height: 4),
                Row(children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFE5484D), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('encore ${e.leftMin} min  ·  jusqu\'à ${e.until}', style: T(11.5, w: 450, color: const Color(0xFF7D879B))),
                ]),
              ],
            ]),
          ),
          if (item.is4k && show4k)
            Container(
              margin: const EdgeInsets.only(left: 10),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: const Color(0x0FFFFFFF), borderRadius: BorderRadius.circular(7)),
              child: Text('4K', style: T(Device.tv ? 14 : 11.5, w: 700, color: const Color(0xFF8F99AB))),
            ),
          const SizedBox(width: 6),
          if (Device.tv) ExcludeFocus(child: IgnorePointer(child: FavButton(favKey: 'live:${item.best.item.id}', size: 44, plain: true))) else FavButton(favKey: 'live:${item.best.item.id}', size: 44, plain: true),
        ]),
      ),
    );
  }
}

/// programme en cours d'une chaîne (le demande au fournisseur s'il n'est pas encore connu)
EpgNow? _epgFor(Chan c) {
  if (c.epgId.isEmpty) return null;
  Epg.want(c.epgId, [for (final v in c.v) v.item.id]);
  return Epg.now(c.epgId);
}

/// tuile de chaîne (rangée « Mes chaînes »)
class ChannelTile extends StatelessWidget {
  final Chan item;
  final VoidCallback onTap;
  const ChannelTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 132,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FocusCard(onTap: onTap, radius: 18, child: Container(decoration: BoxDecoration(border: Border.all(color: const Color(0x14FFFFFF))), child: LogoBox(item.icon, w: 132, h: 88, radius: 18))),
          const SizedBox(height: 8),
          Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(14, w: 600)),
          if (_epgFor(item) != null) Text(_epgFor(item)!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(12.5, w: 450, color: kMut)),
        ]),
      );
}

/// titre de section (« Tout voir › » facultatif)
class SectionTitle extends StatelessWidget {
  final String title;
  final VoidCallback? onMore;
  final String moreLabel;
  const SectionTitle(this.title, {super.key, this.onMore, this.moreLabel = 'Tout voir'});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 12),
        child: Row(children: [
          Expanded(child: Text(title, style: T(22, w: 780, ls: -0.025))),
          // sélectionnable à la télécommande aussi (avant : toucher seulement)
          if (onMore != null)
            FocusCard(
              onTap: onMore!,
              radius: 12,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(moreLabel.isEmpty ? 'Tout voir ›' : '$moreLabel ›', style: T(15, w: 500, color: kMut))),
            ),
        ]),
      );
}

/// rangée horizontale avec titre
class Rail extends StatelessWidget {
  final String title;
  final double height;
  final int count;
  final Widget Function(BuildContext, int) builder;
  final VoidCallback? onMore;
  final String moreLabel;
  const Rail({super.key, required this.title, required this.height, required this.count, required this.builder, this.onMore, this.moreLabel = 'Tout voir'});

  @override
  Widget build(BuildContext context) => count == 0
      ? const SizedBox.shrink()
      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(title, onMore: Device.tv ? null : onMore, moreLabel: moreLabel),
          SizedBox(
            height: height,
            child: ListView.separated(
              cacheExtent: Device.tv ? 1200 : null,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: count + (Device.tv && onMore != null ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (c, i) => i < count
                  ? builder(c, i)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 44),
                      child: FocusCard(
                        onTap: onMore!,
                        radius: 16,
                        child: Container(
                          width: 150,
                          alignment: Alignment.center,
                          color: const Color(0x14FFFFFF),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.arrow_forward_rounded, size: 34, color: Colors.white),
                            const SizedBox(height: 8),
                            Text(moreLabel.isEmpty ? 'Tout voir' : moreLabel, style: T(16, w: 650)),
                          ]),
                        ),
                      ),
                    ),
            ),
          ),
        ]);
}

/// « Top 10 » : gros chiffre en contour à côté de l'affiche
class Top10Card extends StatelessWidget {
  final int rank;
  final Item item;
  final double width;
  final VoidCallback onTap;
  const Top10Card({super.key, required this.rank, required this.item, required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final digits = '$rank';
    final numW = digits.length > 1 ? 150.0 : 92.0;
    return SizedBox(
      width: numW - 40 + width,
      child: Stack(children: [
        Positioned(
          left: 0,
          bottom: 38,
          child: Text(digits, style: T(150, w: 800, ls: -0.06, h: 0.9).copyWith(foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = const Color(0xAAB0B8C8))),
        ),
        Positioned(left: numW - 40, top: 0, bottom: 0, child: Poster(item: item, width: width, onTap: onTap)),
      ]),
    );
  }
}

/// pastilles de filtre (catégories)
class Chips extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final void Function(int) onSelect;
  final List<Widget?>? leading;
  final List<Color?>? tints;      // couleur de la puce choisie (ex. couleur d'une compétition)
  const Chips({super.key, required this.labels, required this.selected, required this.onSelect, this.leading, this.tints});

  Color? _t(int i) => tints != null && i < tints!.length ? tints![i] : null;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => FocusCard(
            onTap: () => onSelect(i),
            radius: 22,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: i == selected ? (_t(i) ?? kText) : const Color(0x14FFFFFF), border: Border.all(color: i == selected ? (_t(i) ?? kText) : (_t(i)?.withOpacity(0.45) ?? const Color(0x1FFFFFFF))), borderRadius: BorderRadius.circular(22)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [if (leading != null && i < leading!.length && leading![i] != null) ...[leading![i]!, const SizedBox(width: 7)], Text(labels[i], style: T(14.5, w: 600, color: i == selected ? (_t(i) != null ? Colors.white : kBg) : const Color(0xFFC9D2E2)))]),
            ),
          ),
        ),
      );
}

/// bouton rond (réglages, retour, +)
class RoundButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final String label;     // lu par VoiceOver / TalkBack
  const RoundButton({super.key, required this.child, this.onTap, this.size = 44, this.color = const Color(0xFF0B0D12), this.label = ''});

  @override
  Widget build(BuildContext context) => Semantics(
        label: label.isEmpty ? null : label,
        button: true,
        child: FocusCard(
          onTap: onTap ?? () {},
          radius: size / 2,
          child: Container(width: size, height: size, alignment: Alignment.center, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: const Color(0x2EFFFFFF), width: 0.6)), child: child),
        ),
      );
}

/// bouton pilule : blanc (principal) ou verre
class PillButton extends StatelessWidget {
  final String label;
  final String? icon;
  final bool primary;
  final VoidCallback onTap;
  final VoidCallback? onLong;
  final double height;
  final bool autofocus;
  const PillButton({super.key, required this.label, this.icon, this.primary = false, required this.onTap, this.onLong, this.height = 50, this.autofocus = false});

  @override
  Widget build(BuildContext context) => FocusCard(
        autofocus: autofocus && Device.tv,
        onTap: onTap,
        onLong: onLong,
        radius: height / 2,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(color: primary ? Colors.white : const Color(0x24FFFFFF), borderRadius: BorderRadius.circular(height / 2), border: primary ? null : Border.all(color: kEdge)),
          child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Ic(icon!, size: 20, color: primary ? kBg : kText, stroke: 1.9), const SizedBox(width: 8)],
            Text(label, style: T(17, w: 700, color: primary ? kBg : kText, ls: -0.01)),
          ]),
        ),
      );
}

/// grande affiche d'accueil : visuel pleine largeur, titre, infos, résumé, boutons ; défile toute seule
class HeroBanner extends StatefulWidget {
  final List<Item> items;
  final Future<Detail?> Function(Item) detailFor;
  final void Function(Item) onPlay, onInfo;
  const HeroBanner({super.key, required this.items, required this.detailFor, required this.onPlay, required this.onInfo});
  @override
  State<HeroBanner> createState() => _HeroState();
}

class _HeroState extends State<HeroBanner> {
  final page = PageController();
  int i = 0;
  bool _regain = false;      // télé : la nouvelle affiche reprend le focus de la précédente
  Timer? t;

  @override
  void initState() {
    super.initState();
    if (!Perf.lite) t = Timer.periodic(const Duration(seconds: 9), (_) {
      if (!mounted || widget.items.length < 2 || !page.hasClients) return;
      page.animateToPage((i + 1) % widget.items.length, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    t?.cancel();
    page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final size = MediaQuery.sizeOf(context);
    final h = wide ? 480.0 : (size.height * 0.64).clamp(460.0, 600.0);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, e) {
        // télé : ← → changent de grande affiche (pas de glissement : le bouton garde le focus)
        if (!Device.tv || e is KeyUpEvent) return KeyEventResult.ignored;
        final k = e.logicalKey;
        if (k != LogicalKeyboardKey.arrowLeft && k != LogicalKeyboardKey.arrowRight) return KeyEventResult.ignored;
        final n = i + (k == LogicalKeyboardKey.arrowLeft ? -1 : 1);
        if (n >= 0 && n < widget.items.length && e is KeyDownEvent) {
          setState(() => i = n);
          _regain = true;
          if (n + 1 < widget.items.length) warmBackdrop(context, widget.items[n + 1]);
        }
        return KeyEventResult.handled;
      },
      child: SizedBox(
      height: h,
      child: Stack(children: [
        if (Device.tv)
          KeyedSubtree(key: ValueKey(i), child: _Slide(item: widget.items[i], detailFor: widget.detailFor, wide: wide, onPlay: widget.onPlay, onInfo: widget.onInfo, autofocus: _regain))
        else
        PageView.builder(
          controller: page,
          itemCount: widget.items.length,
          onPageChanged: (v) {
            setState(() => i = v);
            if (widget.items.length > 1) warmBackdrop(context, widget.items[(v + 1) % widget.items.length]);
          },
          itemBuilder: (_, k) => _Slide(item: widget.items[k], detailFor: widget.detailFor, wide: wide, onPlay: widget.onPlay, onInfo: widget.onInfo),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 4,
          child: Row(mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center, children: [
            if (wide) const SizedBox(width: 28),
            for (var k = 0; k < widget.items.length; k++)
              AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.symmetric(horizontal: 3), height: 6, width: k == i ? 18 : 6, decoration: BoxDecoration(color: k == i ? Colors.white : const Color(0x55FFFFFF), borderRadius: BorderRadius.circular(3))),
          ]),
        ),
      ]),
    ));
  }
}

class _Slide extends StatelessWidget {
  final Item item;
  final Future<Detail?> Function(Item) detailFor;
  final bool wide;
  final void Function(Item) onPlay, onInfo;
  final bool autofocus;
  const _Slide({required this.item, required this.detailFor, required this.wide, required this.onPlay, required this.onInfo, this.autofocus = false});

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
        // le serveur du fournisseur peut être lent ou injoignable (Wi-Fi maison) : on n'attend pas plus de 5 s ses détails, l'image vient de TMDB
        future: Future.wait<dynamic>([
          detailFor(item).timeout(const Duration(seconds: 5), onTimeout: () => null).catchError((_) => null),
          Tmdb.fiche(item).timeout(const Duration(seconds: 10), onTimeout: () => null).catchError((_) => null),
        ]),
        builder: (_, s) {
          final d = s.data?[0] as Detail?;
          final f = s.data?[1] as Fiche?;
          final ready = s.connectionState == ConnectionState.done;      // tant que ça charge : l'affiche floutée seulement
          final img = !ready ? '' : (f != null && f.bg.isNotEmpty ? tmImg(f.bg, 'w1280') : (d != null && d.backdrop.isNotEmpty ? d.backdrop : item.icon));
          final meta = [item.kind == Kind.series ? 'Série' : 'Film', if (d != null && d.year.isNotEmpty) d.year else if (item.year.isNotEmpty) item.year, if (item.rating >= 1) '★ ${item.rating.toStringAsFixed(1)}'].join('  ·  ');
          final plot = f != null && f.plot.isNotEmpty ? f.plot : (d?.plot ?? '');
          return Stack(fit: StackFit.expand, children: [
            Perf.lite ? fadeBackdrop(img, item.icon) : Opacity(opacity: 0.92, child: fadeBackdrop(img, item.icon)),
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, .22, .42, .97], colors: [Color(0x6606080D), Color(0x0006080D), Color(0x0006080D), kBg]))),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, wide ? 400 : 20, 34),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TitleLogo(ready: ready, url: f != null && f.logo.isNotEmpty ? tmImg(f.logo, 'w500') : '', title: f != null && f.title.isNotEmpty ? f.title : item.title, big: true, wide: wide),
                const SizedBox(height: 10),
                Text(meta, style: T(16, w: 500, color: const Color(0xFFC4CBD9))),
                if (plot.isNotEmpty) ...[const SizedBox(height: 8), Text(plot, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(16, w: 400, color: const Color(0xFFDFE5F0), h: 1.35))],
                const SizedBox(height: 18),
                if (Device.tv)
                  // télé : un seul bouton, OK = lecture, appui long = détails
                  Row(children: [
                    PillButton(label: item.kind == Kind.series ? 'Voir la série' : 'Lecture', icon: 'play', primary: true, height: 52, autofocus: autofocus, onTap: () => onPlay(item), onLong: () => onInfo(item)),
                    const SizedBox(width: 14),
                    Text('Maintiens OK : détails', style: T(13.5, color: kMut)),
                  ])
                else
                  Row(children: [
                    Expanded(child: PillButton(label: item.kind == Kind.series ? 'Voir la série' : 'Lecture', icon: 'play', primary: true, height: 48, onTap: () => onPlay(item))),
                    const SizedBox(width: 10),
                    PillButton(label: 'Détails', height: 48, onTap: () => onInfo(item)),
                    const SizedBox(width: 10),
                    FavButton(favKey: '${item.kind.name}:${item.id}', size: 48),
                  ]),
                const SizedBox(height: 14),
              ]),
            ),
          ]);
        },
      );
}

/// titre : logo TMDB (blanc si sombre) ou texte
class TitleLogo extends StatelessWidget {
  final String url, title;
  final bool big, wide;
  final bool ready;      // faux tant que la fiche charge : on réserve la place sans afficher de titre provisoire
  const TitleLogo({super.key, required this.url, required this.title, this.big = false, this.wide = false, this.ready = true});

  @override
  Widget build(BuildContext context) {
    final txt = Text(title.toUpperCase(), maxLines: 3, overflow: TextOverflow.ellipsis, style: T(big ? (wide ? 54 : 44) : 28, w: 900, ls: -0.03, h: 0.98).copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 14, offset: Offset(0, 2))]));
    if (!ready) return SizedBox(height: big ? 96 : 64);
    if (url.isEmpty) return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: KeyedSubtree(key: const ValueKey('txt'), child: txt));
    return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: KeyedSubtree(key: ValueKey(url), child: _logo(context, txt)));
  }

  Widget _logo(BuildContext context, Widget txt) {
    return FutureBuilder<bool>(
      future: isDarkLogo(url),
      builder: (_, s) {
        Widget im = CachedNetworkImage(imageUrl: url, height: big ? 96 : 64, fit: BoxFit.contain, alignment: Alignment.centerLeft, errorWidget: (_, __, ___) => txt);
        if (s.data == true) im = ColorFiltered(colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn), child: im);
        return Align(alignment: Alignment.centerLeft, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7), child: im));
      },
    );
  }
}

/// barre de navigation « pastille » en verre (en bas sur téléphone, en haut sur grand écran)
class NavPill extends StatelessWidget {
  final int index;
  final void Function(int) onSelect;
  final VoidCallback onSearch;
  final List<int> order;      // onglets affichés, dans l'ordre choisi (0 Accueil, 1 Direct, 2 Films, 3 Séries, 4 Sport)
  final PageController? pages;      // glissement entre onglets : la pastille suit le doigt
  const NavPill({super.key, required this.index, required this.onSelect, required this.onSearch, this.order = const [0, 1, 2, 3, 4], this.pages});

  static const _tabs = [
    (CupertinoIcons.house_fill, 'Accueil'),
    (CupertinoIcons.tv_fill, 'Direct'),
    (CupertinoIcons.film_fill, 'Films'),
    (CupertinoIcons.rectangle_stack_fill, 'Séries'),
    (CupertinoIcons.sportscourt_fill, 'Sport'),
  ];
  static const _ink = Color(0xFFF2F4FA);

  /// verre dépoli : flou fort, teinte claire translucide, reflet en haut, liseré lumineux, ombre douce
  static Widget glass({required Widget child, double radius = 34}) {
    final deco = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x38FFFFFF), Color(0x14FFFFFF), Color(0x1FFFFFFF)]),
      border: Border.all(color: const Color(0x52FFFFFF), width: 0.9),
    );
    if (Perf.lite) return Container(decoration: BoxDecoration(color: const Color(0xF2171A22), borderRadius: BorderRadius.circular(radius), border: Border.all(color: const Color(0x33FFFFFF))), child: child);
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 28, offset: Offset(0, 10))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 38, sigmaY: 38), child: DecoratedBox(decoration: deco, child: child)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final vis = order;
    final n = vis.length;
    final bar = glass(
      child: SizedBox(
        height: 64,
        child: LayoutBuilder(builder: (ctx, c) {
          final w = wide ? 0.0 : (c.maxWidth - 8) / n;
          void drag(DragUpdateDetails d) {
            // le doigt qui glisse sur la barre change d'onglet
            final i = ((d.localPosition.dx - 4) / w).floor().clamp(0, n - 1);
            if (vis[i] != index) {
              HapticFeedback.selectionClick();
              onSelect(vis[i]);
            }
          }
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: wide ? null : drag,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(children: [
                if (!wide)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: pages ?? const AlwaysStoppedAnimation(0),
                      builder: (_, __) {
                        final cur = vis.indexOf(index).toDouble();
                        final pos = (pages != null && pages!.hasClients ? (pages!.page ?? cur) : cur).clamp(0.0, n - 1.0);
                        return Align(
                          alignment: Alignment(n <= 1 ? 0 : -1 + 2 * pos / (n - 1), 0),
                          child: FractionallySizedBox(
                            widthFactor: 1 / n,
                            heightFactor: 1,
                            child: Container(decoration: BoxDecoration(color: const Color(0x4D000000), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0x26FFFFFF), width: 0.8))),
                          ),
                        );
                      },
                    ),
                  ),
                Row(mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max, children: [for (final k in vis) _item(k, wide)]),
              ]),
            ),
          );
        }),
      ),
    );
    final search = glass(
      child: Semantics(label: 'Recherche', button: true, child: FocusCard(onTap: onSearch, radius: 32, child: const SizedBox(width: 64, height: 64, child: Center(child: Icon(CupertinoIcons.search, size: 26, color: _ink))))),
    );
    return wide ? Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [bar, const SizedBox(width: 10), search]) : Row(children: [Expanded(child: bar), const SizedBox(width: 10), search]);
  }

  Widget _item(int k, bool wide) {
    final on = k == index;
    final col = on ? kAccent : _ink;
    final w = FocusCard(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect(k);
      },
      onFocus: Device.tv && k != index ? () => onSelect(k) : null,
      preferred: on,
      autofocus: Device.tv && on,      // télé : au lancement, le focus est sur l'onglet ouvert (flèche bas = entrer dans la page)
      radius: 30,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: wide ? 22 : 2),
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: on && wide ? const Color(0x4D000000) : Colors.transparent, borderRadius: BorderRadius.circular(30)),
        child: wide
            ? Row(mainAxisSize: MainAxisSize.min, children: [Icon(_tabs[k].$1, size: 24, color: col), const SizedBox(width: 8), Text(_tabs[k].$2, style: T(15, w: 700, color: col))])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_tabs[k].$1, size: 26, color: col), const SizedBox(height: 3), Text(_tabs[k].$2, maxLines: 1, style: T(11.5, w: 650, color: col))]),
      ),
    );
    return wide ? w : Expanded(child: w);
  }
}

/// tuile de plateforme (rangée « Plateformes »)
class PlatTile extends StatelessWidget {
  final String keyName, name;
  final VoidCallback onTap;
  const PlatTile({super.key, required this.keyName, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final logo = platLogos[keyName];
    return SizedBox(
      width: 104,
      child: Column(children: [
        FocusCard(
          onTap: onTap,
          radius: 22,
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: kBg3, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0x14FFFFFF), width: 0.6)),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: logo != null ? CachedNetworkImage(imageUrl: 'https://image.tmdb.org/t/p/w185$logo', fit: BoxFit.cover, width: 96, height: 96, errorWidget: (_, __, ___) => Padding(padding: const EdgeInsets.all(8), child: Center(child: Text(name, textAlign: TextAlign.center, style: T(13, w: 700))))) : Padding(padding: const EdgeInsets.all(8), child: Text(name, textAlign: TextAlign.center, style: T(13, w: 700))),
          ),
        ),
        const SizedBox(height: 7),
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(12, w: 600, color: kMut)),
      ]),
    );
  }
}

/// tuile de genre (teinte propre à chaque genre)
class GenreTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const GenreTile({super.key, required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hu = genreHue(name).toDouble();
    return SizedBox(
      width: 178,
      height: 88,
      child: FocusCard(
        onTap: onTap,
        radius: 20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x22FFFFFF), width: 0.8),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [HSLColor.fromAHSL(1, hu, 0.55, 0.24).toColor(), HSLColor.fromAHSL(1, (hu + 40) % 360, 0.50, 0.13).toColor()]),
          ),
          child: Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0x1CFFFFFF), borderRadius: BorderRadius.circular(12)), child: Center(child: Ic(genreIcon(name), size: 24))),
            const SizedBox(width: 10),
            Expanded(child: Text(pretty(name), maxLines: 2, overflow: TextOverflow.ellipsis, style: T(15, w: 750, h: 1.15))),
          ]),
        ),
      ),
    );
  }
}


/// bouton « + » / ✓ (ma liste) ou étoile (chaînes)
class FavButton extends StatefulWidget {
  final String favKey;
  final double size;
  final bool plain;
  const FavButton({super.key, required this.favKey, this.size = 48, this.plain = false});
  @override
  State<FavButton> createState() => _FavButtonState();
}

class _FavButtonState extends State<FavButton> {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(valueListenable: Store.favTick, builder: (_, __, ___) => _body(context));

  Widget _body(BuildContext context) {
    final on = Store.isFav(widget.favKey);
    // « + » d'un film ou d'une série : même menu partout (Ma liste et playlists) ; l'étoile d'une chaîne reste un simple interrupteur
    final tap = () async {
      HapticFeedback.selectionClick();
      if (widget.plain) {
        await Store.toggleFav(widget.favKey);
        if (mounted) setState(() {});
      } else {
        collectionSheet(context, widget.favKey);
      }
    };
    final lab = widget.plain ? (on ? 'Retirer des chaînes favorites' : 'Ajouter aux chaînes favorites') : (on ? 'Retirer de ma liste' : 'Ajouter à ma liste');
    if (widget.plain) {
      return Semantics(label: lab, button: true, child: FocusCard(onTap: tap, radius: widget.size / 2, child: SizedBox(width: widget.size, height: widget.size, child: Icon(on ? Icons.star_rounded : Icons.star_border_rounded, size: 24, color: on ? const Color(0xFFFFD166) : const Color(0xFF6F7A90)))));
    }
    return Semantics(
      label: lab,
      button: true,
      child: FocusCard(
        onTap: tap,
        radius: widget.size / 2,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x2EFFFFFF), border: Border.all(color: const Color(0x38FFFFFF), width: 0.6)),
          child: Icon(on ? Icons.check_rounded : Icons.add_rounded, size: 24, color: kText),
        ),
      ),
    );
  }
}

/// carte « Continuer à regarder »
class ContinueCard extends StatelessWidget {
  final Prog p;
  final VoidCallback onTap, onRemove;
  const ContinueCard({super.key, required this.p, required this.onTap, required this.onRemove});

  String _dur(int ms) {
    final m = ms ~/ 60000;
    return m >= 60 ? '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}' : '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final left = p.dur > 0 ? '${_dur(p.dur - p.pos)} restantes' : '';
    return SizedBox(
      width: 300,
      child: FocusCard(
        onTap: onTap,
        onLong: onRemove,
        radius: 20,
        child: GestureDetector(
          onLongPress: onRemove,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: const Color(0xB8161B26), border: Border.all(color: const Color(0x1FFFFFFF), width: 0.8)),
            child: Row(children: [
              SizedBox(
                width: 62,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(aspectRatio: 2 / 3, child: Stack(fit: StackFit.expand, children: [
                    netImage(p.icon, p.name),
                    Center(child: Container(width: 30, height: 30, decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle), child: const Center(child: Ic('play', size: 15)))),
                  ])),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.sname.isEmpty ? p.name : p.sname, maxLines: 2, overflow: TextOverflow.ellipsis, style: T(15, w: 700, h: 1.2)),
                  if (p.sname.isNotEmpty) Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(12.5, w: 500, color: kMut)),
                  const SizedBox(height: 6),
                  if (p.dur > 0) Text('${_dur(p.dur)}  ·  $left', style: T(12.5, w: 500, color: kMut)),
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: p.dur > 0 ? (p.pos / p.dur).clamp(0.0, 1.0) : 0, minHeight: 3, backgroundColor: const Color(0x26FFFFFF), color: Colors.white)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// studio : affiche du premier titre + nom sur plaque sombre
class StudioTile extends StatelessWidget {
  final String name, icon, logo;
  final VoidCallback onTap;
  const StudioTile({super.key, required this.name, required this.icon, this.logo = '', required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: FocusCard(
          onTap: onTap,
          radius: 18,
          child: Container(
          decoration: BoxDecoration(color: const Color(0xFF14161C), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x1FFFFFFF), width: 0.8)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Expanded(child: icon.isEmpty ? const SizedBox.expand() : CachedNetworkImage(imageUrl: icon, fit: BoxFit.cover, width: 150, errorWidget: (_, __, ___) => const SizedBox.expand())),
            Container(
              height: 54,
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: logo.isEmpty ? null : const Color(0xFFEDEEF2),
              child: logo.isEmpty ? Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(15, w: 700)) : CachedNetworkImage(imageUrl: logo, fit: BoxFit.contain, errorWidget: (_, __, ___) => Text(name, maxLines: 1, style: T(14, w: 700, color: Colors.black))),
            ),
          ]),
          ),
        ),
      );
}


/// transition douce entre écrans (fondu + léger glissement)
Route<T> softRoute<T>(WidgetBuilder builder) => !Device.tv ? CupertinoPageRoute<T>(builder: builder) : PageRouteBuilder<T>(
      pageBuilder: (c, _, __) => builder(c),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, a, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
      ),
    );

/// écran de chargement : cases grises qui respirent à la place des affiches
class SkeletonPage extends StatefulWidget {
  final bool rows;
  const SkeletonPage({super.key, this.rows = false});
  @override
  State<SkeletonPage> createState() => _SkeletonState();
}

class _SkeletonState extends State<SkeletonPage> with SingleTickerProviderStateMixin {
  late final AnimationController c = _pulse(this);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Widget box(double w, double h, [double r = 14]) => Container(width: w, height: h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(r)));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 70;
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) => Opacity(
        opacity: Perf.lite ? 0.07 : 0.04 + 0.05 * c.value,
        child: ListView(physics: const NeverScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(20, top, 20, 0), children: [
          if (widget.rows) ...[
            for (var i = 0; i < 8; i++) Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(children: [box(56, 56, 12), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [box(150, 14, 6), const SizedBox(height: 8), box(230, 11, 6)]))])),
          ] else ...[
            box(double.infinity, 300, 22),
            const SizedBox(height: 26),
            for (var r = 0; r < 2; r++) ...[
              box(160, 18, 6),
              const SizedBox(height: 12),
              Row(children: [for (var i = 0; i < 3; i++) Padding(padding: const EdgeInsets.only(right: 10), child: box(112, 168, 14))]),
              const SizedBox(height: 24),
            ],
          ],
        ]),
      ),
    );
  }
}

/// état vide : icône, phrase, action facultative (sélectionnable à la télécommande)
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final String? action;
  final VoidCallback? onAction;
  final bool compact;     // dans une rangée de l'accueil
  const EmptyState({super.key, required this.icon, required this.title, this.sub = '', this.action, this.onAction, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: compact ? 56 : 76,
      height: compact ? 56 : 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(compact ? 18 : 24), border: Border.all(color: kEdge, width: 0.8)),
      child: Icon(icon, size: compact ? 26 : 32, color: kMut),
    );
    final texts = <Widget>[
      Text(title, textAlign: compact ? TextAlign.start : TextAlign.center, style: T(compact ? 15.5 : 17, w: 700)),
      if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub, textAlign: compact ? TextAlign.start : TextAlign.center, style: T(13.5, color: kMut, h: 1.35))),
    ];
    final act = action != null && onAction != null ? PillButton(label: action!, height: 44, onTap: onAction!) : null;
    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Row(children: [
          box,
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: texts)),
          if (act != null) ...[const SizedBox(width: 10), act],
        ]),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          box,
          const SizedBox(height: 18),
          ...texts,
          if (act != null) ...[const SizedBox(height: 18), act],
        ]),
      ),
    );
  }
}

/// premier lancement : « Compte → Source → Catégories », étape en cours en couleur
class Steps extends StatelessWidget {
  final int current;     // 0, 1 ou 2
  const Steps(this.current, {super.key});
  static const _names = ['Compte', 'Source', 'Catégories'];

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Étape ${current + 1} sur 3 : ${_names[current]}',
        child: ExcludeSemantics(
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 4, children: [
            for (var i = 0; i < _names.length; i++) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: i == current ? kAccent : (i < current ? const Color(0x2E5B8CFF) : const Color(0x14FFFFFF)), borderRadius: BorderRadius.circular(99)),
                child: Text('${i + 1}. ${_names[i]}', style: T(12.5, w: 700, color: i == current ? Colors.white : (i < current ? const Color(0xFFB9CCFF) : kMut))),
              ),
              if (i < _names.length - 1) const Icon(Icons.chevron_right_rounded, size: 16, color: kMut),
            ],
          ]),
        ),
      );
}

/// bloc de chargement (cases qui respirent) à placer dans une liste : fiche, recherche
class SkeletonBlock extends StatefulWidget {
  final int lines;
  const SkeletonBlock({super.key, this.lines = 4});
  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock> with SingleTickerProviderStateMixin {
  late final AnimationController c = _pulse(this);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Widget _box(double? w, double h, [double r = 8]) => Container(width: w, height: h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(r)));

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => Opacity(
            opacity: 0.05 + 0.05 * c.value,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _box(double.infinity, 54, 27),
                const SizedBox(height: 10),
                _box(double.infinity, 44, 22),
                const SizedBox(height: 22),
                for (var i = 0; i < widget.lines; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: _box(i == widget.lines - 1 ? 180 : double.infinity, 13, 6)),
              ]),
            ),
          ),
        ),
      );
}

/// écrans de démarrage (compte, source) : sur grand écran (télé), deux colonnes qui occupent toute la largeur — formulaire à gauche,
/// connexion par le téléphone (code, QR) à droite ; sur téléphone, une seule colonne comme avant
class AuthLayout extends StatelessWidget {
  final int step;
  final String text;
  final List<Widget> top, form, side;     // top : bloc au-dessus du texte (ex. bouton retour) ; side : colonne de droite sur grand écran
  const AuthLayout({super.key, required this.step, required this.text, required this.form, this.side = const [], this.top = const [], });

  static bool wide(BuildContext c) => Device.tv;     // télé seulement : deux colonnes ; iPad et tablettes gardent la mise en page tactile

  @override
  Widget build(BuildContext context) {
    final w = wide(context);
    final head = w
        ? [
            Row(children: [
              SvgPicture.asset('assets/logo.svg', height: 52),
              const SizedBox(width: 14),
              Text('MinouFlix', style: T(34, w: 850, ls: -0.04)),
            ]),
            const SizedBox(height: 10),
            Steps(step),
            const SizedBox(height: 10),
            Text(text, style: T(15, color: kMut, h: 1.35)),
          ]
        : [
            Center(child: SvgPicture.asset('assets/logo.svg', height: 96)),
            const SizedBox(height: 10),
            Center(child: Text('MinouFlix', style: T(36, w: 850, ls: -0.04))),
            const SizedBox(height: 12),
            Center(child: Steps(step)),
            const SizedBox(height: 12),
            Text(text, style: T(15, color: kMut)),
          ];
    return Scaffold(
      body: SafeArea(
        child: w && side.isNotEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 24),
                  child: Row(children: [
                    Expanded(
                      flex: 11,
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [...top, ...head, const SizedBox(height: 24), ...form])),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                    Expanded(
                      flex: 9,
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: side)),
                        ),
                      ),
                    ),
                  ]),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(28), children: [
                    ...top,
                    ...head,
                    if (side.isNotEmpty) ...[const SizedBox(height: 16), ...side.expand((x) => [x, const SizedBox(height: 12)])],
                    const SizedBox(height: 8),
                    ...form,
                  ]),
                ),
              ),
      ),
    );
  }
}

/// pulsation des squelettes de chargement ; figée en mode léger (une animation plein écran coûte cher sur une petite télé)
AnimationController _pulse(TickerProvider v) {
  final c = AnimationController(vsync: v, duration: const Duration(milliseconds: 1100));
  if (Perf.lite) {
    c.value = 0.5;
  } else {
    c.repeat(reverse: true);
  }
  return c;
}


/// texte de l'appli : traduit à l'affichage selon la langue choisie (les textes sont écrits en français dans le code)
class Text extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;
  final String? semanticsLabel;
  final TextScaler? textScaler;
  const Text(this.data, {super.key, this.style, this.maxLines, this.overflow, this.textAlign, this.softWrap, this.semanticsLabel, this.textScaler});
  @override
  Widget build(BuildContext context) => mat.Text(L.tr(data), style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign, softWrap: softWrap, semanticsLabel: semanticsLabel, textScaler: textScaler);
}

// ---------- fenêtres et feuilles façon iOS (verre dépoli, angles larges, boutons séparés par des filets) ----------

/// Boîte de dialogue : panneau en verre dépoli, titre centré, boutons côte à côte (ou empilés au-delà de deux) séparés par un filet fin.
/// Mêmes paramètres qu'AlertDialog (backgroundColor est ignoré).
class AppDialog extends StatelessWidget {
  final Widget? title, content;
  final List<Widget> actions;
  final Color? backgroundColor;
  const AppDialog({super.key, this.title, this.content, this.actions = const [], this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final tv = Device.tv, lite = Perf.lite;
    final th = Theme.of(context);
    const line = Color(0x2EFFFFFF);
    final base = TextButton.styleFrom(
      foregroundColor: kAccent,
      minimumSize: Size.fromHeight(tv ? 60 : 52),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: const RoundedRectangleBorder(),
      textStyle: T(tv ? 19 : 17, w: 500),
    );
    final last = base.merge(TextButton.styleFrom(textStyle: T(tv ? 19 : 17, w: 650)));
    Widget cell(int i) => Theme(
          data: th.copyWith(textButtonTheme: TextButtonThemeData(style: i == actions.length - 1 ? last : base)),
          child: actions[i],
        );
    Widget bar() {
      if (actions.isEmpty) return const SizedBox.shrink();
      if (actions.length <= 2) {
        return IntrinsicHeight(
          child: Row(children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const VerticalDivider(width: .6, thickness: .6, color: line),
              Expanded(child: cell(i)),
            ],
          ]),
        );
      }
      return Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const Divider(height: .6, thickness: .6, color: line),
          cell(i),
        ],
      ]);
    }

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: lite ? const Color(0xFF1B1F2A) : const Color(0xD91B1F2A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1FFFFFFF), width: .6),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(22, tv ? 28 : 24, 22, tv ? 24 : 20),
            child: Theme(
              data: th.copyWith(
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0x3D767680),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  hintStyle: T(16, color: kMut),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: kAccent, width: 1.2)),
                ),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (title != null)
                  DefaultTextStyle.merge(style: T(tv ? 21 : 18, w: 650), textAlign: TextAlign.center, child: title!),
                if (title != null && content != null) const SizedBox(height: 14),
                if (content != null) DefaultTextStyle.merge(style: T(tv ? 16 : 14, color: kMut, h: 1.35), textAlign: TextAlign.center, child: content!),
              ]),
            ),
          ),
        ),
        if (actions.isNotEmpty) const Divider(height: .6, thickness: .6, color: line),
        bar(),
      ]),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: tv ? 60 : 34, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tv ? 580 : 350),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            builder: (_, v, c) => Opacity(opacity: v, child: Transform.scale(scale: .94 + .06 * v, child: c)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: lite ? panel : BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28), child: panel),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille du bas : verre dépoli, grand arrondi en haut, petite poignée ; remplace showModalBottomSheet.
/// télé : les feuilles du bas deviennent un panneau centré (lisible à 3 m, premier élément déjà sélectionné)
class _TvPanel extends StatefulWidget {
  final Widget child;
  const _TvPanel({required this.child});
  @override
  State<_TvPanel> createState() => _TvPanelState();
}

class _TvPanelState extends State<_TvPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<_TvPanel>() == null) FocusScope.of(context).nextFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 780, maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: Material(
          color: const Color(0xFF1B1F2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26), side: const BorderSide(color: Color(0x24FFFFFF), width: .8)),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: th.copyWith(
              listTileTheme: ListTileThemeData(contentPadding: const EdgeInsets.symmetric(horizontal: 28), minVerticalPadding: 14, horizontalTitleGap: 16, titleTextStyle: T(19, w: 550), subtitleTextStyle: T(15, color: kMut), iconColor: kText, textColor: kText),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

Future<T?> appSheet<T>({required BuildContext context, required WidgetBuilder builder, bool isScrollControlled = false}) => Device.tv
    ? showDialog<T>(context: context, barrierColor: const Color(0xB3000000), builder: (c) => _TvPanel(child: builder(c)))
    : _appSheet<T>(context: context, builder: builder, isScrollControlled: isScrollControlled);

Future<T?> _appSheet<T>({required BuildContext context, required WidgetBuilder builder, bool isScrollControlled = false}) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x99000000),
      elevation: 0,
      builder: (c) => _SheetFrame(child: builder(c)),
    );

class _SheetFrame extends StatelessWidget {
  final Widget child;
  const _SheetFrame({required this.child});
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: Perf.lite ? const Color(0xFF1B1F2A) : const Color(0xE61B1F2A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: const Border(top: BorderSide(color: Color(0x24FFFFFF), width: .6)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 9),
        Container(width: 38, height: 5, decoration: BoxDecoration(color: const Color(0x4DFFFFFF), borderRadius: BorderRadius.circular(3))),
        const SizedBox(height: 6),
        Flexible(
          child: Theme(
            data: th.copyWith(
              listTileTheme: ListTileThemeData(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                minVerticalPadding: 12,
                horizontalTitleGap: 14,
                titleTextStyle: T(16, w: 500),
                subtitleTextStyle: T(13, color: kMut),
                iconColor: kText,
                textColor: kText,
              ),
            ),
            child: child,
          ),
        ),
      ]),
    );
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: Perf.lite ? panel : BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28), child: panel),
    );
  }
}


/// indicateur de chargement : roue iOS sur iPhone, cercle Material ailleurs
class Spinner extends StatelessWidget {
  final double strokeWidth;
  final Color? color;
  const Spinner({super.key, this.strokeWidth = 4, this.color});
  @override
  Widget build(BuildContext context) => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? CupertinoActivityIndicator(radius: 13, color: color ?? kText)
      : CircularProgressIndicator(strokeWidth: strokeWidth, color: color);
}


/// page à grand titre : le titre se réduit au défilement dans une barre de verre (comme Réglages sur iPhone)
class LargeTitle extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback onBack;
  final double maxWidth;
  const LargeTitle({super.key, required this.title, required this.children, required this.onBack, this.maxWidth = 760});
  @override
  State<LargeTitle> createState() => _LargeTitleState();
}

class _LargeTitleState extends State<LargeTitle> {
  final _c = ScrollController();
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      final v = (_c.offset / 44).clamp(0.0, 1.0);
      if ((v - _t).abs() > .03) setState(() => _t = v);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final bar = Container(
      height: pad.top + 62,
      padding: EdgeInsets.fromLTRB(16 + pad.left, pad.top + 9, 16 + pad.right, 9),
      decoration: BoxDecoration(color: Color.fromRGBO(6, 8, 13, .72 * _t), border: Border(bottom: BorderSide(color: Color.fromRGBO(255, 255, 255, .10 * _t), width: .6))),
      child: Row(children: [
        RoundButton(size: 44, label: 'Retour', onTap: widget.onBack, child: const Ic('back', size: 20)),
        Expanded(child: Opacity(opacity: _t, child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: T(17, w: 650)))),
        const SizedBox(width: 44),
      ]),
    );
    return Stack(children: [
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: widget.maxWidth),
          child: ListView(controller: _c, padding: EdgeInsets.fromLTRB(pad.left, pad.top + 66, pad.right, 60 + pad.bottom), children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 14), child: Opacity(opacity: 1 - _t, child: Text(widget.title, style: T(34, w: 800, ls: -0.04)))),
            ...widget.children,
          ]),
        ),
      ),
      Positioned(top: 0, left: 0, right: 0, child: Perf.lite ? bar : ClipRect(child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 24 * _t + .01, sigmaY: 24 * _t + .01), child: bar))),
    ]);
  }
}


/// ligne de menu à la télécommande (colonne de gauche : filtres, thèmes…) : grande, lisible, sélection nette
class TvMenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;
  final Color? tint;
  final double indent;
  final bool autofocus;
  const TvMenuItem({super.key, required this.label, required this.icon, required this.on, required this.onTap, this.tint, this.indent = 0, this.autofocus = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: indent, bottom: 6),
        child: FocusCard(
          radius: 14,
          focusScale: 1.0,
          preferred: on,
          autofocus: autofocus,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(color: on ? Colors.white.withOpacity(0.14) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(icon, size: 24, color: tint ?? (on ? Colors.white : kMut)),
              const SizedBox(width: 14),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(19, w: on ? 750 : 550, color: on ? Colors.white : kText))),
            ]),
          ),
        ),
      );
}
