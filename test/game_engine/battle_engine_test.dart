import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/game_engine/engine/battle_engine.dart';
import 'package:reinos/game_engine/rng/seeded_random.dart';

import 'test_fixtures.dart';

void main() {
  group('BattleEngine.resolveRound', () {
    test('is deterministic for a given seed', () {
      final resultA = BattleEngine.resolveRound(
        attackingTroops: 3,
        defendingTroops: 2,
        rules: testRules,
        rng: SeededRandom(55),
      );
      final resultB = BattleEngine.resolveRound(
        attackingTroops: 3,
        defendingTroops: 2,
        rules: testRules,
        rng: SeededRandom(55),
      );

      expect(resultA.attackerDice, resultB.attackerDice);
      expect(resultA.defenderDice, resultB.defenderDice);
      expect(resultA.attackerLosses, resultB.attackerLosses);
      expect(resultA.defenderLosses, resultB.defenderLosses);
    });

    test('caps dice at RulesConfig maximums', () {
      final result = BattleEngine.resolveRound(
        attackingTroops: 10,
        defendingTroops: 10,
        rules: testRules,
        rng: SeededRandom(1),
      );

      expect(result.attackerDice.length, testRules.maxDiceAttacker);
      expect(result.defenderDice.length, testRules.maxDiceDefender);
    });

    test('total losses never exceed the number of dice compared', () {
      final rng = SeededRandom(321);
      for (var i = 0; i < 50; i++) {
        final result = BattleEngine.resolveRound(
          attackingTroops: 3,
          defendingTroops: 2,
          rules: testRules,
          rng: rng,
        );
        final comparisons = result.attackerDice.length < result.defenderDice.length
            ? result.attackerDice.length
            : result.defenderDice.length;
        expect(result.attackerLosses + result.defenderLosses, comparisons);
      }
    });

    test('marks the territory conquered once defending troops reach zero', () {
      final result = BattleEngine.resolveRound(
        attackingTroops: 3,
        defendingTroops: 1,
        rules: testRules,
        rng: SeededRandom(2),
      );

      // With only 1 defending troop, a single comparison happens; the
      // defender is wiped out whenever the attacker wins that comparison.
      if (result.defenderLosses >= 1) {
        expect(result.territoryConquered, isTrue);
      }
    });
  });
}
