import 'package:test/test.dart';
import 'package:reinos_engine/game_engine/engine/reinforcement_calculator.dart';

import 'test_fixtures.dart';

void main() {
  group('ReinforcementCalculator', () {
    test('grants the configured minimum when few territories are owned', () {
      final state = withOwnership(freshTestState(), {
        't1': 'p0',
        't2': null,
        't3': null,
        't4': null,
      }, {});

      final result = ReinforcementCalculator.calculate(state, 'p0', testRules);

      expect(result, testRules.minReinforcements);
    });

    test('adds the full region control bonus when a player owns a whole region', () {
      final state = withOwnership(freshTestState(), {
        't1': 'p0',
        't2': 'p0',
        't3': 'p1',
        't4': 'p1',
      }, {});

      final result = ReinforcementCalculator.calculate(state, 'p0', testRules);

      // base = max(floor(2/3)=0, min=3) = 3, + regionA bonus (2) = 5.
      expect(result, 5);
    });

    test('does not grant a region bonus for a partially-controlled region', () {
      final state = withOwnership(freshTestState(), {
        't1': 'p0',
        't2': 'p1',
        't3': 'p0',
        't4': 'p1',
      }, {});

      final result = ReinforcementCalculator.calculate(state, 'p0', testRules);

      expect(result, testRules.minReinforcements);
    });
  });
}
