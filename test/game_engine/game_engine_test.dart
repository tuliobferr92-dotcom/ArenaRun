import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/game_engine/domain/objective.dart';
import 'package:reinos/game_engine/domain/player.dart';
import 'package:reinos/game_engine/engine/game_engine.dart';
import 'package:reinos/game_engine/engine/game_exceptions.dart';
import 'package:reinos/game_engine/state/game_action.dart';
import 'package:reinos/game_engine/state/game_phase.dart';

import 'test_fixtures.dart';

GameAction _place(String territoryId, {int count = 1, String playerId = 'p0', int seq = 0}) {
  return PlaceArmyAction(
    gameId: 'g',
    playerId: playerId,
    timestamp: DateTime.now(),
    sequenceNumber: seq,
    territoryId: territoryId,
    count: count,
  );
}

GameAction _attack(String from, String to, int troops, {String playerId = 'p0', int seq = 0}) {
  return AttackAction(
    gameId: 'g',
    playerId: playerId,
    timestamp: DateTime.now(),
    sequenceNumber: seq,
    fromTerritoryId: from,
    toTerritoryId: to,
    troopCount: troops,
  );
}

GameAction _endPhase({String playerId = 'p0', int seq = 0}) {
  return EndPhaseAction(gameId: 'g', playerId: playerId, timestamp: DateTime.now(), sequenceNumber: seq);
}

void main() {
  group('GameEngine.newMatch', () {
    test('distributes every territory to a player and starts in initialPlacement', () {
      final state = freshTestState();

      expect(state.phase, GamePhase.initialPlacement);
      expect(state.territories.values.every((t) => t.ownerId != null), isTrue);
      expect(state.pendingReinforcements, testRules.initialPlacementExtraArmies);
    });
  });

  group('GameEngine.apply — validation', () {
    test('rejects an action from a player who is not the current player', () {
      final state = freshTestState();
      expect(
        () => GameEngine.apply(state, _place('t1', playerId: 'p1')),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('rejects attacking a non-adjacent territory', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p0', 't3': 'p1', 't4': 'p1',
      }, {'t1': 5, 't4': 1});
      state = state.copyWith(phase: GamePhase.attack, pendingReinforcements: 0);

      expect(
        () => GameEngine.apply(state, _attack('t1', 't4', 1)),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('rejects attacking your own territory', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p0', 't3': 'p1', 't4': 'p1',
      }, {});
      state = state.copyWith(phase: GamePhase.attack, pendingReinforcements: 0);

      expect(
        () => GameEngine.apply(state, _attack('t1', 't2', 1)),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('rejects attacking with more troops than available', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p1',
      }, {'t1': 3});
      state = state.copyWith(phase: GamePhase.attack, pendingReinforcements: 0);

      expect(
        () => GameEngine.apply(state, _attack('t1', 't2', 3)), // max allowed is armyCount-1 = 2
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('rejects ending the reinforcement phase with reinforcements still pending', () {
      var state = freshTestState().copyWith(phase: GamePhase.reinforcement, pendingReinforcements: 3);
      expect(
        () => GameEngine.apply(state, _endPhase()),
        throwsA(isA<InvalidActionException>()),
      );
    });
  });

  group('GameEngine.apply — reinforcement', () {
    test('placing armies decrements pendingReinforcements and increases the army count', () {
      var state = withOwnership(freshTestState(), {'t1': 'p0'}, {'t1': 2})
          .copyWith(phase: GamePhase.reinforcement, pendingReinforcements: 3);

      state = GameEngine.apply(state, _place('t1', count: 3));

      expect(state.territories['t1']!.armyCount, 5);
      expect(state.pendingReinforcements, 0);
    });
  });

  group('GameEngine.apply — attack & conquest', () {
    test('a sufficiently stronger attacker eventually conquers the defender', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p1',
      }, {'t1': 10, 't2': 1});
      state = state.copyWith(phase: GamePhase.attack, pendingReinforcements: 0);

      var conquered = false;
      for (var i = 0; i < 9 && !conquered; i++) {
        final from = state.territories['t1']!;
        if (from.armyCount <= 1) break;
        final troops = (from.armyCount - 1).clamp(1, 3);
        state = GameEngine.apply(state, _attack('t1', 't2', troops, seq: i));
        conquered = state.territories['t2']!.ownerId == 'p0';
      }

      expect(conquered, isTrue, reason: 'Expected conquest within a handful of attack rounds');
      expect(state.territories['t2']!.armyCount, greaterThanOrEqualTo(1));
      expect(state.conqueredTerritoryThisTurn, isTrue);
    });

    test('total army count across the two territories never exceeds the pre-battle total', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p1',
      }, {'t1': 5, 't2': 4});
      state = state.copyWith(phase: GamePhase.attack, pendingReinforcements: 0);

      final before = state.territories['t1']!.armyCount + state.territories['t2']!.armyCount;
      state = GameEngine.apply(state, _attack('t1', 't2', 3));
      final after = state.territories['t1']!.armyCount + state.territories['t2']!.armyCount;

      expect(after, lessThanOrEqualTo(before));
    });
  });

  group('GameEngine.apply — turn flow', () {
    test('a full turn cycle advances to the next player and increments the turn number', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p0', 't3': 'p1', 't4': 'p1',
      }, {});
      state = state.copyWith(
        phase: GamePhase.reinforcement,
        pendingReinforcements: 0,
        currentPlayerIndex: 0,
        turnNumber: 1,
      );

      state = GameEngine.apply(state, _endPhase(seq: 0)); // -> attack
      expect(state.phase, GamePhase.attack);

      state = GameEngine.apply(state, _endPhase(seq: 1)); // -> fortification
      expect(state.phase, GamePhase.fortification);

      state = GameEngine.apply(state, _endPhase(seq: 2)); // -> cardReward/turnEnd -> next player
      expect(state.currentPlayerIndex, 1);
      expect(state.phase, GamePhase.reinforcement);
      expect(state.turnNumber, 1); // only increments once it wraps back to player 0
    });
  });

  group('GameEngine.apply — objectives & victory', () {
    test('completing a controlTerritoryCount objective ends the game with that player as winner', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p0', 't3': 'p0', 't4': 'p1',
      }, {});
      // Rebuild player 0's objective to a reachable 3-territory target.
      final objective = Objective(
        id: 'test_obj',
        type: ObjectiveType.controlTerritoryCount,
        description: 'test',
        params: {'count': 3},
      );
      state = state.copyWith(
        phase: GamePhase.fortification,
        pendingReinforcements: 0,
        currentPlayerIndex: 0,
        players: [
          _withObjective(state.players[0], objective),
          state.players[1],
        ],
      );

      state = GameEngine.apply(state, _endPhase());

      expect(state.phase, GamePhase.gameOver);
      expect(state.winnerId, 'p0');
    });

    test('a sole surviving player wins even without completing their objective', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p0', 't3': 'p0', 't4': 'p0',
      }, {});
      state = state.copyWith(
        phase: GamePhase.fortification,
        pendingReinforcements: 0,
        currentPlayerIndex: 0,
        players: [
          state.players[0],
          state.players[1].copyWith(isEliminated: true),
        ],
      );

      state = GameEngine.apply(state, _endPhase());

      expect(state.phase, GamePhase.gameOver);
      expect(state.winnerId, 'p0');
    });
  });
}

// Player has no public copyWith for objective (it's assigned at creation
// only); tests rebuild a Player with a different objective directly.
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
