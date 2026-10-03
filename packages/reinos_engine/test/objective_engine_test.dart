import 'package:test/test.dart';
import 'package:reinos_engine/game_engine/domain/objective.dart';
import 'package:reinos_engine/game_engine/domain/player.dart';
import 'package:reinos_engine/game_engine/engine/objective_engine.dart';

import 'test_fixtures.dart';

void main() {
  group('ObjectiveEngine — eliminatePlayer', () {
    test('is not complete while the target is still alive', () {
      var state = freshTestState();
      state = state.copyWith(players: [
        _withObjective(state.players[0], const Objective(
          id: 'o',
          type: ObjectiveType.eliminatePlayer,
          description: 'test',
          params: {'targetPlayerId': 'p1'},
        )),
        state.players[1],
      ]);

      expect(ObjectiveEngine.isComplete(state, 'p0'), isFalse);
    });

    test('is complete once the named target is eliminated', () {
      var state = freshTestState();
      state = state.copyWith(players: [
        _withObjective(state.players[0], const Objective(
          id: 'o',
          type: ObjectiveType.eliminatePlayer,
          description: 'test',
          params: {'targetPlayerId': 'p1'},
        )),
        state.players[1].copyWith(isEliminated: true),
      ]);

      expect(ObjectiveEngine.isComplete(state, 'p0'), isTrue);
    });

    test('a different player being eliminated does not satisfy it', () {
      var state = freshTestState(playerCount: 3);
      state = state.copyWith(players: [
        _withObjective(state.players[0], const Objective(
          id: 'o',
          type: ObjectiveType.eliminatePlayer,
          description: 'test',
          params: {'targetPlayerId': 'p1'},
        )),
        state.players[1],
        state.players[2].copyWith(isEliminated: true),
      ]);

      expect(ObjectiveEngine.isComplete(state, 'p0'), isFalse);
    });

    test('a null target can never be satisfied', () {
      var state = freshTestState();
      state = state.copyWith(players: [
        _withObjective(state.players[0], const Objective(
          id: 'o',
          type: ObjectiveType.eliminatePlayer,
          description: 'test',
          params: {'targetPlayerId': null},
        )),
        state.players[1].copyWith(isEliminated: true),
      ]);

      expect(ObjectiveEngine.isComplete(state, 'p0'), isFalse);
    });
  });

  group('ObjectiveEngine — hybrid', () {
    Objective hybridObjective() => const Objective(
          id: 'o',
          type: ObjectiveType.hybrid,
          description: 'test',
          params: {
            'conditions': [
              {'type': 'controlRegions', 'params': {'regionIds': ['regionA']}},
              {'type': 'controlTerritoryCount', 'params': {'count': 3}},
            ],
          },
        );

    test('requires every sub-condition to hold', () {
      // Controls regionA (t1, t2) but only 2 territories total — the count
      // sub-condition (>=3) is not met yet.
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p0', 't3': 'p1', 't4': 'p1',
      }, {});
      state = state.copyWith(
        players: [_withObjective(state.players[0], hybridObjective()), state.players[1]],
      );

      expect(ObjectiveEngine.isComplete(state, 'p0'), isFalse);
    });

    test('is complete once every sub-condition holds simultaneously', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p0', 't3': 'p0', 't4': 'p1',
      }, {});
      state = state.copyWith(
        players: [_withObjective(state.players[0], hybridObjective()), state.players[1]],
      );

      expect(ObjectiveEngine.isComplete(state, 'p0'), isTrue);
    });

    test('satisfying only one sub-condition is not enough', () {
      // 3+ territories, but none of them make up all of regionA.
      var state = withOwnership(freshTestState(), {
        't1': 'p1', 't2': 'p0', 't3': 'p0', 't4': 'p0',
      }, {});
      state = state.copyWith(
        players: [_withObjective(state.players[0], hybridObjective()), state.players[1]],
      );

      expect(ObjectiveEngine.isComplete(state, 'p0'), isFalse);
    });
  });

  group('GameEngine.newMatch — objective variety', () {
    test('assigns all 5 objective types when there are enough players', () {
      final state = freshTestState(playerCount: 5);
      final types = state.players.map((p) => p.objective.type).toSet();
      expect(types, ObjectiveType.values.toSet());
    });

    test('an eliminatePlayer objective never targets the player themselves', () {
      final state = freshTestState(playerCount: 5);
      for (final player in state.players) {
        if (player.objective.type == ObjectiveType.eliminatePlayer) {
          expect(player.objective.params['targetPlayerId'], isNot(player.id));
        }
      }
    });
  });
}

Player _withObjective(Player player, Objective objective) {
  return Player(
    id: player.id,
    displayName: player.displayName,
    color: player.color,
    isBot: player.isBot,
    botDifficulty: player.botDifficulty,
    objective: objective,
    cards: player.cards,
    wisdomPoints: player.wisdomPoints,
    xp: player.xp,
    isEliminated: player.isEliminated,
  );
}
