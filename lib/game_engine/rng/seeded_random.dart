/// Deterministic PRNG the engine owns end to end, so battle outcomes are
/// never decided by the UI or by Dart's platform-dependent `Random` —
/// replayable from a seed, and ready for a future server-authoritative
/// implementation that must reproduce the exact same rolls (ARCHITECTURE.md
/// section 9, GAME_RULES.md combat).
///
/// Implementation: xorshift32. Deliberately avoids 64-bit literals and
/// wide multiplications — both lose precision once compiled to JavaScript
/// (dart2js/dartdevc represent `int` as a double, exact only up to 2^53),
/// which would silently desync the sequence between platforms. Only
/// shifts/XORs are used, so the same seed produces the same sequence on
/// every backend (VM, AOT, JS).
class SeededRandom {
  int _state;

  SeededRandom(int seed) : _state = _normalize(seed);

  /// Restores a generator from a previously-saved [state] (not a seed) —
  /// used by save/load so a resumed match produces the exact same future
  /// dice sequence as if it had never been saved.
  SeededRandom.fromState(this._state);

  static int _normalize(int seed) {
    final masked = seed & 0xFFFFFFFF;
    return masked == 0 ? 0x9E3779B9 : masked;
  }

  /// Current internal state — persist this (not the original seed) to
  /// resume the exact same sequence later (save game / reconnect).
  int get state => _state;

  int _nextRaw() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    x &= 0xFFFFFFFF;
    _state = x;
    return x;
  }

  /// Returns an integer in `[1, sides]`, e.g. `nextDie(6)` for a d6 roll.
  int nextDie(int sides) => (_nextRaw() % sides) + 1;

  /// Returns an integer in `[0, max)`.
  int nextInt(int max) => _nextRaw() % max;

  /// Deterministic Fisher-Yates shuffle (map distribution, deck shuffling).
  List<T> shuffled<T>(List<T> items) {
    final list = List<T>.from(items);
    for (var i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
    return list;
  }

  SeededRandom clone() => SeededRandom.fromState(_state);
}
