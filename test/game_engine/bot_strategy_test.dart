import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/game_engine/domain/bot_difficulty.dart';
import 'package:reinos/game_engine/domain/game_map.dart';
import 'package:reinos/game_engine/domain/player_color.dart';
import 'package:reinos/game_engine/domain/region.dart';
import 'package:reinos/game_engine/domain/territory.dart';
import 'package:reinos/game_engine/engine/bot_strategy.dart';
import 'package:reinos/game_engine/engine/game_engine.dart';
import 'package:reinos/game_engine/state/game_state.dart';

import 'test_fixtures.dart';

Territory _t(String id, List<String> neighbors) => Territory(
      id: id,
      name: id,
      regionId: 'r',
      neighborIds: neighbors,
      polygon: const [Offset2D(0, 0), Offset2D(1, 0), Offset2D(1, 1), Offset2D(0, 1)],
      centroid: const Offset2D(0.5, 0.5),
      biblicalReferences: const [],
      historicalPeriodId: 'test',
      description: '',
    );

/// A deliberately asymmetric board for exercising risk-aware attack choice:
/// - `home` -> `target` is the single biggest margin, but `home` would be
///   left exposed to `flankA` (a strong enemy neighbor) afterwards.
/// - `home2` -> `target2` is a smaller margin, but perfectly safe (no other
///   hostile neighbor to worry about).
GameMap _riskMap() {
  final territories = {
    'home': _t('home', ['target', 'flankA']),
    'target': _t('target', ['home']),
    'flankA': _t('flankA', ['home']),
    'home2': _t('home2', ['target2']),
    'target2': _t('target2', ['home2']),
  };
  return GameMap(
    id: 'risk_map',
    name: 'Risk Map',
    periodId: 'test',
    regions: {'r': const Region(id: 'r', name: 'r', territoryIds: [
      'home', 'target', 'flankA', 'home2', 'target2',
    ], controlBonus: 0)},
    territories: territories,
  );
}

/// A fresh, structurally valid [GameState] on [_riskMap] — ownership and
/// army counts from `GameEngine.newMatch`'s own setup are irrelevant and
/// always overridden via `withOwnership` by each test, same as
/// `freshTestState` is used elsewhere in this suite.
GameState _riskMatchState() {
  return GameEngine.newMatch(
    map: _riskMap(),
    configs: const [
      PlayerConfig(id: 'p0', displayName: 'P0', color: PlayerColor.blue),
      PlayerConfig(id: 'p1', displayName: 'P1', color: PlayerColor.red),
    ],
    rules: testRules,
    seed: 1,
  );
}

void main() {
  group('BotStrategy.decideNextAttack — difficulty', () {
    test('easy attacks even at a numeric disadvantage', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p1',
      }, {'t1': 3, 't2': 4}); // margin = -1

      final decision =
          BotStrategy.decideNextAttack(state, 'p0', difficulty: BotDifficulty.easy);

      expect(decision, isNotNull);
    });

    test('normal requires at least a +1 margin', () {
      var even = withOwnership(freshTestState(), {'t1': 'p0', 't2': 'p1'}, {'t1': 2, 't2': 2});
      expect(BotStrategy.decideNextAttack(even, 'p0', difficulty: BotDifficulty.normal), isNull);

      var ahead = withOwnership(freshTestState(), {'t1': 'p0', 't2': 'p1'}, {'t1': 3, 't2': 2});
      expect(
          BotStrategy.decideNextAttack(ahead, 'p0', difficulty: BotDifficulty.normal), isNotNull);
    });

    test('hard/expert prefer a safe attack over a larger but exposed one', () {
      final state = withOwnership(_riskMatchState(), {
        'home': 'p0', 'target': 'p1', 'flankA': 'p1', 'home2': 'p0', 'target2': 'p1',
      }, {'home': 10, 'target': 1, 'flankA': 20, 'home2': 5, 'target2': 1});

      final hardDecision =
          BotStrategy.decideNextAttack(state, 'p0', difficulty: BotDifficulty.hard);
      expect(hardDecision!.toTerritoryId, 'target2', reason: 'the safe, if smaller, opportunity');

      final normalDecision =
          BotStrategy.decideNextAttack(state, 'p0', difficulty: BotDifficulty.normal);
      expect(normalDecision!.toTerritoryId, 'target', reason: 'normal just takes the best margin');
    });

    test('hard/expert still attack an exposed target when it is the only option', () {
      // home2/target2 removed from contention by giving p0 no army there.
      final state = withOwnership(_riskMatchState(), {
        'home': 'p0', 'target': 'p1', 'flankA': 'p1', 'home2': 'p1', 'target2': 'p1',
      }, {'home': 10, 'target': 1, 'flankA': 20, 'home2': 1, 'target2': 1});

      final decision = BotStrategy.decideNextAttack(state, 'p0', difficulty: BotDifficulty.expert);
      expect(decision, isNotNull, reason: 'never refuse forever when a legal attack exists');
      expect(decision!.toTerritoryId, 'target');
    });
  });

  group('BotStrategy.decideReinforcementPlacement — difficulty', () {
    test('normal/easy reinforce the weakest frontier territory', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p1', 't3': 'p0', 't4': 'p1',
      }, {'t1': 5, 't3': 1});

      final placement = BotStrategy.decideReinforcementPlacement(
        state,
        'p0',
        4,
        difficulty: BotDifficulty.normal,
      );

      expect(placement, {'t3': 4});
    });

    test('hard/expert reinforce the most-threatened frontier territory instead', () {
      // home borders 2 hostiles (target, flankA); home2 borders 1 (target2).
      final state = withOwnership(_riskMatchState(), {
        'home': 'p0', 'target': 'p1', 'flankA': 'p1', 'home2': 'p0', 'target2': 'p1',
      }, {'home': 5, 'target': 1, 'flankA': 1, 'home2': 1, 'target2': 1});

      final hardPlacement = BotStrategy.decideReinforcementPlacement(
        state,
        'p0',
        3,
        difficulty: BotDifficulty.hard,
      );
      expect(hardPlacement, {'home': 3}, reason: 'home faces 2 threats vs home2\'s 1');

      final normalPlacement = BotStrategy.decideReinforcementPlacement(
        state,
        'p0',
        3,
        difficulty: BotDifficulty.normal,
      );
      expect(normalPlacement, {'home2': 3}, reason: 'normal just reinforces the weakest army');
    });
  });

  group('BotStrategy never touches the RNG', () {
    test('decideNextAttack, decideReinforcementPlacement and decideCardTradeIn are pure', () {
      final state = withOwnership(freshTestState(), {'t1': 'p0', 't2': 'p1'}, {'t1': 5, 't2': 1});
      final rngStateBefore = state.rng.state;

      BotStrategy.decideNextAttack(state, 'p0', difficulty: BotDifficulty.expert);
      BotStrategy.decideReinforcementPlacement(state, 'p0', 3, difficulty: BotDifficulty.expert);
      BotStrategy.decideCardTradeIn(state, 'p0');

      expect(state.rng.state, rngStateBefore);
    });
  });
}
