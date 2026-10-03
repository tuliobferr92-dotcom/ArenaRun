import 'package:flutter_test/flutter_test.dart';
import 'package:reinos/game_engine/engine/game_engine.dart';
import 'package:reinos/game_engine/engine/game_exceptions.dart';
import 'package:reinos/game_engine/state/game_action.dart';
import 'package:reinos/game_engine/state/game_phase.dart';

import 'test_fixtures.dart';

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

GameAction _answer(String challengeId, bool correct, {String playerId = 'p0', int seq = 0}) {
  return AnswerChallengeAction(
    gameId: 'g',
    playerId: playerId,
    timestamp: DateTime.now(),
    sequenceNumber: seq,
    challengeId: challengeId,
    correct: correct,
  );
}

void main() {
  group('GameEngine — territory discovery (section 24)', () {
    test('conquering a territory for the first time marks it discovered', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p1',
      }, {'t1': 10, 't2': 1});
      state = state.copyWith(phase: GamePhase.attack, pendingReinforcements: 0);

      var discoveredNow = false;
      for (var i = 0; i < 9 && !discoveredNow; i++) {
        final from = state.territories['t1']!;
        if (from.armyCount <= 1) break;
        final troops = (from.armyCount - 1).clamp(1, 3);
        state = GameEngine.apply(state, _attack('t1', 't2', troops, seq: i));
        discoveredNow = state.newlyDiscoveredTerritoryId == 't2';
      }

      expect(discoveredNow, isTrue);
      expect(state.discoveredTerritoryIds, contains('t2'));
    });

    test('conquering an already-discovered territory again does not re-flag it', () {
      // t2 starts already discovered (as if conquered earlier this match).
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p1',
      }, {'t1': 10, 't2': 1});
      state = state.copyWith(
        phase: GamePhase.attack,
        pendingReinforcements: 0,
        discoveredTerritoryIds: {'t2'},
      );

      String? seenDiscovery;
      for (var i = 0; i < 9; i++) {
        final from = state.territories['t1']!;
        if (from.armyCount <= 1) break;
        final troops = (from.armyCount - 1).clamp(1, 3);
        state = GameEngine.apply(state, _attack('t1', 't2', troops, seq: i));
        seenDiscovery ??= state.newlyDiscoveredTerritoryId;
        if (state.territories['t2']!.ownerId == 'p0') break;
      }

      expect(seenDiscovery, isNull);
    });

    test('newlyDiscoveredTerritoryId is cleared on the next end-of-phase', () {
      var state = withOwnership(freshTestState(), {
        't1': 'p0', 't2': 'p1',
      }, {'t1': 10, 't2': 1});
      state = state.copyWith(phase: GamePhase.attack, pendingReinforcements: 0);

      for (var i = 0; i < 9; i++) {
        final from = state.territories['t1']!;
        if (from.armyCount <= 1) break;
        final troops = (from.armyCount - 1).clamp(1, 3);
        state = GameEngine.apply(state, _attack('t1', 't2', troops, seq: i));
        if (state.newlyDiscoveredTerritoryId != null) break;
      }
      expect(state.newlyDiscoveredTerritoryId, isNotNull);

      state = GameEngine.apply(
        state,
        EndPhaseAction(gameId: 'g', playerId: 'p0', timestamp: DateTime.now(), sequenceNumber: 100),
      );
      expect(state.newlyDiscoveredTerritoryId, isNull);
      // The permanent record survives the transient flag being cleared.
      expect(state.discoveredTerritoryIds, contains('t2'));
    });
  });

  group('GameEngine.apply — AnswerChallengeAction', () {
    test('records a correct answer', () {
      final state = freshTestState();
      final result = GameEngine.apply(state, _answer('chal_1', true));

      expect(result.currentPlayer.answeredChallengeIds, contains('chal_1'));
      expect(result.currentPlayer.correctChallengeAnswers, 1);
    });

    test('records an incorrect answer without incrementing the correct count', () {
      final state = freshTestState();
      final result = GameEngine.apply(state, _answer('chal_1', false));

      expect(result.currentPlayer.answeredChallengeIds, contains('chal_1'));
      expect(result.currentPlayer.correctChallengeAnswers, 0);
    });

    test('rejects answering the same challenge twice', () {
      var state = freshTestState();
      state = GameEngine.apply(state, _answer('chal_1', true));

      expect(
        () => GameEngine.apply(state, _answer('chal_1', false, seq: 1)),
        throwsA(isA<InvalidActionException>()),
      );
    });

    test('does not affect other players\' answered challenges', () {
      final state = freshTestState();
      final result = GameEngine.apply(state, _answer('chal_1', true));

      expect(result.players[1].answeredChallengeIds, isEmpty);
      expect(result.players[1].correctChallengeAnswers, 0);
    });
  });
}
