import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'journal.dart';

/// mesure de fluidité et de mémoire, notée dans le journal (Réglages › Aide › Voir le journal) : images lentes (> 120 ms), mémoire élevée
class PerfLog {
  static int _slow = 0, _worst = 0;
  static DateTime _lastLine = DateTime.fromMillisecondsSinceEpoch(0);

  static int get rssMb {
    try {
      return (ProcessInfo.currentRss / 1048576).round();
    } catch (_) {
      return 0;
    }
  }

  static void start() {
    if (kIsWeb) return;
    SchedulerBinding.instance.addTimingsCallback((ts) {
      for (final t in ts) {
        final ms = t.totalSpan.inMilliseconds;
        if (ms > 120) {
          _slow++;
          if (ms > _worst) _worst = ms;
        }
      }
      final now = DateTime.now();
      if (_slow > 0 && now.difference(_lastLine) > const Duration(seconds: 30)) {
        Journal.add('Fluidité : $_slow images lentes (> 120 ms), la pire $_worst ms, mémoire ${rssMb} Mo');
        _slow = 0;
        _worst = 0;
        _lastLine = now;
      }
    });
    Timer.periodic(const Duration(minutes: 5), (_) {
      final m = rssMb;
      if (m > 350) Journal.add('Mémoire élevée : $m Mo');
    });
  }
}
