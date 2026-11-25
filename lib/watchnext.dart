import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'perf.dart';
import 'store.dart';

/// Google TV / Android TV : « Continuer à regarder » de MinouFlix dans la rangée de l'accueil de la télé (Watch Next).
/// Un clic rouvre MinouFlix (lien minouflix://resume?k=…) à la position enregistrée. Sans effet ailleurs que sur Android TV.
class WatchNext {
  static const _ch = MethodChannel('minou/watchnext');
  static final _last = <String, DateTime>{};

  static bool get _on => !kIsWeb && Platform.isAndroid && Device.tv;

  /// au plus une mise à jour par minute et par titre
  static Future<void> set(Prog p) async {
    if (!_on || p.dur <= 0) return;
    final now = DateTime.now();
    final prev = _last[p.key];
    if (prev != null && now.difference(prev) < const Duration(seconds: 60)) return;
    _last[p.key] = now;
    try {
      await _ch.invokeMethod('set', {
        'id': p.key,
        'title': p.sname.isEmpty ? p.name : '${p.sname} · ${p.name}',
        'poster': p.icon,
        'uri': 'minouflix://resume?k=${Uri.encodeComponent(p.key)}',
        'pos': p.pos,
        'dur': p.dur,
      });
    } catch (_) {}
  }

  static Future<void> remove(String key) async {
    if (!_on) return;
    _last.remove(key);
    try {
      await _ch.invokeMethod('remove', {'id': key});
    } catch (_) {}
  }
}
