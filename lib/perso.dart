import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' hide Text;
import 'store.dart';
import 'ui.dart';

/// Réglages › Onglets : onglets affichés, ordre de gauche à droite, onglet d'ouverture
class TabsSettings extends StatefulWidget {
  const TabsSettings({super.key});
  @override
  State<TabsSettings> createState() => _TabsState();
}

class _TabsState extends State<TabsSettings> {
  late List<int> order = Store.tabOrder();
  late Set<int> hid = Store.tabHidden();
  late int start = Store.tabStart();
  static const names = ['Accueil', 'Direct', 'Films', 'Séries', 'Sport'];
  static const icons = [CupertinoIcons.house_fill, CupertinoIcons.tv_fill, CupertinoIcons.film_fill, CupertinoIcons.rectangle_stack_fill, CupertinoIcons.sportscourt_fill];

  Future<void> _save() async {
    await Store.setTabs(order, hid, start);
    if (mounted) setState(() {});
  }

  void _move(int i, int d) {
    final j = i + d;
    if (j < 0 || j >= order.length) return;
    final id = order[i];
    order.insert(j, order.removeAt(i));
    _stay(id, d, j + d >= 0 && j + d < order.length);
    _save();
  }

  final _nodes = <String, FocusNode>{};
  FocusNode _nd(Object id, int d) => _nodes.putIfAbsent('$id/$d', () => FocusNode());
  /// après un déplacement, le sélecteur reste sur la ligne déplacée (flèche choisie, ou l'autre en bout de liste)
  void _stay(Object id, int d, bool canMore) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _nd(id, canMore ? d : -d).requestFocus());
  }

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }


  void _toggle(int t) {
    if (hid.contains(t)) {
      hid.remove(t);
    } else {
      if (order.where((x) => !hid.contains(x)).length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Garde au moins un onglet.')));
        return;
      }
      hid.add(t);
      if (start == t) start = -1;
    }
    _save();
  }

  Widget _arrow(IconData ic, bool on, VoidCallback f, FocusNode node) => FocusCard(
        focusNode: node,
        onTap: on ? f : () {},
        radius: 12,
        focusScale: 1,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(ic, size: 18, color: on ? kText : const Color(0x44FFFFFF))),
      );

  Widget _opt(String label, int v) => FocusCard(
        onTap: () {
          start = v;
          _save();
        },
        radius: 0,
        focusScale: 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
          child: Row(children: [Expanded(child: Text(label, style: T(16.5, w: 500))), if (start == v) const Icon(CupertinoIcons.checkmark_alt, color: kAccent, size: 20)]),
        ),
      );

  Widget _card(List<Widget> rows) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: kEdge, width: 0.8)),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 0.5, thickness: 0.5, indent: 18, color: kEdge),
                rows[i],
              ],
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final vis = order.where((t) => !hid.contains(t)).toList();
    return Scaffold(
      body: LargeTitle(
        title: 'Onglets',
        onBack: () => Navigator.pop(context),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 14), child: Text('Choisis les onglets affichés et leur ordre, de gauche à droite.', style: T(14, color: kMut, h: 1.4))),
          _card([
            for (var i = 0; i < order.length; i++)
              Row(children: [
                Expanded(
                  child: FocusCard(
                    onTap: () => _toggle(order[i]),
                    radius: 0,
                    focusScale: 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 6, 8),
                      child: Row(children: [
                        Icon(icons[order[i]], size: 22, color: hid.contains(order[i]) ? kMut : kAccent),
                        const SizedBox(width: 14),
                        Expanded(child: Text(names[order[i]], style: T(16.5, w: 600, color: hid.contains(order[i]) ? kMut : kText))),
                        ExcludeFocus(child: IgnorePointer(child: Switch(value: !hid.contains(order[i]), activeColor: Colors.white, activeTrackColor: const Color(0xFF30D158), onChanged: (_) {}))),
                      ]),
                    ),
                  ),
                ),
                _arrow(CupertinoIcons.chevron_up, i > 0, () => _move(i, -1), _nd(order[i], -1)),
                _arrow(CupertinoIcons.chevron_down, i < order.length - 1, () => _move(i, 1), _nd(order[i], 1)),
                const SizedBox(width: 8),
              ]),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(26, 22, 22, 8), child: Text('OUVRIR L\'APPLI SUR', style: T(12, w: 700, ls: 0.09, color: kMut))),
          _card([
            _opt('Le premier onglet de la barre', -1),
            _opt('Le dernier onglet ouvert', 9),
            for (final t in vis) _opt(names[t], t),
          ]),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PillButton(
              label: 'Réinitialiser',
              height: 50,
              onTap: () {
                order = [0, 1, 2, 3, 4];
                hid = {};
                start = -1;
                _save();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Réglages › Écran d'accueil : sections affichées et leur ordre
class HomeSettings extends StatefulWidget {
  const HomeSettings({super.key});
  @override
  State<HomeSettings> createState() => _HomeState();
}

class _HomeState extends State<HomeSettings> {
  late List<String> order = Store.homeOrder();
  late Set<String> hid = Store.homeHidden();
  static const labels = {
    'hero': ('Grande affiche', 'La bannière en haut de l\'accueil'),
    'continue': ('Continuer à regarder', 'Reprendre un film ou un épisode'),
    'mylist': ('Ma liste', 'Masquée quand elle est vide'),
    'soon': ('Prochains épisodes', 'Les séries que tu suis'),
    'playlists': ('Mes playlists', 'Tes listes par thème'),
    'downloads': ('Téléchargés', 'Films et épisodes hors ligne'),
    'top10': ('Top 10 cette semaine', 'Les plus regardés'),
    'affiche': ('À l\'affiche', 'Les sorties cinéma'),
    'sport': ('Sport', 'Matchs et événements à venir'),
    'chains': ('Mes chaînes', 'Masquée quand tu n\'as pas de favorite'),
    'recoV': ('Vous aimerez peut-être', 'Films proposés d\'après ta liste'),
    'recoS': ('Séries pour vous', 'Séries proposées d\'après ta liste'),
    'recent': ('Derniers films ajoutés', 'Les nouveautés du catalogue'),
    'recentS': ('Séries mises à jour', 'Les séries avec de nouveaux épisodes'),
    'trakt': ('Ma liste Trakt', 'Tes titres à voir sur Trakt, présents dans ton catalogue'),
  };

  final _nodes = <String, FocusNode>{};
  FocusNode _nd(Object id, int d) => _nodes.putIfAbsent('$id/$d', () => FocusNode());
  /// après un déplacement, le sélecteur reste sur la ligne déplacée (flèche choisie, ou l'autre en bout de liste)
  void _stay(Object id, int d, bool canMore) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _nd(id, canMore ? d : -d).requestFocus());
  }

  @override
  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await Store.setHome(order, hid);
    if (mounted) setState(() {});
  }

  Widget _arrow(IconData ic, bool on, VoidCallback f, FocusNode node) => FocusCard(
        focusNode: node,
        onTap: on ? f : () {},
        radius: 12,
        focusScale: 1,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(ic, size: 18, color: on ? kText : const Color(0x44FFFFFF))),
      );

  @override
  Widget build(BuildContext context) {
    final mv = order.where((x) => x != 'hero').toList();      // la grande affiche reste en haut
    Widget row(String id, {bool movable = true}) {
      final l = labels[id]!, off = hid.contains(id), i = mv.indexOf(id);
      return Row(children: [
        Expanded(
          child: FocusCard(
            onTap: () {
              off ? hid.remove(id) : hid.add(id);
              _save();
            },
            radius: 0,
            focusScale: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 6, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.$1, style: T(16.5, w: 600, color: off ? kMut : kText)),
                    Text(l.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: T(12.5, color: kMut)),
                  ]),
                ),
                ExcludeFocus(child: IgnorePointer(child: Switch(value: !off, activeColor: Colors.white, activeTrackColor: const Color(0xFF30D158), onChanged: (_) {}))),
              ]),
            ),
          ),
        ),
        if (movable) ...[
          _arrow(CupertinoIcons.chevron_up, i > 0, () {
            final j = order.indexOf(mv[i - 1]), k = order.indexOf(id);
            order[k] = mv[i - 1];
            order[j] = id;
            _stay(id, -1, i - 1 > 0);
            _save();
          }, _nd(id, -1)),
          _arrow(CupertinoIcons.chevron_down, i < mv.length - 1, () {
            final j = order.indexOf(mv[i + 1]), k = order.indexOf(id);
            order[k] = mv[i + 1];
            order[j] = id;
            _stay(id, 1, i + 1 < mv.length - 1);
            _save();
          }, _nd(id, 1)),
          const SizedBox(width: 8),
        ] else
          const SizedBox(width: 90),
      ]);
    }

    return Scaffold(
      body: LargeTitle(
        title: 'Écran d\'accueil',
        onBack: () => Navigator.pop(context),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 14), child: Text('Choisis les sections de l\'accueil et leur ordre. Une section sans contenu ne s\'affiche jamais.', style: T(14, color: kMut, h: 1.4))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: kEdge, width: 0.8)),
                child: Column(children: [
                  row('hero', movable: false),
                  for (final id in mv) ...[const Divider(height: 0.5, thickness: 0.5, indent: 18, color: kEdge), row(id)],
                ]),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PillButton(
              label: 'Réinitialiser',
              height: 50,
              onTap: () {
                order = [...Store.homeIds];
                hid = {};
                _save();
              },
            ),
          ),
        ],
      ),
    );
  }
}
