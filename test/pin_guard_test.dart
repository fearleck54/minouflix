import 'package:flutter_test/flutter_test.dart';
import 'package:minouflix/pin_guard.dart';

/// code du mode enfant : 3 essais puis 5 minutes d'attente
void main() {
  const t = 1000000;
  test('deux erreurs : pas encore bloqué', () {
    final g = const PinGuard(0, 0).failed(t).failed(t);
    expect(g.locked(t), isFalse);
    expect(g.left(), 1);
  });
  test('troisième erreur : bloqué 5 min, compteur remis à zéro', () {
    final g = const PinGuard(0, 0).failed(t).failed(t).failed(t);
    expect(g.locked(t), isTrue);
    expect(g.waitMin(t), 5);
    expect(g.fails, 0);
    expect(g.locked(t + PinGuard.lockMs), isFalse);
  });
  test('attente arrondie au-dessus', () {
    final g = const PinGuard(0, t + 61000);
    expect(g.waitMin(t), 2);
  });
  test('bon code : tout est remis à zéro', () {
    final g = const PinGuard(2, 0).success();
    expect(g.fails, 0);
    expect(g.locked(t), isFalse);
  });
}
