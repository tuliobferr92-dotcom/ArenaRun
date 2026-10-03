import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/game_engine/rng/seeded_random.dart';

void main() {
  group('SeededRandom', () {
    test('same seed produces the same sequence of dice rolls', () {
      final a = SeededRandom(123);
      final b = SeededRandom(123);

      final rollsA = List.generate(20, (_) => a.nextDie(6));
      final rollsB = List.generate(20, (_) => b.nextDie(6));

      expect(rollsA, rollsB);
    });

    test('different seeds produce different sequences', () {
      final a = SeededRandom(1);
      final b = SeededRandom(2);

      final rollsA = List.generate(20, (_) => a.nextDie(6));
      final rollsB = List.generate(20, (_) => b.nextDie(6));

      expect(rollsA, isNot(equals(rollsB)));
    });

    test('nextDie always stays within [1, sides]', () {
      final rng = SeededRandom(7);
      for (var i = 0; i < 1000; i++) {
        final roll = rng.nextDie(6);
        expect(roll, inInclusiveRange(1, 6));
      }
    });

    test('shuffled is a deterministic permutation of the input', () {
      final rng = SeededRandom(99);
      final shuffled = rng.shuffled([1, 2, 3, 4, 5]);

      expect(shuffled.toSet(), {1, 2, 3, 4, 5});
      expect(shuffled.length, 5);
    });
  });
}
