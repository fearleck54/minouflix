import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'xtream.dart';

/// programme en cours d'une chaîne
class EpgNow {
  final String title;
  final int start, stop;       // secondes
  const EpgNow(this.title, this.start, this.stop);
  double get progress => ((DateTime.now().millisecondsSinceEpoch / 1000 - start) / (stop - start)).clamp(0.0, 1.0);
  int get leftMin => ((stop - DateTime.now().millisecondsSinceEpoch / 1000) / 60).ceil().clamp(0, 9999);
  String get until {
    final t = DateTime.fromMillisecondsSinceEpoch(stop * 1000);
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class Epg {
  static Map<String, List<List<Object>>> _by = {};
  static final _asked = <String, DateTime>{};
  static final _queue = <(String, List<int>)>[];
  static int _active = 0;
  static Xtream? src;
  static Timer? _t;
  static final version = ValueNotifier<int>(0);

  /// changement de source : les programmes de l'ancienne source sont oubliés
  static void reset() {
    _by = {};
    _asked.clear();
    _queue.clear();
    src = null;
    version.value++;
  }

  /// demande le programme en cours d'une chaîne (une petite requête, au plus 2 à la fois, renouvelée toutes les 10 min) ; rend la main quand c'est lu
  static Future<void> want(String id, List<int> sids) async {
    final x = src;
    if (x == null || id.isEmpty || sids.isEmpty) return;
    final at = _asked[id];
    if (at != null && DateTime.now().difference(at) < const Duration(minutes: 10)) return;
    _asked[id] = DateTime.now();
    if (_queue.length >= 40) _queue.removeAt(0);
    _queue.add((id, sids.take(4).toList()));
    _pump();
  }

  static void _pump() {
    final x = src;
    if (x == null) return;
    while (_active < 2 && _queue.isNotEmpty) {
      final (id, sids) = _queue.removeLast();      // la dernière chaîne affichée d'abord
      _active++;
      _first(x, sids).then((l) {
        if (l.isNotEmpty) {
          _by[id] = l;
          _t?.cancel();
          _t = Timer(const Duration(milliseconds: 400), () => version.value++);
        }
      }).catchError((_) {}).whenComplete(() {
        _active--;
        _pump();
      });
    }
  }

  /// le fournisseur ne donne parfois le programme que sur une autre version de la chaîne (HD, FHD…) : on essaie chacune jusqu'à une réponse
  static Future<List<List<Object>>> _first(Xtream x, List<int> sids) async {
    for (final sid in sids) {
      try {
        final l = await x.shortEpg(sid);
        if (l.isNotEmpty) return l;
      } catch (_) {}
    }
    return const [];
  }

  static bool get loaded => _by.isNotEmpty;

  static EpgNow? now(String id) {
    final l = _by[id];
    if (l == null) return null;
    final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final p in l) {
      if ((p[0] as int) <= t && (p[1] as int) > t) return EpgNow(p[2] as String, p[0] as int, p[1] as int);
    }
    return null;
  }
}
