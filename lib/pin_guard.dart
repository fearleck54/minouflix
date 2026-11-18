/// code du mode enfant : 3 essais, puis 5 minutes d'attente (logique pure, testée dans test/)
class PinGuard {
  static const maxTries = 3;
  static const lockMs = 5 * 60 * 1000;

  final int fails, lockUntil;     // essais ratés depuis le dernier blocage ; fin du blocage (ms)
  const PinGuard(this.fails, this.lockUntil);

  bool locked(int now) => now < lockUntil;

  /// minutes d'attente restantes (arrondi au-dessus), 0 si débloqué
  int waitMin(int now) => locked(now) ? ((lockUntil - now) / 60000).ceil() : 0;

  /// après un code faux : le 3e échec bloque et remet le compteur à zéro
  PinGuard failed(int now) => fails + 1 >= maxTries ? PinGuard(0, now + lockMs) : PinGuard(fails + 1, lockUntil);

  /// après un bon code
  PinGuard success() => const PinGuard(0, 0);

  int left() => maxTries - fails;
}
